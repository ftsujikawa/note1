// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDKRsq5DQuJfTs5hIxnybJQxcNO2CtKGFw',
    appId: '1:816464201732:web:9450146597e55033e3cd51',
    messagingSenderId: '816464201732',
    projectId: 'flutter-firebase-app-a275c',
    authDomain: 'flutter-firebase-app-a275c.firebaseapp.com',
    storageBucket: 'flutter-firebase-app-a275c.firebasestorage.app',
    measurementId: 'G-L30WC0R0R7',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAycQC7L10RAEgSHqjz5jk7s8Vnb892T94',
    appId: '1:816464201732:android:5b647e8fd22f4c57e3cd51',
    messagingSenderId: '816464201732',
    projectId: 'flutter-firebase-app-a275c',
    storageBucket: 'flutter-firebase-app-a275c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAUQxTrutrdiHQtsSZIBVKxEIqGXv1FvHU',
    appId: '1:816464201732:ios:29c9906dd4264a7de3cd51',
    messagingSenderId: '816464201732',
    projectId: 'flutter-firebase-app-a275c',
    storageBucket: 'flutter-firebase-app-a275c.firebasestorage.app',
    iosBundleId: 'com.example.note1',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAUQxTrutrdiHQtsSZIBVKxEIqGXv1FvHU',
    appId: '1:816464201732:ios:29c9906dd4264a7de3cd51',
    messagingSenderId: '816464201732',
    projectId: 'flutter-firebase-app-a275c',
    storageBucket: 'flutter-firebase-app-a275c.firebasestorage.app',
    iosBundleId: 'com.example.note1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDKRsq5DQuJfTs5hIxnybJQxcNO2CtKGFw',
    appId: '1:816464201732:web:95ce0c8bbfa54b02e3cd51',
    messagingSenderId: '816464201732',
    projectId: 'flutter-firebase-app-a275c',
    authDomain: 'flutter-firebase-app-a275c.firebaseapp.com',
    storageBucket: 'flutter-firebase-app-a275c.firebasestorage.app',
    measurementId: 'G-53GQH44PEL',
  );
}
