import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final supabase = Supabase.instance.client;

  bool _isLoading = false;

  Future<void> _saveProfileDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // --- UPSERT THE PROFILE DATA ---
        await supabase.from('profiles').upsert({
          'id': user.id, // Mandatory for Upsert!
          'username': _usernameController.text.trim(),
          'full_name': _fullNameController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          // --- SEND BACK TO GATEKEEPER TO TRIGGER PIN SETUP ---
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AuthGate()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving profile: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final inputFillColor = isDarkMode ? Colors.grey[800] : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color:
              isDarkMode
                  ? Theme.of(context).scaffoldBackgroundColor
                  : Colors.white,
          gradient:
              isDarkMode
                  ? null
                  : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(Colors.white, primaryColor, 0.1)!,
                      Color.lerp(Colors.white, primaryColor, 0.2)!,
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
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_add_alt_1,
                        size: 70,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      "Almost There!",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      "Because you signed in with Google, we just need a few more details to set up your profile.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // --- USERNAME ---
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: "Choose a Username",
                        hintText: "e.g. AbuBakar",
                        filled: true,
                        fillColor: inputFillColor,
                        prefixIcon: Icon(
                          Icons.alternate_email,
                          color: primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator:
                          (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Please enter a username'
                                  : null,
                    ),
                    const SizedBox(height: 16),

                    // --- FULL NAME ---
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        hintText: "e.g. John Doe",
                        filled: true,
                        fillColor: inputFillColor,
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator:
                          (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Please enter your full name'
                                  : null,
                    ),
                    const SizedBox(height: 32),

                    // --- SAVE BUTTON ---
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfileDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 4,
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
                                  "Continue to PIN Setup",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
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
