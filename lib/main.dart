import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'login_screen.dart';
import 'dashboard_screen.dart'; // ⬅️ use the new dashboard instead of home_screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("🔥 BEFORE Firebase.initializeApp()");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("✅ AFTER Firebase.initializeApp()");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print("🟢 Building MyApp...");
    return MaterialApp(
      title: 'YallaHire',
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    print("🟠 Entered AuthGate...");
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print(
          "📡 Stream snapshot: connectionState=${snapshot.connectionState}, user=${snapshot.data}",
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          print("⏳ Waiting for auth state...");
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          print("✅ User found. Navigating to Dashboard.");
          return const DashboardScreen(); // ⬅️ new dashboard screen
        } else {
          print("❌ No user. Navigating to LoginScreen.");
          return LoginScreen();
        }
      },
    );
  }
}
