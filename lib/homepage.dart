import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';

import 'profile_page.dart';
import 'setup_profile_page.dart';
import 'notification_page.dart';
import 'login_page.dart';
import 'theme_selection_page.dart';
import 'scan_page.dart' if (dart.library.html) 'scan_page_web.dart';
import 'expenses_page.dart';
import 'income_page.dart';
import 'charts_page.dart';
import 'goals_page.dart';
import 'change_passcode_page.dart';

// --- WRAPPER FOR SHOWCASE VIEW ---
class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      blurValue: 2.0,
      disableBarrierInteraction:
          true, // Forces user to use our Next/Skip buttons
      builder: (context) => const _UserHomeContent(),
    );
  }
}

class _UserHomeContent extends StatefulWidget {
  const _UserHomeContent();

  @override
  State<_UserHomeContent> createState() => _UserHomeContentState();
}

class _UserHomeContentState extends State<_UserHomeContent> {
  final supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- TUTORIAL KEYS ---
  final GlobalKey _profileMenuKey = GlobalKey();
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _scanMenuKey = GlobalKey();

  // --- MASTER TUTORIAL STATE ---
  bool _isTutorialActive = false;
  String _tutorialPhase = 'none';

  String _username = "Loading...";
  String _email = "";
  String? _avatarUrl;
  int _selectedIndex = 0;

  int _lastSeenNotificationId = 0;

  double _totalBalance = 0.0;
  double _pastBalance = 0.0;
  double _thisMonthNet = 0.0;

  // --- NEW: UPCOMING DUES & DETAILS ---
  double _upcomingDues = 0.0;
  List<Map<String, dynamic>> _upcomingDuesDetails = [];

  bool _isLoadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadLastSeenNotification();
    _calculateTotalBalance();

    // --- THE AUTOMATED ENGINE ---
    _processRecurringIncomes();

