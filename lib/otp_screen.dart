import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_feedback.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const Color kPrimary = Color(0xFFE89C8A);

  final TextEditingController codeController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    showAppMessageDialog(context, title: 'Notice', message: text);
  }

  Future<void> _verifyCode() async {
    final code = codeController.text.trim();

    if (code.length != 6) {
      _showSnack('Please enter the 6-digit code.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user == null) {
        throw Exception('No authenticated user found.');
      }

      final profileRef = FirebaseFirestore.instance
          .collection('profiles')
          .doc(user.uid);

      final profileDoc = await profileRef.get();

      if (!mounted) return;

      if (profileDoc.exists) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      } else {
        await profileRef.set({
          'phoneNumber': user.phoneNumber ?? widget.phoneNumber,
          'phoneVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const ProfileScreen(isOnboarding: true),
          ),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack(e.message ?? 'Invalid code. Please try again.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Verification failed: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  "Verify your number",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "Enter the 6-digit code sent to\n${widget.phoneNumber}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'Verification code',
                    labelStyle: const TextStyle(color: Colors.black54),
                    floatingLabelStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: Colors.black38,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: kPrimary,
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              'Verify Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
