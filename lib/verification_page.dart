import 'dart:async'; // Required for the countdown timer
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pinput/pinput.dart';
import 'homepage.dart'; // <--- IMPORT HOMEPAGE INSTEAD OF LOGIN PAGE

class VerificationPage extends StatefulWidget {
  final String email;
  const VerificationPage({super.key, required this.email});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final _codeController = TextEditingController();
  final supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isResending = false;

  // Timer variables
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel(); // Cancel timer if user leaves the page
    _codeController.dispose();
    super.dispose();
  }

  // --- START COOLDOWN TIMER ---
  void _startCooldown() {
    setState(() => _resendCooldown = 60); // 60 seconds
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  // --- VERIFY OTP & AUTO-LOGIN ---
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the full 6-digit code")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final AuthResponse response = await supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: widget.email,
        token: code,
      );

      // If session is not null, Supabase has AUTO-LOGGED THEM IN!
      if (response.session != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account Verified! Logging you in..."),
            backgroundColor: Colors.green,
          ),
        );

        // --- CRITICAL FIX: Send them straight to the Home Page! ---
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const UserHomePage()),
          (route) =>
              false, // Kills the back button so they can't go back to the OTP screen
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invalid Code: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // --- RESEND OTP ---
  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    try {
      await supabase.auth.resend(type: OtpType.signup, email: widget.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("New verification code sent!"),
            backgroundColor: Colors.green,
          ),
        );
        _startCooldown(); // Start the 60s timer
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isResending = false);
  }

  @override
  Widget build(BuildContext context) {
    // --- PINPUT THEMES ---
    // This defines how the boxes look normally (Now Solid White!)
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 55,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Colors.deepPurple,
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        color: Colors.white, // Solid white background
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
    );

    // This defines how the box looks when the user taps on it to type
    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.deepPurple, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      backgroundColor: Colors.transparent, // 1. Allow gradient to show
      appBar: AppBar(
        title: const Text("Verify Account"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        // --- 2. THE PURPLE GRADIENT BACKGROUND ---
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8EAF6), // Soft Indigo
              Color(0xFFD1C4E9), // Light Deep Purple
              Color(0xFFF3E5F5), // Soft Pinkish Purple
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- 3. SEMI-TRANSPARENT CIRCLE FOR ICON ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read,
                      size: 70,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "Check Your Email",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Text(
                    "We sent a 6-digit code to:\n${widget.email}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- 4. NEW WHITE CODE INPUT (6 BOXES) ---
                  Pinput(
                    length: 6,
                    controller: _codeController,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    // Auto-submit the code once all 6 boxes are filled
                    onCompleted: (pin) {
                      if (!_isLoading) {
                        _verifyCode();
                      }
                    },
                  ),
                  const SizedBox(height: 40),

                  // --- VERIFY BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                "Verify Code",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- RESEND OTP ROW ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Didn't receive the code?",
                        style: TextStyle(color: Colors.deepPurple),
                      ),
                      TextButton(
                        onPressed:
                            (_resendCooldown > 0 || _isResending)
                                ? null
                                : _resendCode,
                        child:
                            _isResending
                                ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.deepPurple,
                                  ),
                                )
                                : Text(
                                  _resendCooldown > 0
                                      ? "Resend in ${_resendCooldown}s"
                                      : "Resend Code",
                                  style: TextStyle(
                                    color:
                                        _resendCooldown > 0
                                            ? Colors.grey
                                            : Colors.deepPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
