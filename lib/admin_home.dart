import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <-- IMPORT ADDED HERE
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'admin_user_details.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final supabase = Supabase.instance.client;
  int _selectedIndex = 0;

  // --- LOGOUT FUNCTION ---
  void _handleLogout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Logout"),
            content: const Text("Are you sure you want to exit Admin mode?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await supabase.auth.signOut();
                  if (context.mounted) {
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
  }

  // Titles for the custom header
  final List<String> _titles = [
    "System Overview",
    "Manage Users",
    "Broadcast Center",
    "App Categories",
    "Tax Deductions",
    "Security & Spam",
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final adminActiveColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
      extendBody: false,
      body: Column(
        children: [
          // --- SLEEK BLACK ADMIN HEADER ---
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF424242), // Lighter Grey
                  Color(0xFF212121), // Dark Grey
                  Colors.black, // Pure Black
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
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
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    left: -50,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.02),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 20,
                      left: 24,
                      right: 24,
                      bottom: 30,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Admin Control",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _titles[_selectedIndex],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.logout,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: _handleLogout,
                            tooltip: "Logout",
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- BODY CONTENT ---
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const AdminOverviewTab(), // Tab 0
                const AdminUserListTab(), // Tab 1
                const AdminAnnounceTab(), // Tab 2
                const AdminCategoryTab(), // Tab 3
                const AdminTaxTab(), // Tab 4
                const AdminSecurityTab(), // Tab 5
              ],
            ),
          ),
        ],
      ),

      // --- PILL-STYLE BOTTOM NAVIGATION ---
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 5,
          right: 5,
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
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildModernNavItem(
              0,
              Icons.dashboard,
              "Home",
              adminActiveColor,
              isDarkMode,
            ),
            _buildModernNavItem(
              1,
              Icons.people,
              "Users",
              adminActiveColor,
              isDarkMode,
            ),
            _buildModernNavItem(
              2,
              Icons.campaign,
              "News",
              adminActiveColor,
              isDarkMode,
            ),
            _buildModernNavItem(
              3,
              Icons.category,
              "Tags",
              adminActiveColor,
              isDarkMode,
            ),
            _buildModernNavItem(
              4,
              Icons.request_quote,
              "Tax",
              adminActiveColor,
              isDarkMode,
            ),
            _buildModernNavItem(
              5,
              Icons.security,
              "Spam",
              adminActiveColor,
              isDarkMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernNavItem(
    int index,
    IconData icon,
    String label,
    Color activeColor,
    bool isDarkMode,
  ) {
    final isSelected = _selectedIndex == index;
    final unselectedColor = Colors.grey.shade400;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 10.0 : 6.0,
          vertical: 12.0,
        ),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? activeColor.withOpacity(isDarkMode ? 0.2 : 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : unselectedColor,
              size: 22,
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  width: isSelected ? null : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: activeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
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

// ==========================================
// TAB 0: SYSTEM OVERVIEW (UPDATED METRICS)
// ==========================================
class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});
  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  int _totalUsers = 0;
  int _totalTransactions = 0;
  int _totalScans = 0;
  int _totalBroadcasts = 0;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchGlobalData();
  }

  Future<void> _fetchGlobalData() async {
    try {
      // 1. Fetch Users
      final profileData = await supabase
          .from('profiles')
          .select('username, email, created_at')
          .order('created_at', ascending: false);

      // 2. Fetch Income & Expenses to count transactions and scans
      final incData = await supabase.from('income').select('id, is_scanned');
      final expData = await supabase.from('expenses').select('id, is_scanned');

      // 3. Fetch Broadcasts
      final notifData = await supabase.from('notifications').select('id');

      // Calculate Scans
      int scanCount = 0;
      for (var row in incData) {
        if (row['is_scanned'] == true) scanCount++;
      }
      for (var row in expData) {
        if (row['is_scanned'] == true) scanCount++;
      }

      if (mounted) {
        setState(() {
          _totalUsers = profileData.length;
          _logs = List<Map<String, dynamic>>.from(profileData);
          _totalTransactions = incData.length + expData.length;
          _totalScans = scanCount;
          _totalBroadcasts = notifData.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Overview Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black87),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchGlobalData,
      color: Colors.black87,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Total Users",
                  _totalUsers.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  "Transactions Logged",
                  _totalTransactions.toString(),
                  Icons.receipt_long,
                  Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "Total Scans",
                  _totalScans.toString(),
                  Icons.document_scanner,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  "System Broadcasts",
                  _totalBroadcasts.toString(),
                  Icons.campaign,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),
          const Text(
            "System Logs (New Users)",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          if (_logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  "No users registered yet.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._logs.take(10).map((log) {
              final rawDate = log['created_at'];
              String dateStr =
                  rawDate != null
                      ? DateFormat(
                        'MMM d, y - h:mm a',
                      ).format(DateTime.parse(rawDate).toLocal())
                      : "Unknown";

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.greenAccent,
                    child: Icon(Icons.person_add, color: Colors.white),
                  ),
                  title: Text(
                    log['username'] ?? "Unknown",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${log['email']}\n$dateStr"),
                  isThreeLine: true,
                ),
              );
            }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 1: MANAGE USERS
// ==========================================
class AdminUserListTab extends StatefulWidget {
  const AdminUserListTab({super.key});
  @override
  State<AdminUserListTab> createState() => _AdminUserListTabState();
}

class _AdminUserListTabState extends State<AdminUserListTab> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final data = await supabase
          .from('profiles')
          .select(
            'id, full_name, username, email, role, created_at, avatar_url',
          )
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await supabase.rpc(
        'delete_user_by_id',
        params: {'target_user_id': userId},
      );
      _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spam account permanently deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black87),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchUsers,
      color: Colors.black87,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final isMe = user['id'] == supabase.auth.currentUser?.id;
          final avatarUrl = user['avatar_url'];

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor:
                    user['role'] == 'admin'
                        ? Colors.black87
                        : Colors.deepPurple.shade50,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child:
                    avatarUrl == null
                        ? Icon(
                          user['role'] == 'admin' ? Icons.shield : Icons.person,
                          color:
                              user['role'] == 'admin'
                                  ? Colors.white
                                  : Colors.deepPurple,
                        )
                        : null,
              ),
              title: Text(
                user['username'] ?? "Unknown",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(user['email'] ?? "No Email"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminUserDetailsPage(user: user),
                  ),
                );
              },
              trailing:
                  isMe
                      ? const Chip(
                        label: Text("You"),
                        backgroundColor: Colors.grey,
                      )
                      : IconButton(
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        tooltip: "Delete Spam Account",
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: const Text("Delete User?"),
                                  content: Text(
                                    "Are you sure you want to permanently delete ${user['username']}? All their financial data will be wiped.",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _deleteUser(user['id']);
                                      },
                                      child: const Text(
                                        "Delete",
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                          );
                        },
                      ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// TAB 2: ANNOUNCEMENTS (SECURED WITH DOTENV!)
