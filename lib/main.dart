import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

bool shouldUseFirebaseEmulator = false;
late final FirebaseAuth auth;
late final FirebaseApp app;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  auth = FirebaseAuth.instance;

  if (shouldUseFirebaseEmulator) {
    await auth.useAuthEmulator('localhost', 9099);
  }

  runApp(const MyApp());
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
  String? _userPhotoUrl;

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

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (Platform.isWindows) {
        // Windows用のGoogle認証フロー
        const clientId =
            '816464201732-29ln6fesquaug5pifejbia8pmm32tsr5.apps.googleusercontent.com';
        final redirectUri = 'http://localhost:54321'; // リダイレクトURIを修正

        // 認証URLを生成
        final authUrl = Uri.parse(
          'https://accounts.google.com/o/oauth2/v2/auth?'
          'client_id=$clientId'
          '&redirect_uri=$redirectUri'
          '&response_type=code'
          '&scope=email%20profile%20openid'
          '&access_type=offline'
          '&prompt=consent'
          '&state=${DateTime.now().millisecondsSinceEpoch}',
        );

        //print('認証URL: $authUrl'); // デバッグ情報を追加

        // ブラウザで認証URLを開く
        if (await canLaunchUrl(authUrl)) {
          await launchUrl(authUrl, mode: LaunchMode.externalApplication);

          // ローカルサーバーを起動してコードを待ち受ける
          final server = await HttpServer.bind('localhost', 54321);
          String? code;

          await for (HttpRequest request in server) {
            code = request.uri.queryParameters['code'];

            request.response
              ..headers.contentType = ContentType.html
              ..write(
                '<html><body><h1>認証が完了しました。このページを閉じてアプリケーションに戻ってください。</h1></body></html>',
              )
              ..close();

            await server.close();
            break;
          }

          if (code != null) {
            //print('認証コード: $code'); // デバッグ情報
            // コードをトークンに交換
            final tokenResponse = await http.post(
              Uri.parse('https://oauth2.googleapis.com/token'),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: {
                'client_id': clientId,
                'client_secret':
                    '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', // クライアントシークレットを追加
                'redirect_uri': redirectUri,
                'grant_type': 'authorization_code',
                'code': code,
              },
            );

            //print('トークンレスポンス: ${tokenResponse.body}'); // デバッグ情報

            if (tokenResponse.statusCode == 200) {
              final tokenData = json.decode(tokenResponse.body);
              final idToken = tokenData['id_token'];
              final accessToken = tokenData['access_token'];

              // Firebaseで認証
              final credential = GoogleAuthProvider.credential(
                accessToken: accessToken,
                idToken: idToken,
              );

              final userCredential = await auth.signInWithCredential(
                credential,
              );
              final user = userCredential.user;

              if (user != null && mounted) {
                setState(() {
                  _userPhotoUrl = user.photoURL;
                });
              }
            } else {
              throw Exception('トークンの取得に失敗しました');
            }
          }
        } else {
          throw Exception('認証URLを開けませんでした');
        }
      } else {
        // 通常のGoogleサインインフロー
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;

        setState(() {
          _userPhotoUrl = googleUser.photoUrl;
        });

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      if (mounted) {
        //print('詳細なエラー情報: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Googleログインエラー: ${e.toString()}'),
            duration: const Duration(seconds: 10),
          ),
        );
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
            if (_userPhotoUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(_userPhotoUrl!),
                ),
              ),
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _signInWithGoogle,
              icon: Image.network(
                'https://developers.google.com/identity/images/g-logo.png',
                height: 24.0,
              ),
              label: const Text('Googleでログイン'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: const BorderSide(color: Colors.grey, width: 1),
                ),
              ),
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

  Future<void> _reauthenticateWithGoogle(BuildContext context) async {
    try {
      if (Platform.isWindows) {
        throw Exception('Windows版では再認証は利用できません');
      }

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(
        credential,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('再認証エラー: ${e.toString()}')));
      }
      rethrow;
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('アカウント削除の確認'),
            content: const Text('本当にアカウントを削除しますか？\nこの操作は取り消せません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('削除'),
              ),
            ],
          ),
    );

    if (result != true || !context.mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Googleアカウントの場合は再認証が必要
      if (user.providerData.any(
        (provider) => provider.providerId == 'google.com',
      )) {
        await _reauthenticateWithGoogle(context);
      }

      // ユーザーのドキュメントを全て削除
      final docs =
          await FirebaseFirestore.instance
              .collection('documents')
              .where('userId', isEqualTo: user.uid)
              .get();

      for (var doc in docs.docs) {
        await doc.reference.delete();
      }

      // ユーザーアカウントを削除
      await user.delete();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('アカウントを削除しました')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ドキュメント一覧'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'logout':
                  FirebaseAuth.instance.signOut();
                  break;
                case 'delete_account':
                  _deleteAccount(context);
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('ログアウト'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete_account',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text('アカウント削除', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
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
  TextAlign _textAlign = TextAlign.left;
  Timer? _saveTimer;
  List<String> _images = [];
  Map<int, Size> _imageSizes = {};
  final ImagePicker _picker = ImagePicker();

  // 画像サイズの定数
  static const Size _smallSize = Size(200, 150);
  static const Size _mediumSize = Size(300, 200);
  static const Size _largeSize = Size(400, 300);

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
        _textAlign = _getTextAlignFromString(
          data['styles']?['textAlign'] ?? 'left',
        );
        _images = List<String>.from(data['images'] ?? []);

        // 画像サイズの初期化
        final imageSizes = data['imageSizes'] as Map<String, dynamic>?;
        if (imageSizes != null) {
          _imageSizes = imageSizes.map((key, value) {
            final size = value as Map<String, dynamic>;
            return MapEntry(
              int.parse(key),
              Size(size['width'].toDouble(), size['height'].toDouble()),
            );
          });
        }
      });
    }
  }

  TextAlign _getTextAlignFromString(String align) {
    switch (align) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  String _getStringFromTextAlign(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return 'center';
      case TextAlign.right:
        return 'right';
      default:
        return 'left';
    }
  }

  Future<void> _addImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024, // 画像サイズを制限
        maxHeight: 1024,
        imageQuality: 85, // 品質を調整
      );
      if (image == null) return;

      final userId = FirebaseAuth.instance.currentUser!.uid;
      final bytes = await image.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('画像データが空です');
      }

      // ファイル名を一意にする
      final ext = image.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'users/$userId/documents/${widget.documentId}/$fileName';

      final storageRef = FirebaseStorage.instance.ref().child(path);

      // アップロードタスクの作成と監視
      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}',
          customMetadata: {
            'uploadedBy': userId,
            'documentId': widget.documentId,
          },
        ),
      );

      // アップロードの進行状況を監視
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          final progress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          print('アップロード進行状況: ${progress.toStringAsFixed(1)}%');
        }
      });

      // アップロード完了を待機
      await uploadTask;

      if (uploadTask.snapshot.state == TaskState.success) {
        // URLを取得
        final imageUrl = await storageRef.getDownloadURL();

        // Firestoreに保存
        setState(() {
          _images.add(imageUrl);
        });
        await FirebaseFirestore.instance
            .collection('documents')
            .doc(widget.documentId)
            .update({
              'images': _images,
              'lastModified': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('画像をアップロードしました')));
        }
      } else {
        throw Exception('アップロードに失敗しました');
      }
    } catch (e) {
      print('エラーの詳細: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像のアップロードに失敗しました: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _deleteImage(int index) async {
    try {
      final imageUrl = _images[index];
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // まずFirestoreから画像URLを削除
      setState(() {
        _images.removeAt(index);
      });
      await FirebaseFirestore.instance
          .collection('documents')
          .doc(widget.documentId)
          .update({'images': _images});

      // Storage上のファイルを削除
      try {
        final ref = FirebaseStorage.instance.refFromURL(imageUrl);
        if (ref.fullPath.startsWith('users/$userId/')) {
          await ref.delete();
        }
      } catch (storageError) {
        print('ストレージからの削除に失敗しました: $storageError');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の削除に失敗しました: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showResizeDialog(BuildContext context, int index) async {
    Size currentSize = _imageSizes[index] ?? _mediumSize;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('画像サイズの変更'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('小'),
                  subtitle: const Text('200 x 150'),
                  leading: Radio<Size>(
                    value: _smallSize,
                    groupValue: currentSize,
                    onChanged: (Size? value) {
                      currentSize = value!;
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ),
                ListTile(
                  title: const Text('中'),
                  subtitle: const Text('300 x 200'),
                  leading: Radio<Size>(
                    value: _mediumSize,
                    groupValue: currentSize,
                    onChanged: (Size? value) {
                      currentSize = value!;
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ),
                ListTile(
                  title: const Text('大'),
                  subtitle: const Text('400 x 300'),
                  leading: Radio<Size>(
                    value: _largeSize,
                    groupValue: currentSize,
                    onChanged: (Size? value) {
                      currentSize = value!;
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  _resizeImage(index, currentSize.width, currentSize.height);
                  Navigator.pop(context);
                },
                child: const Text('変更'),
              ),
            ],
          ),
    );
  }

  Future<void> _resizeImage(int index, double width, double height) async {
    try {
      setState(() {
        _imageSizes[index] = Size(width, height);
      });

      // Firestoreに保存
      final imageSizesMap = _imageSizes.map(
        (key, value) => MapEntry(key.toString(), {
          'width': value.width,
          'height': value.height,
        }),
      );

      await FirebaseFirestore.instance
          .collection('documents')
          .doc(widget.documentId)
          .update({
            'imageSizes': imageSizesMap,
            'lastModified': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('画像サイズを変更しました')));
      }
    } catch (e) {
      print('画像のリサイズエラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像サイズの変更に失敗しました: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
              'textAlign': _getStringFromTextAlign(_textAlign),
            },
            'images': _images,
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
        actions: [
          IconButton(icon: const Icon(Icons.image), onPressed: _addImage),
        ],
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
                const VerticalDivider(),
                IconButton(
                  icon: Icon(
                    Icons.format_align_left,
                    color:
                        _textAlign == TextAlign.left
                            ? Colors.blue
                            : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _textAlign = TextAlign.left;
                      _saveDocument();
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.format_align_center,
                    color:
                        _textAlign == TextAlign.center
                            ? Colors.blue
                            : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _textAlign = TextAlign.center;
                      _saveDocument();
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.format_align_right,
                    color:
                        _textAlign == TextAlign.right
                            ? Colors.blue
                            : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _textAlign = TextAlign.right;
                      _saveDocument();
                    });
                  },
                ),
                const VerticalDivider(),
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
          if (_images.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                double maxHeight = 0;
                for (int i = 0; i < _images.length; i++) {
                  final size = _imageSizes[i] ?? const Size(300, 200);
                  maxHeight = maxHeight > size.height ? maxHeight : size.height;
                }
                return SizedBox(
                  height: maxHeight + 16, // パディングの分を追加
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final size = _imageSizes[index] ?? const Size(300, 200);
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Stack(
                          children: [
                            Container(
                              width: size.width,
                              height: size.height,
                              constraints: BoxConstraints(
                                minWidth: size.width,
                                minHeight: size.height,
                                maxWidth: size.width,
                                maxHeight: size.height,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: GestureDetector(
                                onTap: () => _showResizeDialog(context, index),
                                child: Image.network(
                                  _images[index],
                                  width: size.width,
                                  height: size.height,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 100,
                                      width: 100,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.error),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => _deleteImage(index),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
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
                textAlign: _textAlign,
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
