import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    print("🟡 AuthGate widget built");

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print(
          "📡 Auth stream: connectionState = ${snapshot.connectionState}, user = ${snapshot.data}",
        );

        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user != null) {
            print("✅ User is logged in: ${user.email}");
            return const HomeScreen();
          } else {
            print("❌ No user logged in");
            return LoginScreen();
          }
        }

        print("⏳ Waiting for auth state...");
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