    // Trigger tutorial check on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartTutorial();
    });
  }

  // ==========================================
  // ⚙️ THE AUTOMATED RECURRING ENGINE ⚙️
  // ==========================================
  Future<void> _processRecurringIncomes() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('income')
          .select()
          .eq('user_id', user.id)
          .eq('is_recurring', true)
          .order('created_at', ascending: false);

      if (response.isEmpty) return;

      final Map<String, Map<String, dynamic>> latestIncomes = {};
      for (var income in response) {
        final source = income['source'] as String;
        if (!latestIncomes.containsKey(source)) {
          latestIncomes[source] = income;
        }
      }

      final now = DateTime.now();
      bool hasNewIncomes = false;

      for (var income in latestIncomes.values) {
        final createdAt = DateTime.parse(income['created_at']).toLocal();

        if (createdAt.year < now.year ||
            (createdAt.year == now.year && createdAt.month < now.month)) {
          await supabase.from('income').insert({
            'user_id': user.id,
            'amount': (income['amount'] as num).toDouble(),
            'source': income['source'],
            'category_id': income['category_id'],
            'is_recurring': true,
            'created_at': now.toUtc().toIso8601String(),
          });
          hasNewIncomes = true;
        }
      }

      if (hasNewIncomes) {
        _calculateTotalBalance();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "🔄 Recurring incomes automatically processed for this month!",
              ),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Auto-Engine Error: $e");
    }
  }

  Future<void> _checkAndStartTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final user = supabase.auth.currentUser;
    if (user == null) return;

    bool hasSeenTutorial =
        prefs.getBool('has_seen_full_tutorial_${user.id}') ?? false;

    if (!hasSeenTutorial && mounted) {
      _startHomeTutorial();
    }
  }

  void _startHomeTutorial() {
    setState(() {
      _isTutorialActive = true;
      _tutorialPhase = 'home';
      _selectedIndex = 0;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        ShowCaseWidget.of(
          context,
        ).startShowCase([_profileMenuKey, _balanceKey]);
      }
    });
  }

  void _advanceTutorial(int nextTabIndex, String nextPhase) {
    setState(() {
      _selectedIndex = nextTabIndex;
      _tutorialPhase = nextPhase;
    });
  }

  Future<void> _skipOrFinishTutorial() async {
    setState(() {
      _isTutorialActive = false;
      _tutorialPhase = 'none';
    });
    final prefs = await SharedPreferences.getInstance();
    final user = supabase.auth.currentUser;
    if (user != null) {
      await prefs.setBool('has_seen_full_tutorial_${user.id}', true);
    }
  }

  Widget _buildCustomTooltip({
    required BuildContext context,
    required String title,
    required String description,
    required bool isLastStep,
    required Color primaryColor,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  ShowCaseWidget.of(context).dismiss();
                  _skipOrFinishTutorial();
                },
                child: const Text("Skip", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  if (isLastStep) {
                    ShowCaseWidget.of(context).dismiss();
                    _advanceTutorial(0, 'income');
                  } else {
                    ShowCaseWidget.of(context).next();
                  }
                },
                child: const Text(
                  "Next",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- UPGRADED CALCULATE TOTAL BALANCE WITH BREAKDOWN GENERATOR ---
  Future<void> _calculateTotalBalance() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final incomeResponse = await supabase
          .from('income')
          .select('amount, created_at')
          .eq('user_id', user.id);
      final expenseResponse = await supabase
          .from('expenses')
          .select('amount, created_at')
          .eq('user_id', user.id);

      final commitmentsResponse = await supabase
          .from('commitments')
          .select('name, monthly_payment')
          .eq('user_id', user.id);
      final goalsResponse = await supabase
          .from('goals')
          .select('name, target_amount, saved_amount, target_date')
          .eq('user_id', user.id);

      double totalInc = 0;
      double totalExp = 0;
      double pastInc = 0;
      double pastExp = 0;
      double thisMonthInc = 0;
      double thisMonthExp = 0;

      double upcoming = 0;
      List<Map<String, dynamic>> tempDuesDetails = [];

      final now = DateTime.now();

      for (var row in incomeResponse) {
        double amt = (row['amount'] ?? 0).toDouble();
        totalInc += amt;
        DateTime date = DateTime.parse(row['created_at']).toLocal();
        if (date.year == now.year && date.month == now.month) {
          thisMonthInc += amt;
        } else if (date.isBefore(DateTime(now.year, now.month, 1))) {
          pastInc += amt;
        }
      }

      for (var row in expenseResponse) {
        double amt = (row['amount'] ?? 0).toDouble();
        totalExp += amt;
        DateTime date = DateTime.parse(row['created_at']).toLocal();
        if (date.year == now.year && date.month == now.month) {
          thisMonthExp += amt;
        } else if (date.isBefore(DateTime(now.year, now.month, 1))) {
          pastExp += amt;
        }
      }

      // --- CALCULATE UPCOMING DUES & SAVE DETAILS ---
      for (var c in commitmentsResponse) {
        double amt = (c['monthly_payment'] as num?)?.toDouble() ?? 0.0;
        if (amt > 0) {
          upcoming += amt;
          tempDuesDetails.add({
            'name': c['name'] ?? 'Unknown Debt',
            'amount': amt,
            'type': 'Commitment',
            'icon': Icons.credit_score,
            'color': Colors.redAccent,
          });
        }
      }

      for (var g in goalsResponse) {
        if (g['target_date'] != null) {
          DateTime targetDate = DateTime.parse(g['target_date']).toLocal();
          double target = (g['target_amount'] as num?)?.toDouble() ?? 0.0;
          double saved = (g['saved_amount'] as num?)?.toDouble() ?? 0.0;

          int monthsLeft =
              (targetDate.year - now.year) * 12 + targetDate.month - now.month;
          if (monthsLeft < 1) monthsLeft = 1;

          double remaining = target - saved;
          if (remaining > 0) {
            double monthly = remaining / monthsLeft;
            upcoming += monthly;
            tempDuesDetails.add({
              'name': g['name'] ?? 'Unknown Goal',
              'amount': monthly,
              'type': 'Goal Target',
              'icon': Icons.savings,
              'color': Colors.green,
            });
          }
        }
      }

      // Sort the list so highest amounts are at the top
      tempDuesDetails.sort(
        (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
      );

      if (mounted) {
        setState(() {
          _totalBalance = totalInc - totalExp;
          _pastBalance = pastInc - pastExp;
          _thisMonthNet = thisMonthInc - thisMonthExp;
          _upcomingDues = upcoming;
          _upcomingDuesDetails = tempDuesDetails; // Save the detailed list!
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      debugPrint("Error calculating balance: $e");
      if (mounted) setState(() => _isLoadingBalance = false);
    }
  }

  // --- NEW: THE BOTTOM SHEET FOR UPCOMING DUES ---
  void _showUpcomingDuesSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Upcoming Dues",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    NumberFormat.currency(
                      locale: 'en_MY',
                      symbol: 'RM ',
                    ).format(_upcomingDues),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                "Your expected targets and commitments for this month.",
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),

              const SizedBox(height: 20),
              Divider(color: Colors.grey.withOpacity(0.2)),
              const SizedBox(height: 10),

              Expanded(
                child:
                    _upcomingDuesDetails.isEmpty
                        ? const Center(
                          child: Text(
                            "No upcoming dues or targets!",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                        : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _upcomingDuesDetails.length,
                          itemBuilder: (context, index) {
                            final item = _upcomingDuesDetails[index];
                            final amount = item['amount'] as double;
                            final color = item['color'] as Color;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    isDarkMode
                                        ? Colors.grey[850]
                                        : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      item['icon'],
                                      color: color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color:
                                                isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          item['type'],
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "RM ${amount.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadLastSeenNotification() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _lastSeenNotificationId = prefs.getInt('lastSeenNotificationId') ?? 0;
      });
    }
  }

  Future<void> _markNotificationsAsRead(int latestId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSeenNotificationId', latestId);
    if (mounted) {
      setState(() {
        _lastSeenNotificationId = latestId;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        setState(() => _email = user.email ?? "");

        final data =
            await supabase
                .from('profiles')
                .select('full_name, username, avatar_url')
                .eq('id', user.id)
                .maybeSingle();

        if (data == null ||
            data['username'] == null ||
            (data['username'] as String).isEmpty) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SetupProfilePage()),
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _username = data['username'] ?? "User";
            _avatarUrl = data['avatar_url'];
          });
        }
      }
    } catch (e) {
      // Handle error
    }
  }

  void _onItemTapped(int index) {
    if (_isTutorialActive) return;

    setState(() => _selectedIndex = index);
    _calculateTotalBalance();
  }

  List<Widget> get _pages => <Widget>[
    IncomePage(
      showTutorial: _isTutorialActive && _tutorialPhase == 'income',
      onTutorialNext: () => _advanceTutorial(1, 'expenses'),
      onTutorialSkip: _skipOrFinishTutorial,
    ),
    ExpensesPage(
      showTutorial: _isTutorialActive && _tutorialPhase == 'expenses',
      onTutorialNext: () => _advanceTutorial(2, 'scan'),
      onTutorialSkip: _skipOrFinishTutorial,
    ),
    ScanPage(
      showTutorial: _isTutorialActive && _tutorialPhase == 'scan',
      onTutorialNext: () => _advanceTutorial(3, 'charts'),
      onTutorialSkip: _skipOrFinishTutorial,
    ),
    ChartsPage(
      showTutorial: _isTutorialActive && _tutorialPhase == 'charts',
      onTutorialNext: () => _advanceTutorial(4, 'goals'),
      onTutorialSkip: _skipOrFinishTutorial,
    ),
    GoalsPage(
      showTutorial: _isTutorialActive && _tutorialPhase == 'goals',
      onTutorialNext: _skipOrFinishTutorial,
      onTutorialSkip: _skipOrFinishTutorial,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bool showBalance = _selectedIndex == 0 || _selectedIndex == 1;

    final primaryColor = Theme.of(context).colorScheme.primary;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color drawerIconColor = isDarkMode ? Colors.white : primaryColor;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDarkMode ? scaffoldBg : Colors.white,
      extendBody: false,

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(primaryColor, Colors.white, 0.2)!,
                    primaryColor,
                    Color.lerp(primaryColor, Colors.black, 0.4)!,
                  ],
                ),
              ),
              child: ClipRRect(
                child: Stack(
                  children: [
                    Positioned(
                      top: -40,
                      right: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -60,
                      left: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 25,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.white,
                              backgroundImage:
                                  _avatarUrl != null
                                      ? NetworkImage(_avatarUrl!)
                                      : null,
                              child:
                                  _avatarUrl == null
                                      ? Icon(
                                        Icons.person,
                                        size: 40,
                                        color: primaryColor,
                                      )
                                      : null,
                            ),
                            const SizedBox(height: 15),
                            Text(
                              _username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _email,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person, color: drawerIconColor),
              title: const Text('Manage Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                ).then((_) => _loadUserProfile());
              },
            ),
            ListTile(
              leading: Icon(Icons.palette, color: drawerIconColor),
              title: const Text('Appearance & Theme'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ThemeSelectionPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.password, color: drawerIconColor),
              title: const Text('Change Passcode'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChangePasscodePage(),
                  ),
                );
              },
            ),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.help_outline, color: Colors.blueAccent),
              title: const Text(
                'Replay App Tutorial',
                style: TextStyle(color: Colors.blueAccent),
              ),
              onTap: () {
                Navigator.pop(context);
                _startHomeTutorial();
              },
            ),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text("Logout"),
                        content: const Text(
                          "Are you sure you want to log out?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              try {
                                await supabase.auth.signOut();
                              } catch (e) {
                                debugPrint("Logout Error: $e");
                              }
                              if (mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                  (Route<dynamic> route) => false,
                                );
                              }
                            },
                            child: const Text(
                              "Logout",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
      ),

      body: Container(
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
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(primaryColor, Colors.white, 0.2)!,
                    primaryColor,
                    Color.lerp(primaryColor, Colors.black, 0.4)!,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -40,
                      right: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -60,
                      left: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: kIsWeb ? 20 : 50,
                        left: 20,
                        right: 20,
                        bottom: showBalance ? 30 : 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Showcase.withWidget(
                                key: _profileMenuKey,
                                width: 280,
                                height: 160,
                                targetShapeBorder: const CircleBorder(),
                                container: _buildCustomTooltip(
                                  context: context,
                                  title: 'Main Menu',
                                  description:
                                      'Tap your profile icon to change themes, update your passcode, or log out.',
                                  isLastStep: false,
                                  primaryColor: primaryColor,
                                ),
                                child: GestureDetector(
                                  onTap:
                                      () =>
                                          _scaffoldKey.currentState
                                              ?.openDrawer(),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.white,
                                      backgroundImage:
                                          _avatarUrl != null
                                              ? NetworkImage(_avatarUrl!)
                                              : null,
                                      child:
                                          _avatarUrl == null
                                              ? Icon(
                                                Icons.person,
                                                color: primaryColor,
                                              )
                                              : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Welcome back,",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              StreamBuilder(
                                stream: supabase
                                    .from('notifications')
                                    .stream(primaryKey: ['id'])
                                    .order('created_at', ascending: false),
                                builder: (context, snapshot) {
                                  bool showRedDot = false;
                                  int latestId = 0;

                                  if (snapshot.hasData &&
                                      snapshot.data!.isNotEmpty) {
                                    final List<Map<String, dynamic>> data =
                                        snapshot.data!;
                                    data.sort(
                                      (a, b) => (b['id'] as int).compareTo(
                                        a['id'] as int,
                                      ),
                                    );
                                    latestId = data.first['id'] as int;
                                    if (latestId > _lastSeenNotificationId) {
                                      showRedDot = true;
                                    }
                                  }

                                  return Stack(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          if (latestId > 0) {
                                            _markNotificationsAsRead(latestId);
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      const NotificationPage(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.notifications_outlined,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                      if (showRedDot)
                                        Positioned(
                                          right: 12,
                                          top: 12,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: primaryColor,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),

                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child:
                                showBalance
                                    ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 25),
                                        const Text(
                                          "Total Balance",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 5),

                                        Showcase.withWidget(
                                          key: _balanceKey,
                                          width: 280,
                                          height: 160,
                                          targetPadding: const EdgeInsets.all(
                                            8,
                                          ),
                                          container: _buildCustomTooltip(
                                            context: context,
                                            title: 'Your Cashflow',
                                            description:
                                                'Here is your total balance, past month totals, and your net earnings for this month.',
                                            isLastStep: true,
                                            primaryColor: primaryColor,
                                          ),
                                          child:
                                              _isLoadingBalance
                                                  ? const SizedBox(
                                                    height: 30,
                                                    width: 30,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                  : Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        NumberFormat.currency(
                                                          locale: 'en_MY',
                                                          symbol: 'RM ',
                                                        ).format(_totalBalance),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 38,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          letterSpacing: -1,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: [
                                                          _buildBalanceBadge(
                                                            "Past Months",
                                                            _pastBalance,
                                                            Colors
                                                                .blueAccent
                                                                .shade100,
                                                            showPlusMinus: true,
                                                          ),
                                                          _buildBalanceBadge(
                                                            "This Month Net",
                                                            _thisMonthNet,
                                                            _thisMonthNet >= 0
                                                                ? Colors
                                                                    .greenAccent
                                                                : Colors
                                                                    .redAccent
                                                                    .shade100,
                                                            showPlusMinus: true,
                                                          ),

                                                          // --- THE CLICKABLE UPCOMING DUES BADGE ---
                                                          _buildBalanceBadge(
                                                            "Upcoming Dues",
                                                            _upcomingDues,
                                                            Colors.orangeAccent,
                                                            showPlusMinus:
                                                                false,
                                                            onTap:
                                                                _showUpcomingDuesSheet,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                        ),
                                      ],
                                    )
                                    : const SizedBox(width: double.infinity),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _pages[_selectedIndex]),
          ],
        ),
      ),

      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 15,
          right: 15,
          top: 10,
          bottom:
              MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom
                  : 15,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildModernNavItem(
              0,
              Icons.attach_money,
              "Income",
              primaryColor,
              isDarkMode,
            ),
            _buildModernNavItem(
              1,
              Icons.receipt_long,
              "Expenses",
              primaryColor,
              isDarkMode,
            ),

            Showcase.withWidget(
              key: _scanMenuKey,
              width: 280,
              height: 160,
              targetShapeBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              container: _buildCustomTooltip(
                context: context,
                title: 'Smart Scanner',
                description:
                    'Don\'t type! Just snap a picture of your receipts and our AI will read them automatically.',
                isLastStep: true,
                primaryColor: primaryColor,
              ),
              child: _buildModernNavItem(
                2,
                Icons.qr_code_scanner,
                "Scan",
                primaryColor,
                isDarkMode,
              ),
            ),

            _buildModernNavItem(
              3,
              Icons.bar_chart,
              "Charts",
              primaryColor,
              isDarkMode,
            ),
            _buildModernNavItem(
              4,
              Icons.track_changes,
              "Targets",
              primaryColor,
              isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  // --- UPDATED BALANCE BADGE (NOW SUPPORTS TAP) ---
  Widget _buildBalanceBadge(
    String label,
    double amount,
    Color iconColor, {
    bool showPlusMinus = true,
    VoidCallback? onTap,
  }) {
    String prefix = "";
    if (showPlusMinus) {
      if (amount > 0) prefix = "+";
      if (amount < 0) prefix = "-";
    }

    String formattedAmount = NumberFormat.currency(
      locale: 'en_MY',
      symbol: 'RM ',
    ).format(amount.abs());

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            "$prefix$formattedAmount",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: badge,
        ),
      );
    }

    return badge;
  }

  Widget _buildModernNavItem(
    int index,
    IconData icon,
    String label,
    Color primaryColor,
    bool isDarkMode,
  ) {
    final isSelected = _selectedIndex == index;
    final unselectedColor = Colors.grey.shade400;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.0 : 12.0,
          vertical: 12.0,
        ),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? primaryColor.withOpacity(isDarkMode ? 0.3 : 0.15)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? (isDarkMode ? Colors.white : primaryColor)
                      : unselectedColor,
              size: 26,
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  width: isSelected ? null : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
