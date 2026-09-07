import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'homepage.dart';

class PasscodePage extends StatefulWidget {
  const PasscodePage({super.key});

  @override
  State<PasscodePage> createState() => _PasscodePageState();
}

class _PasscodePageState extends State<PasscodePage> {
  // Only instantiate LocalAuthentication on non-web platforms
  final LocalAuthentication? auth = kIsWeb ? null : LocalAuthentication();

  String _enteredPin = "";
  final int _pinLength = 6;

  String _correctPin = "";
  bool _userWantsBiometrics = false;

  bool _isAuthenticating = false;
  bool _canCheckBiometrics = false;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _loadPinAndCheckBiometrics();
  }

  Future<void> _loadPinAndCheckBiometrics() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _correctPin = prefs.getString('user_pin') ?? "";
      _userWantsBiometrics = prefs.getBool('use_biometrics') ?? false;
    });

    // Skip all biometric checks on web
    if (kIsWeb || auth == null) return;

    try {
      final canCheckBiometrics = await auth!.canCheckBiometrics;
      final isDeviceSupported = await auth!.isDeviceSupported();

      setState(() {
        _canCheckBiometrics =
            canCheckBiometrics && isDeviceSupported && _userWantsBiometrics;
      });

      if (_canCheckBiometrics) {
        _authenticateBiometrics();
      }
    } on PlatformException catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _authenticateBiometrics() async {
    if (kIsWeb || auth == null) return;

    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
        _errorMessage = "";
      });
      authenticated = await auth!.authenticate(
        localizedReason: 'Scan your fingerprint or face to unlock FinSight',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint(e.toString());
    }

    if (mounted) {
      setState(() => _isAuthenticating = false);
      if (authenticated) {
        _unlockApp();
      }
    }
  }

  void _onNumPadTap(String number) {
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += number;
        _errorMessage = "";
      });

      if (_enteredPin.length == _pinLength) {
        _verifyPin();
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

  void _verifyPin() {
    if (_enteredPin == _correctPin) {
      _unlockApp();
    } else {
      setState(() {
        _enteredPin = "";
        _errorMessage = "Incorrect Passcode. Try again.";
      });
    }
  }

  void _unlockApp() {
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
                child: Icon(Icons.lock_outline, size: 50, color: primaryColor),
              ),
              const SizedBox(height: 30),
              Text(
                "Enter Passcode",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (index) {
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
                        SizedBox(
                          width: 80,
                          height: 80,
                          // Hide biometric button entirely on web
                          child:
                              (!kIsWeb && _canCheckBiometrics)
                                  ? IconButton(
                                    onPressed: _authenticateBiometrics,
                                    icon: Icon(
                                      Icons.fingerprint,
                                      size: 40,
                                      color:
                                          _isAuthenticating
                                              ? Colors.grey
                                              : primaryColor,
                                    ),
                                  )
                                  : null,
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
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
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
