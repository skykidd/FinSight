import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminUserDetailsPage extends StatelessWidget {
  final Map<String, dynamic> user;

  const AdminUserDetailsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final String username = user['username'] ?? "Unknown";
    final String email = user['email'] ?? "No Email";
    final String fullName = user['full_name'] ?? "Not set";
    final String role = user['role'] ?? "user";
    final String? avatarUrl = user['avatar_url'];

    // Format Date (e.g., "Dec 25, 2024")
    String joinedDate = "Unknown";
    if (user['created_at'] != null) {
      joinedDate = DateFormat(
        'MMM d, yyyy',
      ).format(DateTime.parse(user['created_at']));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER BACKGROUND ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // BIG AVATAR
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child:
                          avatarUrl == null
                              ? Text(
                                username[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: Colors.deepPurple,
                                ),
                              )
                              : null,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // USERNAME & ROLE TAG
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          role == 'admin' ? Colors.redAccent : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- DETAILS LIST ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    _buildDetailTile(Icons.email, "Email Address", email),
                    const Divider(height: 1),
                    _buildDetailTile(Icons.badge, "Full Name", fullName),
                    const Divider(height: 1),
                    _buildDetailTile(
                      Icons.calendar_today,
                      "Member Since",
                      joinedDate,
                    ),
                    const Divider(height: 1),
                    _buildDetailTile(Icons.shield, "System Role", role),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }
}
