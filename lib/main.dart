import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:isolate';
import 'dart:io' show Platform;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Isolateの処理を後に移動
  if (Platform.isAndroid) {
    RootIsolateToken? rootIsolateToken = RootIsolateToken.instance;
    if (rootIsolateToken != null) {
      Isolate.spawn(_isolateMain, rootIsolateToken);
    }
  }

  runApp(const MyApp());
}

void _isolateMain(RootIsolateToken rootIsolateToken) {
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
  // バックグラウンド処理をここに記述
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ワープロ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return const DocumentListPage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _register() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: const Text('ログイン'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: const Text('新規登録'),
                ),
              ],
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class DocumentListPage extends StatelessWidget {
  const DocumentListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ドキュメント一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('documents')
                .where('userId', isEqualTo: user.uid)
                .orderBy('lastModified', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('エラーが発生しました'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children:
                snapshot.data!.docs.map((doc) {
                  Map<String, dynamic> data =
                      doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['title'] ?? '無題'),
                    subtitle: Text(
                      '最終更新: ${data['lastModified']?.toDate().toString().split('.')[0] ?? ''}',
                    ),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => EditorPage(documentId: doc.id),
                          ),
                        ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => doc.reference.delete(),
                    ),
                  );
                }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNewDocument(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _createNewDocument(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser!;
    final docRef = await FirebaseFirestore.instance.collection('documents').add(
      {
        'userId': user.uid,
        'title': '新規ドキュメント',
        'content': '',
        'lastModified': FieldValue.serverTimestamp(),
        'styles': {'isBold': false, 'isItalic': false, 'fontSize': 16.0},
      },
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorPage(documentId: docRef.id),
        ),
      );
    }
  }
}

class EditorPage extends StatefulWidget {
  final String documentId;

  const EditorPage({super.key, required this.documentId});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isBold = false;
  bool _isItalic = false;
  double _fontSize = 16.0;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _saveTimer?.cancel();
    super.dispose();
  }

  void _loadDocument() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('documents')
            .doc(widget.documentId)
            .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _titleController.text = data['title'] ?? '無題';
        _contentController.text = data['content'] ?? '';
        _isBold = data['styles']?['isBold'] ?? false;
        _isItalic = data['styles']?['isItalic'] ?? false;
        _fontSize = (data['styles']?['fontSize'] ?? 16.0).toDouble();
      });
    }
  }

  void _saveDocument() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () {
      FirebaseFirestore.instance
          .collection('documents')
          .doc(widget.documentId)
          .update({
            'title': _titleController.text,
            'content': _contentController.text,
            'lastModified': FieldValue.serverTimestamp(),
            'styles': {
              'isBold': _isBold,
              'isItalic': _isItalic,
              'fontSize': _fontSize,
            },
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.blue),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'タイトルを入力',
            hintStyle: TextStyle(color: Colors.white70),
          ),
          onChanged: (_) => _saveDocument(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.format_bold,
                    color: _isBold ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isBold = !_isBold;
                      _saveDocument();
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.format_italic,
                    color: _isItalic ? Colors.blue : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isItalic = !_isItalic;
                      _saveDocument();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.text_decrease),
                  onPressed: () {
                    setState(() {
                      _fontSize = (_fontSize - 2).clamp(8.0, 48.0);
                      _saveDocument();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.text_increase),
                  onPressed: () {
                    setState(() {
                      _fontSize = (_fontSize + 2).clamp(8.0, 48.0);
                      _saveDocument();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                style: TextStyle(
                  fontSize: _fontSize,
                  fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                  fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'ここに文章を入力してください',
                ),
                onChanged: (_) => _saveDocument(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
