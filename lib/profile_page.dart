import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart'; // --- 1. ADDED THIS IMPORT ---
import 'main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

  // --- 1. FETCH PROFILE & IMAGE ---
  Future<void> _getProfile() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data =
          await supabase
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();

      if (data != null) {
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _fullNameController.text = data['full_name'] ?? '';
          _avatarUrl = data['avatar_url'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _isLoading = false);
  }

  // --- 2. UPLOAD IMAGE FUNCTION ---
  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final imageExtension = image.path.split('.').last;
      final imagePath = '$userId/profile.$imageExtension';

      final bytes = await image.readAsBytes();
      await supabase.storage
          .from('avatars')
          .uploadBinary(
            imagePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = supabase.storage.from('avatars').getPublicUrl(imagePath);

      await supabase
          .from('profiles')
          .update({'avatar_url': imageUrl})
          .eq('id', userId);

      setState(() {
        _avatarUrl = imageUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image Uploaded!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  // --- 3. SECURE CHANGE PASSWORD ---
  Future<void> _changePassword() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while typing
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final isDarkMode =
                  Theme.of(context).brightness == Brightness.dark;
              final inputFillColor =
                  isDarkMode ? Colors.grey[800] : Colors.white;
              final primaryColor = Theme.of(context).colorScheme.primary;

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text(
                  "Change Password",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "For security purposes, please enter your current password to verify your identity.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    // OLD PASSWORD
                    TextField(
                      controller: oldPasswordController,
                      obscureText: obscureOld,
                      decoration: InputDecoration(
                        labelText: "Current Password",
                        filled: true,
                        fillColor: inputFillColor,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: primaryColor,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureOld
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setDialogState(() => obscureOld = !obscureOld);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // NEW PASSWORD
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: "New Password",
                        filled: true,
                        fillColor: inputFillColor,
                        prefixIcon: Icon(Icons.lock_reset, color: primaryColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setDialogState(() => obscureNew = !obscureNew);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isUpdating ? null : () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor, // Dynamic theme color!
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onPressed:
                        isUpdating
                            ? null
                            : () async {
                              final oldPass = oldPasswordController.text;
                              final newPass = newPasswordController.text;

                              if (oldPass.isEmpty || newPass.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please fill in both passwords',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (newPass.length < 8) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'New password must be at least 8 characters',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setDialogState(() => isUpdating = true);

                              try {
                                final email = supabase.auth.currentUser!.email!;

                                // 1. Verify old password securely via Supabase Auth
                                await supabase.auth.signInWithPassword(
                                  email: email,
                                  password: oldPass,
                                );

                                // 2. Update to new password
                                await supabase.auth.updateUser(
                                  UserAttributes(password: newPass),
                                );

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Password Updated Successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } on AuthException catch (e) {
                                String msg = e.message;
                                if (e.message.contains(
                                  "Invalid login credentials",
                                )) {
                                  msg =
                                      "Incorrect current password. Please try again.";
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(msg),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setDialogState(() => isUpdating = false);
                                }
                              }
                            },
                    child:
                        isUpdating
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              "Update Password",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                  ),
                ],
              );
            },
          ),
    );
  }

  // --- 4. DELETE ACCOUNT ---
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Delete Account?"),
            content: const Text(
              "This cannot be undone. All your data will be lost.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await supabase.rpc('delete_own_account');
      await supabase.auth.signOut();

      // --- 2. ADDED THIS: WIPE THE PIN FROM THE DEVICE ---
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_pin');

      // --- RETURN TO AUTH GATE ---
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- 5. UPDATE PROFILE TEXT ---
  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final updates = {
        'id': userId,
        'username': _usernameController.text,
        'full_name': _fullNameController.text,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await supabase.from('profiles').upsert(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile Saved!'),
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
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    // --- DYNAMIC THEME EXTRACTION ---
    final primaryColor = Theme.of(context).colorScheme.primary;
    final inputFillColor = isDarkMode ? Colors.grey[800] : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Manage Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 4,
        shadowColor: Colors.black45,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        // --- ADDED DYNAMIC TEXTURE TO APP BAR ---
        flexibleSpace: Container(
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
                Positioned(
                  top: 20,
                  left: 100,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          child:
              _isLoading
                  ? Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                  : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 20.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- PROFILE PICTURE SECTION ---
                        Center(
                          child: GestureDetector(
                            onTap: _uploadImage,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: primaryColor.withOpacity(0.5),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      if (!isDarkMode)
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.3),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor:
                                        isDarkMode
                                            ? Colors.grey[800]
                                            : Colors.white,
                                    backgroundImage:
                                        _avatarUrl != null
                                            ? NetworkImage(_avatarUrl!)
                                            : null,
                                    child:
                                        _avatarUrl == null
                                            ? Icon(
                                              Icons.person,
                                              size: 60,
                                              color: primaryColor.withOpacity(
                                                0.5,
                                              ),
                                            )
                                            : null,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // --- TEXT FIELDS ---
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            filled: true,
                            fillColor: inputFillColor,
                            prefixIcon: Icon(
                              Icons.alternate_email,
                              color: primaryColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            filled: true,
                            fillColor: inputFillColor,
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                              color: primaryColor,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // --- DANGER ZONE CARD ---
                        Container(
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[850] : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.1),
                            ),
                            boxShadow: [
                              if (!isDarkMode)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_reset,
                                    color: Colors.orange,
                                  ),
                                ),
                                title: const Text(
                                  "Change Password",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                                onTap: _changePassword,
                              ),
                              Divider(
                                height: 1,
                                color: Colors.grey.withOpacity(0.2),
                              ),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                  ),
                                ),
                                title: const Text(
                                  "Delete Account",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                                onTap: _deleteAccount,
                              ),
                            ],
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