// ==========================================
class AdminAnnounceTab extends StatefulWidget {
  const AdminAnnounceTab({super.key});
  @override
  State<AdminAnnounceTab> createState() => _AdminAnnounceTabState();
}

class _AdminAnnounceTabState extends State<AdminAnnounceTab> {
  final supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _msgController = TextEditingController();
  String _selectedType = 'News';
  bool _isSending = false;

  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final data = await supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(data);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.isEmpty || _msgController.text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await supabase.from('notifications').insert({
        'title': _titleController.text,
        'message': _msgController.text,
        'type': _selectedType,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      await _sendPushNotification(_titleController.text, _msgController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Notification Broadcasted!"),
            backgroundColor: Colors.green,
          ),
        );
        _titleController.clear();
        _msgController.clear();
        FocusScope.of(context).unfocus();
        _fetchHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isSending = false);
  }

  // --- UPDATED SECURE PUSH NOTIFICATION ---
  Future<void> _sendPushNotification(String title, String content) async {
    final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID']!;
    final oneSignalApiKey = dotenv.env['ONESIGNAL_API_KEY']!;

    try {
      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": "Basic $oneSignalApiKey",
        },
        body: jsonEncode({
          "app_id": oneSignalAppId,
          "included_segments": ["All"],
          "headings": {"en": title},
          "contents": {"en": content},
        }),
      );
    } catch (e) {
      debugPrint("Failed to send push: $e");
    }
  }

  Future<void> _deleteNotification(int id) async {
    try {
      await supabase.from('notifications').delete().eq('id', id);
      _fetchHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Broadcast removed from history."),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _openEditDialog(Map<String, dynamic> item) {
    final editTitleController = TextEditingController(text: item['title']);
    final editMsgController = TextEditingController(text: item['message']);
    String editType = item['type'] ?? 'News';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Broadcast"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: editType,
                      decoration: const InputDecoration(labelText: "Type"),
                      items:
                          ['News', 'Update', 'Patch Note']
                              .map(
                                (val) => DropdownMenuItem(
                                  value: val,
                                  child: Text(val),
                                ),
                              )
                              .toList(),
                      onChanged: (val) => setDialogState(() => editType = val!),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: editTitleController,
                      decoration: const InputDecoration(labelText: "Title"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: editMsgController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: "Message"),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Note: Editing this will update the in-app history, but cannot recall push notifications already sent to devices.",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await supabase
                          .from('notifications')
                          .update({
                            'title': editTitleController.text,
                            'message': editMsgController.text,
                            'type': editType,
                          })
                          .eq('id', item['id']);
                      _fetchHistory();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Broadcast Updated!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "Update",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchHistory,
      color: Colors.black87,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text(
            "Compose Announcement",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: InputDecoration(
              labelText: "Type",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            items:
                ['News', 'Update', 'Patch Note']
                    .map(
                      (val) => DropdownMenuItem(value: val, child: Text(val)),
                    )
                    .toList(),
            onChanged: (val) => setState(() => _selectedType = val!),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: "Title",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _msgController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: "Message",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          ElevButton(
            _isSending,
            "Broadcast via OneSignal",
            Icons.send,
            _sendNotification,
            Colors.black87,
          ),

          const SizedBox(height: 40),
          Divider(color: Colors.grey.withOpacity(0.3), thickness: 1),
          const SizedBox(height: 20),

          const Text(
            "Broadcast History",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          if (_isLoadingHistory)
            const Center(
              child: CircularProgressIndicator(color: Colors.black87),
            )
          else if (_history.isEmpty)
            const Center(
              child: Text(
                "No past broadcasts.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._history.map((item) {
              DateTime date = DateTime.parse(item['created_at']).toLocal();
              String formattedDate = DateFormat(
                'dd MMM yyyy • h:mm a',
              ).format(date);

              IconData typeIcon = Icons.campaign;
              Color typeColor = Colors.blueAccent;
              if (item['type'] == 'Update') {
                typeIcon = Icons.system_update;
                typeColor = Colors.orange;
              }
              if (item['type'] == 'Patch Note') {
                typeIcon = Icons.build;
                typeColor = Colors.deepPurple;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: typeColor.withOpacity(0.1),
                    child: Icon(typeIcon, color: typeColor, size: 20),
                  ),
                  title: Text(
                    item['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    formattedDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item['message'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(
                            Icons.edit,
                            size: 18,
                            color: Colors.blue,
                          ),
                          label: const Text(
                            "Edit",
                            style: TextStyle(color: Colors.blue),
                          ),
                          onPressed: () => _openEditDialog(item),
                        ),
                        TextButton.icon(
                          icon: const Icon(
                            Icons.delete,
                            size: 18,
                            color: Colors.red,
                          ),
                          label: const Text(
                            "Delete",
                            style: TextStyle(color: Colors.red),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text("Delete Broadcast?"),
                                    content: const Text(
                                      "Remove this message from the app history?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _deleteNotification(item['id']);
                                        },
                                        child: const Text(
                                          "Delete",
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
                  ],
                ),
              );
            }),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 3: APP CATEGORIES (SPLIT: INCOME / EXPENSES)
// ==========================================
class AdminCategoryTab extends StatelessWidget {
  const AdminCategoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // CUSTOM TAB BAR
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                // Use black indicator for Admin theme
                color: isDarkMode ? Colors.white : Colors.black87,
                borderRadius: BorderRadius.circular(25),
              ),
              labelColor: isDarkMode ? Colors.black : Colors.white,
              unselectedLabelColor:
                  isDarkMode ? Colors.white70 : Colors.black54,
              tabs: const [Tab(text: "Income"), Tab(text: "Expenses")],
            ),
          ),
          // TAB VIEWS
          const Expanded(
            child: TabBarView(
              children: [
                CategoryListManager(tableName: 'income_categories'),
                CategoryListManager(tableName: 'expense_categories'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable Widget for managing categories based on table name
class CategoryListManager extends StatefulWidget {
  final String tableName;

  const CategoryListManager({super.key, required this.tableName});

  @override
  State<CategoryListManager> createState() => _CategoryListManagerState();
}

class _CategoryListManagerState extends State<CategoryListManager> {
  final supabase = Supabase.instance.client;
  final _catController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await supabase.from(widget.tableName).select().order('id');
      if (mounted) {
        setState(() => _categories = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint("Table ${widget.tableName} might not exist yet: $e");
    }
  }

  Future<void> _addCategory() async {
    if (_catController.text.isEmpty) return;
    try {
      await supabase.from(widget.tableName).insert({
        'name': _catController.text,
      });
      _catController.clear();
      _fetchCategories();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCategory(int id) async {
    await supabase.from(widget.tableName).delete().eq('id', id);
    _fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _catController,
                  decoration: InputDecoration(
                    labelText: "New Category Name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _addCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchCategories,
            color: Colors.black87,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.black87,
                      child: Icon(
                        Icons.category,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      cat['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteCategory(cat['id']),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// TAB 4: TAX DEDUCTIONS
// ==========================================
class AdminTaxTab extends StatefulWidget {
  const AdminTaxTab({super.key});
  @override
  State<AdminTaxTab> createState() => _AdminTaxTabState();
}

class _AdminTaxTabState extends State<AdminTaxTab> {
  final supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  List<Map<String, dynamic>> _deductions = [];

  @override
  void initState() {
    super.initState();
    _fetchDeductions();
  }

  Future<void> _fetchDeductions() async {
    try {
      final data = await supabase.from('tax_deductions').select().order('id');
      if (mounted) {
        setState(() => _deductions = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint("Tax Table Error: $e");
    }
  }

  Future<void> _addDeduction() async {
    if (_nameController.text.isEmpty || _amountController.text.isEmpty) return;
    try {
      await supabase.from('tax_deductions').insert({
        'name': _nameController.text,
        'amount': double.tryParse(_amountController.text) ?? 0.0,
      });
      _nameController.clear();
      _amountController.clear();
      _fetchDeductions();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteDeduction(int id) async {
    await supabase.from('tax_deductions').delete().eq('id', id);
    _fetchDeductions();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Manage Standard Tax Reliefs",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Deduction Name (e.g., Medical)",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Max Relief Amount (RM)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _addDeduction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchDeductions,
            color: Colors.black87,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _deductions.length,
              itemBuilder: (context, index) {
                final ded = _deductions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.black87,
                      child: Icon(
                        Icons.money_off,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      ded['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("Max Relief: RM ${ded['amount']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteDeduction(ded['id']),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// TAB 5: SECURITY & SPAM MONITOR
// ==========================================
class AdminSecurityTab extends StatefulWidget {
  const AdminSecurityTab({super.key});
  @override
  State<AdminSecurityTab> createState() => _AdminSecurityTabState();
}

class _AdminSecurityTabState extends State<AdminSecurityTab> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _spamList = [];

  @override
  void initState() {
    super.initState();
    _fetchSpamData();
  }

  Future<void> _fetchSpamData() async {
    setState(() => _isLoading = true);
    try {
      final exps = await supabase
          .from('expenses')
          .select('user_id')
          .eq('is_scanned', true);
      final incs = await supabase
          .from('income')
          .select('user_id')
          .eq('is_scanned', true);
      final profiles = await supabase
          .from('profiles')
          .select('id, username, email, avatar_url');

      Map<String, int> scanCounts = {};
      for (var e in exps) {
        String uid = e['user_id'];
        scanCounts[uid] = (scanCounts[uid] ?? 0) + 1;
      }
      for (var i in incs) {
        String uid = i['user_id'];
        scanCounts[uid] = (scanCounts[uid] ?? 0) + 1;
      }

      List<Map<String, dynamic>> result = [];
      for (var p in profiles) {
        String uid = p['id'];
        int count = scanCounts[uid] ?? 0;
        if (count > 0) {
          result.add({...p, 'scan_count': count});
        }
      }

      result.sort(
        (a, b) => (b['scan_count'] as int).compareTo(a['scan_count'] as int),
      );

      if (mounted) {
        setState(() {
          _spamList = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Spam Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _wipeUserScans(String userId, String username) async {
    try {
      await supabase
          .from('expenses')
          .delete()
          .eq('user_id', userId)
          .eq('is_scanned', true);
      await supabase
          .from('income')
          .delete()
          .eq('user_id', userId)
          .eq('is_scanned', true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("All scans wiped for $username."),
            backgroundColor: Colors.green,
          ),
        );
      }
      _fetchSpamData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error wiping scans: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black87),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchSpamData,
      color: Colors.black87,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text(
            "Scanner Spam Detection",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          const Text(
            "Monitors users who may be abusing the OCR scanner API.",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          if (_spamList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text(
                  "No scanner activity detected.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else
            ..._spamList.map((user) {
              int count = user['scan_count'];
              bool isHighRisk = count >= 10;
              bool isWarning = count >= 5 && count < 10;

              Color cardColor = Colors.white;
              if (isHighRisk) cardColor = Colors.red.shade50;
              if (isWarning) cardColor = Colors.orange.shade50;

              return Card(
                color: cardColor,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isHighRisk
                            ? Colors.red
                            : (isWarning
                                ? Colors.orange
                                : Colors.grey.shade300),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    user['username'] ?? "Unknown",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isHighRisk
                        ? "High API Spam Risk"
                        : (isWarning ? "Elevated Activity" : "Normal Usage"),
                    style: TextStyle(
                      color:
                          isHighRisk
                              ? Colors.red
                              : (isWarning
                                  ? Colors.orange.shade800
                                  : Colors.grey),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    tooltip: "Wipe Scans",
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: const Text("Wipe Scans?"),
                              content: Text(
                                "Are you sure you want to permanently delete all $count scanned entries for ${user['username']}?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _wipeUserScans(
                                      user['id'],
                                      user['username'],
                                    );
                                  },
                                  child: const Text(
                                    "Wipe Data",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                      );
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// --- HELPER WIDGET FOR BUTTONS ---
Widget ElevButton(
  bool isLoading,
  String text,
  IconData icon,
  VoidCallback onPressed,
  Color color,
) {
  return SizedBox(
    width: double.infinity,
    height: 55,
    child: ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon:
          isLoading
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
              : Icon(icon),
      label: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );
}
