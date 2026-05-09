import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'app_feedback.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color kPrimary = Color(0xFFE89C8A);

  final TextEditingController phoneController = TextEditingController();

  String countryCode = '+961';
  bool isLoading = false;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    showAppMessageDialog(context, title: 'Notice', message: text);
  }

  String _normalizePhone() {
    String number = phoneController.text.trim().replaceAll(' ', '');

    // remove the local leading zero before sending the number in international format.
    if (number.startsWith('0')) {
      number = number.substring(1);
    }

    return '$countryCode$number';
  }

  Future<void> _sendCode() async {
    final rawPhone = phoneController.text.trim();

    if (rawPhone.isEmpty) {
      _showSnack('Please enter your phone number.');
      return;
    }

    final phoneNumber = _normalizePhone();
    debugPrint('PHONE SENT TO FIREBASE: $phoneNumber');

    setState(() => isLoading = true);

    try {
      if (kDebugMode) {
        // test mode disables real app verification during local development.
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: true,
        );
      }

      // start Firebase phone authentication and handle each verification callback.
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('verificationCompleted');

          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
          } catch (e) {
            debugPrint('verificationCompleted sign-in error: $e');
          }

          if (!mounted) return;
          setState(() => isLoading = false);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('verificationFailed: ${e.code} ${e.message}');
          if (!mounted) return;
          setState(() => isLoading = false);
          _showSnack('Verification failed: ${e.message ?? e.code}');
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('codeSent');
          if (!mounted) return;
          setState(() => isLoading = false);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => OtpScreen(
                    verificationId: verificationId,
                    phoneNumber: phoneNumber,
                  ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('codeAutoRetrievalTimeout');
          if (!mounted) return;
          setState(() => isLoading = false);
        },
      );
    } catch (e) {
      debugPrint('sendCode catch: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnack('Could not send code: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  "YallaHire",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Continue with your phone number.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "We use phone verification to keep YallaHire safe and trustworthy.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black45,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CountryCodePicker(
                        onChanged: (country) {
                          setState(() {
                            countryCode = country.dialCode ?? '+961';
                          });
                        },
                        initialSelection: 'LB',
                        favorite: const ['+961', 'LB'],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          hintText: '3 123 456',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _sendCode,
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
                              'Send Code',
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
