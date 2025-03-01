import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

class AuthServer {
  final completer = Completer<String>();
  var server;

  Future<void> start() async {
    server = await shelf_io.serve(
      (request) {
        if (request.url.path == '/') {
          // URLフラグメントからアクセストークンを取得
          final token =
              request.url.fragment
                  .split('&')
                  .firstWhere((element) => element.startsWith('access_token='))
                  .split('=')[1];

          completer.complete(token);

          return Response.ok(
            '<html><body><h1>認証が完了しました。このページを閉じてアプリケーションに戻ってください。</h1></body></html>',
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }
        return Response.notFound('Not found');
      },
      'localhost',
      8000,
    );
  }

  Future<String> waitForToken() => completer.future;

  Future<void> stop() async {
    await server?.close();
  }
}
