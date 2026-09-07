import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangePasscodePage extends StatefulWidget {
  const ChangePasscodePage({super.key});

  @override
  State<ChangePasscodePage> createState() => _ChangePasscodePageState();
}

class _ChangePasscodePageState extends State<ChangePasscodePage> {
  int _step = 0; // 0 = Current, 1 = New, 2 = Confirm
  String _enteredPin = "";
  String _savedPin = "";
  String _newPin = "";
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _loadCurrentPin();
  }

  Future<void> _loadCurrentPin() async {
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _savedPin =
            prefs.getString('user_pin_${user.id}') ??
            prefs.getString('user_pin') ??
            "";
      });
    }
  }

  void _onNumPadTap(String number) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += number;
        _errorMessage = "";
      });

      if (_enteredPin.length == 6) {
        // Slight delay so the user sees the last dot fill in before the screen changes
        Future.delayed(const Duration(milliseconds: 150), () {
          _processPinComplete();
        });
      }
    }
  }

  void _processPinComplete() async {
    if (_step == 0) {
      if (_enteredPin == _savedPin) {
        setState(() {
          _step = 1;
          _enteredPin = "";
        });
      } else {
        setState(() {
          _errorMessage = "Incorrect Current Passcode";
          _enteredPin = "";
        });
      }
    } else if (_step == 1) {
      setState(() {
        _newPin = _enteredPin;
        _step = 2;
        _enteredPin = "";
      });
    } else if (_step == 2) {
      if (_enteredPin == _newPin) {
        final prefs = await SharedPreferences.getInstance();
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await prefs.setString('user_pin_${user.id}', _newPin);
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Passcode Updated Successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = "Passcodes do not match. Try again.";
          _step = 1;
          _enteredPin = "";
          _newPin = "";
        });
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).colorScheme.primary;

    String title = "Enter Current Passcode";
    IconData lockIcon = Icons.lock_outline;
    if (_step == 1) {
      title = "Enter New Passcode";
      lockIcon = Icons.lock_reset;
    } else if (_step == 2) {
      title = "Confirm New Passcode";
      lockIcon = Icons.check_circle_outline;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: isDarkMode ? Colors.white : Colors.black87),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(lockIcon, size: 50, color: primaryColor),
              ),
              const SizedBox(height: 30),
              Text(
                title,
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
                        const SizedBox(width: 80, height: 80),
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
