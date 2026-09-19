import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for kIsWeb
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_page.dart';
import 'homepage.dart';
import 'admin_home.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // --- NEW: ANTI-SPAM & LOCKOUT VARIABLES ---
  bool _isProcessing = false; // Prevents rapid double-clicks
  int _failedAttempts = 0; // Tracks failed login attempts
  DateTime? _lockoutTime; // Tracks when the 3-minute timeout expires

  // --- STANDARD EMAIL LOGIN ---
  Future<void> _signIn() async {
    // 1. CHECK LOCKOUT STATUS FIRST
    if (_lockoutTime != null) {
      final remaining = _lockoutTime!.difference(DateTime.now()).inSeconds;
      if (remaining > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Too many attempts. Try again in $remaining seconds.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      } else {
        // Time has passed, reset the lockout
        setState(() {
          _failedAttempts = 0;
          _lockoutTime = null;
        });
      }
    }

    // 2. PREVENT DOUBLE CLICKS & VALIDATE
    if (_isProcessing || !_formKey.currentState!.validate()) return;

    _isProcessing = true;
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null && mounted) {
        // SUCCESS: Reset the failed attempts counter!
        _failedAttempts = 0;

        final data =
            await Supabase.instance.client
                .from('profiles')
                .select('role')
                .eq('id', response.user!.id)
                .maybeSingle();

        String role = 'user';
        if (data != null && data['role'] != null) {
          role = data['role'];
        }

        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminHomePage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const UserHomePage()),
          );
        }
      }
    } on AuthException catch (e) {
      _handleFailedAttempt(e.message);
    } catch (e) {
      _handleFailedAttempt("Error: $e");
    } finally {
      // ALWAYS unlock the button when finished
      _isProcessing = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEW: HELPER TO HANDLE FAILURES & TRIGGER LOCKOUT ---
  void _handleFailedAttempt(String originalMessage) {
    _failedAttempts++;
    String displayMessage = originalMessage;

    // Clean up Supabase's default error messages
    if (originalMessage.contains("Email not confirmed")) {
      displayMessage = "Please check your email to verify your account.";
    } else if (originalMessage.contains("Invalid login credentials")) {
      displayMessage = "Wrong email or password.";
    }

    // Trigger Lockout if they hit 5 failures
    if (_failedAttempts >= 5) {
      _lockoutTime = DateTime.now().add(const Duration(minutes: 3));
      displayMessage =
          "Account temporarily locked for 3 minutes due to too many failed attempts.";
    } else {
      // Show them how many tries they have left
      displayMessage =
          "$displayMessage (Attempts left: ${5 - _failedAttempts})";
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(displayMessage), backgroundColor: Colors.red),
      );
    }
  }

  // --- GOOGLE SIGN IN ---
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo:
            kIsWeb
                ? 'https://finsight-web-38a6b.web.app' // Web destination
                : 'io.supabase.finsight://login-callback', // Mobile destination
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google Sign-In Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Required to let gradient show
      body: Container(
        // --- BOLD PURPLE GRADIENT BACKGROUND ---
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
                vertical: 40.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(
                          0.5,
                        ), // Semi-transparent white circle
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        size: 70,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      "FinSight Login",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      "Welcome to FinSight, where you gain clear insight into your finances. Track spending, manage budgets, and make decisions all in one place.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.deepPurple,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- UPDATED CRISP OUTLINE INPUT BOXES ---

                    // EMAIL INPUT
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Gmail Address",
                        hintText: "example@gmail.com",
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Colors.deepPurple,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.deepPurple.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.deepPurple,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) return 'Invalid email format';
                        if (!value.toLowerCase().trim().endsWith(
                          '@gmail.com',
                        )) {
                          return 'Please login with a @gmail.com account';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // PASSWORD INPUT
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: "Password",
                        filled: true,
                        fillColor: Colors.white, // Solid white
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.deepPurple,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.deepPurple.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.deepPurple,
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Please enter your password'
                                  : null,
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --- EMAIL LOGIN BUTTON ---
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          elevation: 5, // Added a nice drop shadow
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
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- OR DIVIDER ---
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.deepPurple.withOpacity(0.3),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            "OR",
                            style: TextStyle(
                              color: Colors.deepPurple.shade300,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.deepPurple.withOpacity(0.3),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- GOOGLE SIGN IN BUTTON ---
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: const Icon(
                          Icons.g_mobiledata,
                          size: 32,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          "Sign in with Google",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account?",
                          style: TextStyle(color: Colors.deepPurple),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignUpPage(),
                              ),
                            );
                          },
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
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
      ),
    );
  }
}
