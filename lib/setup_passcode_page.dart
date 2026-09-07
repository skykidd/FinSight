import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'homepage.dart';

class SetupPasscodePage extends StatefulWidget {
  const SetupPasscodePage({super.key});

  @override
  State<SetupPasscodePage> createState() => _SetupPasscodePageState();
}

class _SetupPasscodePageState extends State<SetupPasscodePage> {
  // Only instantiate LocalAuthentication on non-web platforms
  final LocalAuthentication? auth = kIsWeb ? null : LocalAuthentication();

  String _enteredPin = "";
  String _firstPin = "";
  bool _isConfirming = false;
  String _errorMessage = "";

  void _onNumPadTap(String number) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += number;
        _errorMessage = "";
      });

      if (_enteredPin.length == 6) {
        if (!_isConfirming) {
          setState(() {
            _firstPin = _enteredPin;
            _enteredPin = "";
            _isConfirming = true;
          });
        } else {
          _verifyAndSavePin();
        }
      }
    }
  }

  void _onBackspaceTap() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = "";
      });
    }
  }

  // --- NEW: FUNCTION TO RESET SETUP ---
  void _resetSetup() {
    setState(() {
      _firstPin = "";
      _enteredPin = "";
      _isConfirming = false;
      _errorMessage = "";
    });
  }

  Future<void> _verifyAndSavePin() async {
    if (_enteredPin == _firstPin) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_pin', _firstPin);

      // Biometrics only available on mobile
      if (!kIsWeb && auth != null) {
        final canCheckBiometrics = await auth!.canCheckBiometrics;
        final isDeviceSupported = await auth!.isDeviceSupported();

        if (canCheckBiometrics && isDeviceSupported && mounted) {
          _askForBiometrics(prefs);
          return;
        }
      }

      _goToDashboard();
    } else {
      setState(() {
        _enteredPin = "";
        _errorMessage = "Passcodes do not match. Try again.";
      });
    }
  }

  void _askForBiometrics(SharedPreferences prefs) {
    // Grab the theme color for the dialog button
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Enable Biometrics?",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              "Would you like to use your fingerprint or Face ID to unlock FinSight in the future?",
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await prefs.setBool('use_biometrics', false);
                  if (mounted) Navigator.pop(context);
                  _goToDashboard();
                },
                child: const Text(
                  "Not Now",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await prefs.setBool('use_biometrics', true);
                  if (mounted) Navigator.pop(context);
                  _goToDashboard();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor, // Dynamic Theme Color
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Enable"),
              ),
            ],
          ),
    );
  }

  void _goToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const UserHomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    // --- DYNAMIC THEME EXTRACTION ---
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // --- PREMIUM OMBRE GRADIENT BACKGROUND ---
        decoration: BoxDecoration(
          color: isDarkMode ? scaffoldBg : Colors.white,
          gradient:
              isDarkMode
                  ? null
                  : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(Colors.white, primaryColor, 0.15)!,
                      Color.lerp(Colors.white, primaryColor, 0.35)!,
                      Color.lerp(Colors.white, primaryColor, 0.15)!,
                    ],
                  ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isConfirming ? Icons.check_circle_outline : Icons.lock_open,
                  size: 50,
                  color: primaryColor, // Dynamic Theme Color
                ),
              ),
              const SizedBox(height: 30),
              Text(
                _isConfirming ? "Confirm Passcode" : "Create Passcode",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : "Enter a 6-digit PIN",
                style: TextStyle(
                  color:
                      _errorMessage.isNotEmpty ? Colors.redAccent : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  bool isFilled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isFilled
                              ? primaryColor
                              : (isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.white.withOpacity(0.5)),
                      border:
                          isFilled
                              ? null
                              : Border.all(
                                color:
                                    isDarkMode
                                        ? Colors.grey.shade600
                                        : primaryColor.withOpacity(0.3),
                                width: 2,
                              ),
                    ),
                  );
                }),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    _buildNumPadRow(['1', '2', '3']),
                    _buildNumPadRow(['4', '5', '6']),
                    _buildNumPadRow(['7', '8', '9']),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // --- NEW: CONDITIONAL RESET BUTTON ---
                        SizedBox(
                          width: 80,
                          height: 80,
                          child:
                              _isConfirming
                                  ? TextButton(
                                    onPressed: _resetSetup,
                                    child: Text(
                                      "Reset",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isDarkMode
                                                ? Colors.white70
                                                : Colors.black54,
                                      ),
                                    ),
                                  )
                                  : null, // Leaves the space completely empty if on step 1
                        ),
                        _buildNumPadButton('0'),
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: IconButton(
                            onPressed: _onBackspaceTap,
                            icon: Icon(
                              Icons.backspace_outlined,
                              size: 30,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumPadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((num) => _buildNumPadButton(num)).toList(),
    );
  }

  Widget _buildNumPadButton(String number) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _onNumPadTap(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Text(
          number,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
