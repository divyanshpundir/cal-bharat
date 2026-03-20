import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class FirebaseBootstrap extends StatelessWidget {
  const FirebaseBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Splash();
        }
        if (snapshot.hasError) {
          return _FirebaseInitError(error: snapshot.error);
        }
        return const AuthGate();
      },
    );
  }

  Future<void> _initFirebase() async {
    if (kIsWeb) {
      const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
      const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
      const messagingSenderId =
          String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
      const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
      const authDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
      const storageBucket = String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');

      if (apiKey.isEmpty ||
          appId.isEmpty ||
          messagingSenderId.isEmpty ||
          projectId.isEmpty) {
        throw Exception(
          'Firebase web config missing. Run with dart-defines:\n'
          'FIREBASE_WEB_API_KEY, FIREBASE_WEB_APP_ID, FIREBASE_WEB_MESSAGING_SENDER_ID, FIREBASE_WEB_PROJECT_ID\n'
          '(optional: FIREBASE_WEB_AUTH_DOMAIN, FIREBASE_WEB_STORAGE_BUCKET)',
        );
      }

      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          authDomain: authDomain.isEmpty ? '$projectId.firebaseapp.com' : authDomain,
          storageBucket: storageBucket.isEmpty ? null : storageBucket,
        ),
      );
      return;
    }

    await Firebase.initializeApp();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cal भारत',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseInitError extends StatelessWidget {
  const _FirebaseInitError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Firebase init failed:\n\n$error',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

