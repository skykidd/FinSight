import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final supabase = Supabase.instance.client;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _isLoading = true;

  // Stores data grouped by date
  Map<DateTime, List<Map<String, dynamic>>> _expensesByDate = {};
  Map<DateTime, List<Map<String, dynamic>>> _customEventsByDate = {};

  // --- EXPANDED MALAYSIAN FESTIVALS (2024 - 2026) ---
  final Map<DateTime, String> _festivals = {
    // 2024
    DateTime.utc(2024, 1, 1): "New Year's Day",
    DateTime.utc(2024, 2, 10): "Chinese New Year",
    DateTime.utc(2024, 2, 11): "Chinese New Year (Day 2)",
    DateTime.utc(2024, 4, 10): "Hari Raya Aidilfitri",
    DateTime.utc(2024, 4, 11): "Hari Raya Aidilfitri (Day 2)",
    DateTime.utc(2024, 5, 1): "Labour Day",
    DateTime.utc(2024, 5, 22): "Wesak Day",
    DateTime.utc(2024, 6, 3): "Agong's Birthday",
    DateTime.utc(2024, 6, 17): "Hari Raya Haji",
    DateTime.utc(2024, 7, 7): "Awal Muharram",
    DateTime.utc(2024, 8, 31): "Merdeka Day",
    DateTime.utc(2024, 9, 16): "Malaysia Day",
    DateTime.utc(2024, 10, 31): "Deepavali",
    DateTime.utc(2024, 12, 25): "Christmas",

    // 2025 (Estimates for lunar holidays)
    DateTime.utc(2025, 1, 1): "New Year's Day",
    DateTime.utc(2025, 1, 29): "Chinese New Year",
    DateTime.utc(2025, 1, 30): "Chinese New Year (Day 2)",
    DateTime.utc(2025, 3, 31): "Hari Raya Aidilfitri",
    DateTime.utc(2025, 4, 1): "Hari Raya Aidilfitri (Day 2)",
    DateTime.utc(2025, 5, 1): "Labour Day",
    DateTime.utc(2025, 5, 12): "Wesak Day",
    DateTime.utc(2025, 6, 2): "Agong's Birthday",
    DateTime.utc(2025, 6, 6): "Hari Raya Haji",
    DateTime.utc(2025, 6, 27): "Awal Muharram",
    DateTime.utc(2025, 8, 31): "Merdeka Day",
    DateTime.utc(2025, 9, 16): "Malaysia Day",
    DateTime.utc(2025, 10, 20): "Deepavali",
    DateTime.utc(2025, 12, 25): "Christmas",

    // 2026 (Estimates for lunar holidays)
    DateTime.utc(2026, 1, 1): "New Year's Day",
    DateTime.utc(2026, 2, 17): "Chinese New Year",
    DateTime.utc(2026, 2, 18): "Chinese New Year (Day 2)",
    DateTime.utc(2026, 3, 20): "Hari Raya Aidilfitri",
    DateTime.utc(2026, 3, 21): "Hari Raya Aidilfitri (Day 2)",
    DateTime.utc(2026, 5, 1): "Labour Day",
    DateTime.utc(2026, 5, 1): "Wesak Day", // Coincides with Labour Day
    DateTime.utc(2026, 5, 27): "Hari Raya Haji",
    DateTime.utc(2026, 6, 1): "Agong's Birthday",
    DateTime.utc(2026, 6, 16): "Awal Muharram",
    DateTime.utc(2026, 8, 31): "Merdeka Day",
    DateTime.utc(2026, 9, 16): "Malaysia Day",
    DateTime.utc(2026, 11, 8): "Deepavali",
    DateTime.utc(2026, 12, 25): "Christmas",
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchCalendarData();
  }

  // Normalizes a date to just Year-Month-Day
  DateTime _normalizeDate(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  Future<void> _fetchCalendarData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch Expenses
      final expenseData = await supabase
          .from('expenses')
          .select('amount, category, created_at, merchant');

      Map<DateTime, List<Map<String, dynamic>>> groupedExpenses = {};
      for (var row in expenseData) {
        DateTime rawDate = DateTime.parse(row['created_at']).toLocal();
        DateTime pureDate = _normalizeDate(rawDate);
        if (groupedExpenses[pureDate] == null) groupedExpenses[pureDate] = [];
        groupedExpenses[pureDate]!.add(row);
      }

      // 2. Fetch Custom Events
      final eventData = await supabase
          .from('calendar_events')
          .select()
          .eq('user_id', user.id);

      Map<DateTime, List<Map<String, dynamic>>> groupedEvents = {};
      for (var row in eventData) {
        DateTime rawDate = DateTime.parse(row['event_date']);
        DateTime pureDate = _normalizeDate(rawDate);
        if (groupedEvents[pureDate] == null) groupedEvents[pureDate] = [];
        groupedEvents[pureDate]!.add(row);
      }

      if (mounted) {
        setState(() {
          _expensesByDate = groupedExpenses;
          _customEventsByDate = groupedEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ADD CUSTOM EVENT ---
  Future<void> _addCustomEvent(String title) async {
    if (title.isEmpty || _selectedDay == null) return;

    try {
      await supabase.from('calendar_events').insert({
        'user_id': supabase.auth.currentUser!.id,
        'event_date': _normalizeDate(_selectedDay!).toIso8601String(),
        'title': title,
      });
      _fetchCalendarData(); // Refresh data
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error adding event: $e")));
    }
  }

  // --- DELETE CUSTOM EVENT ---
  Future<void> _deleteCustomEvent(int id) async {
    try {
      await supabase.from('calendar_events').delete().eq('id', id);
      _fetchCalendarData(); // Refresh data
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error deleting event: $e")));
    }
  }

  // Show dialog to add a new event
  void _showAddEventDialog(Color primaryColor) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              "Add Event for ${DateFormat('MMM d').format(_selectedDay!)}",
            ),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "E.g., Pay Rent, Car Service...",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _addCustomEvent(controller.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor, // --- THEMED BUTTON ---
                ),
                child: const Text(
                  "Save",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final normalized = _normalizeDate(day);
    List<dynamic> combined = [];
    if (_expensesByDate[normalized] != null) {
      combined.addAll(_expensesByDate[normalized]!);
    }
    if (_customEventsByDate[normalized] != null) {
      combined.addAll(_customEventsByDate[normalized]!);
    }
    return combined;
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('food') || name.contains('dining')) {
      return Icons.restaurant;
    }
    if (name.contains('transport') || name.contains('car')) {
      return Icons.directions_car;
    }
    if (name.contains('bill') || name.contains('utilit')) return Icons.receipt;
    if (name.contains('shop')) return Icons.shopping_bag;
    if (name.contains('health')) return Icons.medical_services;
    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.black : Colors.white;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.grey[50];

    // --- DYNAMIC THEME COLOR ---
    final primaryColor = Theme.of(context).colorScheme.primary;

    final normalizedSelectedDay = _normalizeDate(_selectedDay!);
    final selectedDayExpenses = _expensesByDate[normalizedSelectedDay] ?? [];
    final selectedDayEvents = _customEventsByDate[normalizedSelectedDay] ?? [];
    final currentFestival = _festivals[normalizedSelectedDay];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Spending Calendar",
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : Column(
                children: [
                  // --- CALENDAR WIDGET ---
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        if (!isDarkMode)
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                          ),
                      ],
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      selectedDayPredicate:
                          (day) => isSameDay(_selectedDay, day),
                      eventLoader: _getEventsForDay,
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onFormatChanged:
                          (format) => setState(() => _calendarFormat = format),
                      onPageChanged: (focusedDay) => _focusedDay = focusedDay,

                      // Custom Styling
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        markersMaxCount: 3,
                      ),

                      // Custom Builders for specific markers
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          final normalDate = _normalizeDate(date);
                          List<Widget> markers = [];

                          // 1. Expense Marker (Red Dot)
                          if (_expensesByDate[normalDate] != null &&
                              _expensesByDate[normalDate]!.isNotEmpty) {
                            markers.add(
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }

                          // 2. Custom Event Marker (Theme Color Dot)
                          if (_customEventsByDate[normalDate] != null &&
                              _customEventsByDate[normalDate]!.isNotEmpty) {
                            markers.add(
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: primaryColor, // --- THEMED MARKER ---
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }

                          // 3. Holiday Marker (Gold Star)
                          if (_festivals.containsKey(normalDate)) {
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  top: 1,
                                  right: 1,
                                  child: Icon(
                                    Icons.stars,
                                    size: 12,
                                    color: Colors.amber[700],
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: markers,
                                  ),
                                ),
                              ],
                            );
                          }

                          return Positioned(
                            bottom: 4,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: markers,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // --- DAY DETAILS SECTION ---
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[900] : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                        boxShadow: [
                          if (!isDarkMode)
                            const BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, -5),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag Handle
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Header Row with Date and Add Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat(
                                  'EEEE, MMMM d',
                                ).format(_selectedDay!),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add_circle,
                                  color:
                                      primaryColor, // --- THEMED ADD ICON ---
                                  size: 28,
                                ),
                                onPressed:
                                    () => _showAddEventDialog(primaryColor),
                                tooltip: "Add Custom Event",
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),

                          // --- THE NEW AGENDA / TIMELINE LIST ---
                          Expanded(
                            child:
                                (selectedDayExpenses.isEmpty &&
                                        selectedDayEvents.isEmpty &&
                                        currentFestival == null)
                                    ? _buildEmptyState(isDarkMode, primaryColor)
                                    : ListView(
                                      physics: const BouncingScrollPhysics(),
                                      children: [
                                        // 1. FESTIVALS & CUSTOM EVENTS SECTION (The Agenda)
                                        if (currentFestival != null ||
                                            selectedDayEvents.isNotEmpty) ...[
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              "Today's Agenda",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),

                                          // The Holiday Banner
                                          if (currentFestival != null)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withOpacity(
                                                  0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.amber
                                                      .withOpacity(0.3),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.celebration,
                                                    color: Colors.orange,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    currentFestival,
                                                    style: const TextStyle(
                                                      color: Colors.orange,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          // The User's Custom Events
                                          ...selectedDayEvents.map(
                                            (event) => Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    isDarkMode
                                                        ? Colors.grey[850]
                                                        : Colors.grey[50],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: primaryColor
                                                      .withOpacity(0.2),
                                                ), // --- THEMED BORDER ---
                                              ),
                                              child: ListTile(
                                                leading: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: primaryColor
                                                        .withOpacity(
                                                          0.1,
                                                        ), // --- THEMED BG ---
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.push_pin,
                                                    color: primaryColor,
                                                    size: 18,
                                                  ), // --- THEMED ICON ---
                                                ),
                                                title: Text(
                                                  event['title'],
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        isDarkMode
                                                            ? Colors.white
                                                            : Colors.black87,
                                                  ),
                                                ),
                                                trailing: IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.redAccent,
                                                    size: 20,
                                                  ),
                                                  onPressed:
                                                      () => _deleteCustomEvent(
                                                        event['id'],
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                        ],

                                        // 2. EXPENSES SECTION
                                        if (selectedDayExpenses.isNotEmpty) ...[
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8.0,
                                            ),
                                            child: Text(
                                              "Spending",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),

                                          // The Spending List
                                          Container(
                                            decoration: BoxDecoration(
                                              color:
                                                  isDarkMode
                                                      ? Colors.grey[850]
                                                      : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.grey.withOpacity(
                                                  0.2,
                                                ),
                                              ),
                                              boxShadow: [
                                                if (!isDarkMode)
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.02),
                                                    blurRadius: 5,
                                                    offset: const Offset(0, 2),
                                                  ),
                                              ],
                                            ),
                                            child: Column(
                                              children:
                                                  selectedDayExpenses.asMap().entries.map((
                                                    entry,
                                                  ) {
                                                    int idx = entry.key;
                                                    var exp = entry.value;
                                                    bool isLast =
                                                        idx ==
                                                        selectedDayExpenses
                                                                .length -
                                                            1;

                                                    return Column(
                                                      children: [
                                                        ListTile(
                                                          contentPadding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 16,
                                                                vertical: 4,
                                                              ),
                                                          leading: CircleAvatar(
                                                            backgroundColor:
                                                                Colors.redAccent
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                            child: Icon(
                                                              _getCategoryIcon(
                                                                exp['category'] ??
                                                                    '',
                                                              ),
                                                              color:
                                                                  Colors
                                                                      .redAccent,
                                                              size: 20,
                                                            ),
                                                          ),
                                                          title: Text(
                                                            exp['merchant'] ??
                                                                exp['category'] ??
                                                                'Expense',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  isDarkMode
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .black87,
                                                            ),
                                                          ),
                                                          subtitle: Text(
                                                            DateFormat(
                                                              'h:mm a',
                                                            ).format(
                                                              DateTime.parse(
                                                                exp['created_at'],
                                                              ).toLocal(),
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                          trailing: Text(
                                                            "- RM ${(exp['amount'] ?? 0).toStringAsFixed(2)}",
                                                            style: const TextStyle(
                                                              color:
                                                                  Colors
                                                                      .redAccent,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ),
                                                        if (!isLast)
                                                          Divider(
                                                            height: 1,
                                                            indent: 60,
                                                            color: Colors.grey
                                                                .withOpacity(
                                                                  0.2,
                                                                ),
                                                          ),
                                                      ],
                                                    );
                                                  }).toList(),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(
                                          height: 30,
                                        ), // Bottom padding
                                      ],
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  // --- BETTER EMPTY STATE WIDGET ---
  Widget _buildEmptyState(bool isDarkMode, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available,
              size: 50,
              color: primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "Nothing scheduled.",
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Tap the + button to add a personal note\nor task for this day.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
