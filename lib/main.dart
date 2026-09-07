import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for kIsWeb
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <-- 1. IMPORT DOTENV

import 'login_page.dart';
import 'admin_home.dart';
import 'theme_provider.dart';
import 'passcode_page.dart';
import 'setup_passcode_page.dart';
import 'update_password_page.dart';
import 'complete_profile_page.dart'; // Make sure this file exists!

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // <-- 2. LOAD .ENV BEFORE ANYTHING ELSE
  await dotenv.load(fileName: ".env");

  // <-- 3. USE SECURE VARIABLES FOR SUPABASE
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  if (!kIsWeb) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    // <-- 4. USE SECURE VARIABLE FOR ONESIGNAL
    OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID']!);
    OneSignal.Notifications.requestPermission(true);
  }

  await themeProvider.loadTheme();
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FinSight',
          themeMode:
              themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeProvider.primaryColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              backgroundColor: themeProvider.primaryColor,
              foregroundColor: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeProvider.primaryColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: themeProvider.primaryColor,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const UpdatePasswordPage()),
          (Route<dynamic> route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session != null) {
          return RoleCheckWrapper(key: ValueKey(session.user.id));
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

class RoleCheckWrapper extends StatefulWidget {
  const RoleCheckWrapper({super.key});
  @override
  State<RoleCheckWrapper> createState() => _RoleCheckWrapperState();
}

class _RoleCheckWrapperState extends State<RoleCheckWrapper> {
  String? _role;
  bool _needsProfileSetup = false;
  bool _loading = true;
  bool _hasSetupPin = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final user = supabase.auth.currentUser;

    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final bool hasPin = prefs.containsKey('user_pin');

      try {
        final data =
            await supabase
                .from('profiles')
                .select('role, username, full_name')
                .eq('id', user.id)
                .maybeSingle();

        // --- DEBUG PRINT: Check your VS Code Terminal! ---
        if (kDebugMode) {
          print("====================================");
          print("SUPABASE PROFILE DATA: $data");
          print("====================================");
        }

        if (mounted) {
          setState(() {
            _role = data?['role'] ?? 'user';

            // --- STRICT GOOGLE ONBOARDING CHECK ---
            if (data == null ||
                data['username'] == null ||
                data['username'].toString().trim().isEmpty ||
                data['username'].toString().trim() == 'New User' ||
                data['full_name'] == null ||
                data['full_name'].toString().trim().isEmpty) {
              _needsProfileSetup = true;
            } else {
              _needsProfileSetup = false;
            }

            _hasSetupPin = hasPin;
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _role = 'user';
            _needsProfileSetup =
                true; // Default to setup page if fetch totally fails
            _hasSetupPin = hasPin;
            _loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // --- 1. THE TRAP: FORCE PROFILE SETUP FIRST ---
    if (_needsProfileSetup) {
      return const CompleteProfilePage();
    }

    // --- 2. ADMIN INTERCEPT ---
    if (_role == 'admin') return const AdminHomePage();

    // --- 3. PIN SETUP OR PIN LOCK ---
    if (!_hasSetupPin) {
      return const SetupPasscodePage();
    } else {
      return const PasscodePage();
    }
  }
}
