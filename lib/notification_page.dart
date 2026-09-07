import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    // --- GRAB THEME COLORS ---
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // We removed extendBodyBehindAppBar so the appbar sits cleanly on top
      appBar: AppBar(
        title: const Text(
          "Announcements",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 4,
        shadowColor: Colors.black45,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        // --- THIS ADDS THE DYNAMIC TEXTURE TO THE APPBAR ---
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
        // --- PREMIUM LIGHT GRADIENT BACKGROUND FOR THE BODY ---
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
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('notifications')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              final notifications = snapshot.data!;

              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 60,
                        color:
                            isDarkMode
                                ? Colors.grey.shade600
                                : primaryColor.withOpacity(0.3),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "No announcements yet",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color:
                              isDarkMode
                                  ? Colors.grey.shade400
                                  : primaryColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final note = notifications[index];
                  final title = note['title'] ?? "No Title";
                  final message = note['message'] ?? "";
                  final type = note['type'] ?? "News";

                  // --- FIX: CONVERT TO LOCAL DEVICE TIME ZONE ---
                  final createdAt =
                      DateTime.parse(note['created_at']).toLocal();
                  final formattedDate = DateFormat(
                    'MMM d, h:mm a',
                  ).format(createdAt);

                  // Badge Color Logic
                  Color badgeColor;
                  Color badgeTextColor;

                  if (type == 'Patch Note') {
                    badgeColor = Colors.orange.shade100;
                    badgeTextColor = Colors.orange.shade800;
                  } else if (type == 'Alert') {
                    badgeColor = Colors.red.shade100;
                    badgeTextColor = Colors.red.shade800;
                  } else {
                    // Default / News
                    badgeColor = Colors.green.shade100;
                    badgeTextColor = Colors.green.shade800;
                  }

                  if (isDarkMode) {
                    badgeColor = badgeColor.withOpacity(0.15);
                    badgeTextColor = badgeTextColor.withOpacity(0.9);
                  }

                  // --- PREMIUM CONTAINER (REPLACES CARD) ---
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[850] : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (!isDarkMode)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- TOP ROW: BADGE & DATE ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: badgeTextColor.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: badgeTextColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDarkMode
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // --- TITLE ---
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // --- MESSAGE BODY ---
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color:
                                  isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
