import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calendar_page.dart';

class ChartsPage extends StatefulWidget {
  // --- INJECTED FROM HOMEPAGE ---
  final bool showTutorial;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;

  const ChartsPage({
    super.key,
    this.showTutorial = false,
    this.onTutorialNext,
    this.onTutorialSkip,
  });

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  // --- SCROLL CONTROLLERS ---
  final ScrollController _scrollController = ScrollController();
  final ScrollController _monthScrollController = ScrollController();

  // --- TUTORIAL KEYS ---
  final GlobalKey _barChartKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey();

  final int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  bool _isYearlyView = false;

  final List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  // --- FESTIVALS LIST ---
  final Map<DateTime, String> _festivals = {
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

    DateTime.utc(2026, 1, 1): "New Year's Day",
    DateTime.utc(2026, 2, 17): "Chinese New Year",
    DateTime.utc(2026, 2, 18): "Chinese New Year (Day 2)",
    DateTime.utc(2026, 3, 20): "Hari Raya Aidilfitri",
    DateTime.utc(2026, 3, 21): "Hari Raya Aidilfitri (Day 2)",
    DateTime.utc(2026, 5, 1): "Labour Day",
    DateTime.utc(2026, 5, 1): "Wesak Day",
    DateTime.utc(2026, 5, 27): "Hari Raya Haji",
    DateTime.utc(2026, 6, 1): "Agong's Birthday",
    DateTime.utc(2026, 6, 16): "Awal Muharram",
    DateTime.utc(2026, 8, 31): "Merdeka Day",
    DateTime.utc(2026, 9, 16): "Malaysia Day",
    DateTime.utc(2026, 11, 8): "Deepavali",
    DateTime.utc(2026, 12, 25): "Christmas",
  };

  // --- RAW DATA ---
  List<Map<String, dynamic>> _allIncome = [];
  List<Map<String, dynamic>> _allExpenses = [];
  List<Map<String, dynamic>> _allCustomEvents = [];
  Map<int, String> _incomeCategoryMap = {};

  // --- NEW: GOALS & COMMITMENTS DATA ---
  List<Map<String, dynamic>> _allCommitments = [];
  List<Map<String, dynamic>> _allGoals = [];

  // --- MONTHLY AGGREGATES ---
  double _currentMonthIncome = 0;
  double _currentMonthExpenses = 0;
  List<MapEntry<String, double>> _sortedIncomeCategories = [];
  List<MapEntry<String, double>> _sortedExpenseCategories = [];

  // --- DETAILED TRANSACTION LISTS FOR BOTTOM SHEET ---
  List<Map<String, dynamic>> _currentMonthIncomeList = [];
  List<Map<String, dynamic>> _currentMonthExpenseList = [];
  List<Map<String, dynamic>> _monthTimeline = [];

  // --- CHART DATA ---
  List<BarChartGroupData> _yearlyBarGroups = [];
  double _maxBarY = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();

    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerTutorial();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _monthScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ChartsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showTutorial && !oldWidget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerTutorial();
      });
    }
  }

  void _triggerTutorial() {
    Future.delayed(const Duration(milliseconds: 400), () async {
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final user = supabase.auth.currentUser;
        if (user != null) {
          // Tutorial stops at Calendar key, perfectly avoiding the pie chart!
          ShowCaseWidget.of(
            context,
          ).startShowCase([_barChartKey, _calendarKey]);
          await prefs.setBool('has_seen_charts_tutorial_${user.id}', true);
        }
      }
    });
  }

  void _scrollToSelectedMonth() {
    if (!_monthScrollController.hasClients) return;
    const double itemWidth = 85.0;
    const double margin = 10.0;
    const double totalItemWidth = itemWidth + margin;
    final double listViewWidth = MediaQuery.of(context).size.width - 40;
    final double targetCenter =
        ((_selectedMonth - 1) * totalItemWidth) + (itemWidth / 2);
    double offset = targetCenter - (listViewWidth / 2);
    if (offset < 0) offset = 0;
    if (offset > _monthScrollController.position.maxScrollExtent) {
      offset = _monthScrollController.position.maxScrollExtent;
    }
    _monthScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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
                  widget.onTutorialSkip?.call();
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
                    widget.onTutorialNext?.call();
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

  Future<void> _fetchData({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted && !isRefresh) setState(() => _isLoading = false);
        return;
      }

      int startYear = _isYearlyView ? (_selectedYear - 4) : _selectedYear;

      final localStart = DateTime(startYear, 1, 1);
      final localEnd = DateTime(_selectedYear, 12, 31, 23, 59, 59);

      final startQueryDate = localStart.toUtc().toIso8601String();
      final endQueryDate = localEnd.toUtc().toIso8601String();

      // Fetch Income Categories
      final incCatsData = await supabase
          .from('income_categories')
          .select('id, name');
      Map<int, String> tempIncMap = {};
      for (var cat in incCatsData) {
        tempIncMap[cat['id'] as int] = cat['name'].toString();
      }
      _incomeCategoryMap = tempIncMap;

      // Fetch Income
      final incomeData = await supabase
          .from('income')
          .select('amount, created_at, source, category_id')
          .gte('created_at', startQueryDate)
          .lte('created_at', endQueryDate);

      // Fetch Expenses
      final expenseData = await supabase
          .from('expenses')
          .select('amount, category, created_at, merchant')
          .gte('created_at', startQueryDate)
          .lte('created_at', endQueryDate);

      // Fetch Custom Calendar Events
      final eventData = await supabase
          .from('calendar_events')
          .select('event_date, title')
          .gte('event_date', startQueryDate)
          .lte('event_date', endQueryDate)
          .eq('user_id', user.id);

      // --- NEW: FETCH COMMITMENTS AND GOALS ---
      final commitmentsData = await supabase
          .from('commitments')
          .select('name, total_amount, paid_amount, monthly_payment');

      final goalsData = await supabase
          .from('goals')
          .select('name, target_amount, saved_amount');

      _allIncome = List<Map<String, dynamic>>.from(incomeData);
      _allExpenses = List<Map<String, dynamic>>.from(expenseData);
      _allCustomEvents = List<Map<String, dynamic>>.from(eventData);
      _allCommitments = List<Map<String, dynamic>>.from(commitmentsData);
      _allGoals = List<Map<String, dynamic>>.from(goalsData);

      // Process Data for the Bar Chart
      double highestBar = 0;
      List<BarChartGroupData> barGroups = [];

      if (_isYearlyView) {
        List<double> incByYear = List.filled(5, 0.0);
        List<double> expByYear = List.filled(5, 0.0);
        for (var row in _allIncome) {
          DateTime d = DateTime.parse(row['created_at']).toLocal();
          int idx = d.year - startYear;
          if (idx >= 0 && idx < 5) {
            incByYear[idx] += (row['amount'] ?? 0).toDouble();
          }
        }
        for (var row in _allExpenses) {
          DateTime d = DateTime.parse(row['created_at']).toLocal();
          int idx = d.year - startYear;
          if (idx >= 0 && idx < 5) {
            expByYear[idx] += (row['amount'] ?? 0).toDouble();
          }
        }
        for (int i = 0; i < 5; i++) {
          if (incByYear[i] > highestBar) highestBar = incByYear[i];
          if (expByYear[i] > highestBar) highestBar = expByYear[i];
          barGroups.add(_makeBarGroup(i, incByYear[i], expByYear[i]));
        }
      } else {
        List<double> incByMonth = List.filled(12, 0.0);
        List<double> expByMonth = List.filled(12, 0.0);
        for (var row in _allIncome) {
          DateTime d = DateTime.parse(row['created_at']).toLocal();
          if (d.year == _selectedYear) {
            incByMonth[d.month - 1] += (row['amount'] ?? 0).toDouble();
          }
        }
        for (var row in _allExpenses) {
          DateTime d = DateTime.parse(row['created_at']).toLocal();
          if (d.year == _selectedYear) {
            expByMonth[d.month - 1] += (row['amount'] ?? 0).toDouble();
          }
        }
        for (int i = 0; i < 12; i++) {
          if (incByMonth[i] > highestBar) highestBar = incByMonth[i];
          if (expByMonth[i] > highestBar) highestBar = expByMonth[i];
          barGroups.add(_makeBarGroup(i, incByMonth[i], expByMonth[i]));
        }
      }

      if (mounted) {
        setState(() {
          _yearlyBarGroups = barGroups;
          _maxBarY = highestBar == 0 ? 100 : highestBar * 1.2;
        });
      }

      _processMonthData(_selectedMonth);
    } catch (e) {
      debugPrint(e.toString());
      if (mounted && !isRefresh) setState(() => _isLoading = false);
    }
  }

  BarChartGroupData _makeBarGroup(int x, double y1, double y2) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y1,
          color: Colors.blueAccent,
          width: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
        BarChartRodData(
          toY: y2,
          color: Colors.redAccent,
          width: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
      ],
    );
  }

  void _processMonthData(int targetMonth) {
    double incomeSum = 0;
    double expenseSum = 0;

    Map<String, double> incCategoryTotals = {};
    Map<String, double> expCategoryTotals = {};

    List<Map<String, dynamic>> tempIncList = [];
    List<Map<String, dynamic>> tempExpList = [];
    List<Map<String, dynamic>> combinedTimeline = [];

    _festivals.forEach((date, name) {
      if (date.year == _selectedYear && date.month == targetMonth) {
        combinedTimeline.add({'type': 'festival', 'title': name, 'date': date});
      }
    });

    for (var event in _allCustomEvents) {
      DateTime date = DateTime.parse(event['event_date']).toLocal();
      if (date.month == targetMonth && date.year == _selectedYear) {
        combinedTimeline.add({
          'type': 'event',
          'title': event['title'],
          'date': date,
        });
      }
    }
    combinedTimeline.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );

    // Process Income
    for (var row in _allIncome) {
      DateTime date = DateTime.parse(row['created_at']).toLocal();
      if (date.year == _selectedYear && date.month == targetMonth) {
        double amt = (row['amount'] ?? 0).toDouble();
        incomeSum += amt;

        String catName = 'General';
        if (row['category_id'] != null) {
          catName = _incomeCategoryMap[row['category_id']] ?? 'General';
        }

        incCategoryTotals[catName] = (incCategoryTotals[catName] ?? 0) + amt;
        tempIncList.add({
          'amount': amt,
          'title': row['source'] ?? 'Income',
          'date': date,
          'category': catName,
        });
      }
    }

    // Process Expenses
    for (var row in _allExpenses) {
      DateTime date = DateTime.parse(row['created_at']).toLocal();
      if (date.year == _selectedYear && date.month == targetMonth) {
        double amt = (row['amount'] ?? 0).toDouble();
        expenseSum += amt;

        String catName = row['category'] ?? 'General';
        expCategoryTotals[catName] = (expCategoryTotals[catName] ?? 0) + amt;
        tempExpList.add({
          'amount': amt,
          'title': row['merchant'] ?? 'Expense',
          'date': date,
          'category': catName,
        });
      }
    }

    var sortedIncEntries = incCategoryTotals.entries.toList();
    sortedIncEntries.sort((a, b) => b.value.compareTo(a.value));

    var sortedExpEntries = expCategoryTotals.entries.toList();
    sortedExpEntries.sort((a, b) => b.value.compareTo(a.value));

    tempIncList.sort((a, b) => b['date'].compareTo(a['date']));
    tempExpList.sort((a, b) => b['date'].compareTo(a['date']));

    setState(() {
      _currentMonthIncome = incomeSum;
      _currentMonthExpenses = expenseSum;
      _sortedIncomeCategories = sortedIncEntries;
      _sortedExpenseCategories = sortedExpEntries;
      _currentMonthIncomeList = tempIncList;
      _currentMonthExpenseList = tempExpList;
      _monthTimeline = combinedTimeline;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedMonth();
    });
  }

  void _showCategoryDetailsSheet(
    String categoryName,
    bool isIncome,
    Color primaryColor,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    List<Map<String, dynamic>> items =
        isIncome
            ? _currentMonthIncomeList
                .where((item) => item['category'] == categoryName)
                .toList()
            : _currentMonthExpenseList
                .where((item) => item['category'] == categoryName)
                .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isIncome ? Colors.green : Colors.redAccent)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(categoryName),
                      color: isIncome ? Colors.green : Colors.redAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          isIncome
                              ? "Income Transactions"
                              : "Expense Transactions",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: Colors.grey.withOpacity(0.2)),
              const SizedBox(height: 10),

              Expanded(
                child:
                    items.isEmpty
                        ? const Center(
                          child: Text(
                            "No data found.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                        : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final dateStr = DateFormat(
                              'dd MMM yyyy • h:mm a',
                            ).format(item['date']);

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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color:
                                                isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dateStr,
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "${isIncome ? '+' : '-'}RM ${(item['amount'] as double).toStringAsFixed(2)}",
                                    style: TextStyle(
                                      color:
                                          isIncome
                                              ? Colors.green
                                              : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
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

  void _showMonthDiscoverySheet(int targetMonth, Color primaryColor) {
    double incomeSum = 0;
    double expenseSum = 0;
    Map<String, double> catTotals = {};

    List<Map<String, dynamic>> popUpTimeline = [];

    _festivals.forEach((date, name) {
      if (date.year == _selectedYear && date.month == targetMonth) {
        popUpTimeline.add({'type': 'festival', 'title': name, 'date': date});
      }
    });

    for (var event in _allCustomEvents) {
      DateTime d = DateTime.parse(event['event_date']).toLocal();
      if (d.year == _selectedYear && d.month == targetMonth) {
        popUpTimeline.add({
          'type': 'event',
          'title': event['title'],
          'date': d,
        });
      }
    }

    popUpTimeline.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );

    for (var row in _allIncome) {
      DateTime d = DateTime.parse(row['created_at']).toLocal();
      if (d.year == _selectedYear && d.month == targetMonth) {
        incomeSum += (row['amount'] ?? 0).toDouble();
      }
    }

    for (var row in _allExpenses) {
      DateTime d = DateTime.parse(row['created_at']).toLocal();
      if (d.year == _selectedYear && d.month == targetMonth) {
        double amt = (row['amount'] ?? 0).toDouble();
        expenseSum += amt;
        String cat = row['category'] ?? 'General';
        catTotals[cat] = (catTotals[cat] ?? 0) + amt;
      }
    }

    var sortedCats =
        catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    _buildDiscoveryBottomSheet(
      title: "${_monthNames[targetMonth - 1]} $_selectedYear Discovery",
      incomeSum: incomeSum,
      expenseSum: expenseSum,
      timeline: popUpTimeline,
      sortedCats: sortedCats,
      isDarkMode: isDarkMode,
      primaryColor: primaryColor,
    );
  }

  void _showYearDiscoverySheet(int targetYear, Color primaryColor) {
    double incomeSum = 0;
    double expenseSum = 0;
    Map<String, double> catTotals = {};

    List<Map<String, dynamic>> popUpTimeline = [];

    _festivals.forEach((date, name) {
      if (date.year == targetYear) {
        popUpTimeline.add({'type': 'festival', 'title': name, 'date': date});
      }
    });

    for (var event in _allCustomEvents) {
      DateTime d = DateTime.parse(event['event_date']).toLocal();
      if (d.year == targetYear) {
        popUpTimeline.add({
          'type': 'event',
          'title': event['title'],
          'date': d,
        });
      }
    }

    popUpTimeline.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );

    for (var row in _allIncome) {
      DateTime d = DateTime.parse(row['created_at']).toLocal();
      if (d.year == targetYear) incomeSum += (row['amount'] ?? 0).toDouble();
    }

    for (var row in _allExpenses) {
      DateTime d = DateTime.parse(row['created_at']).toLocal();
      if (d.year == targetYear) {
        double amt = (row['amount'] ?? 0).toDouble();
        expenseSum += amt;
        String cat = row['category'] ?? 'General';
        catTotals[cat] = (catTotals[cat] ?? 0) + amt;
      }
    }

    var sortedCats =
        catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    _buildDiscoveryBottomSheet(
      title: "$targetYear Annual Discovery",
      incomeSum: incomeSum,
      expenseSum: expenseSum,
      timeline: popUpTimeline,
      sortedCats: sortedCats,
      isDarkMode: isDarkMode,
      primaryColor: primaryColor,
    );
  }

  void _buildDiscoveryBottomSheet({
    required String title,
    required double incomeSum,
    required double expenseSum,
    required List<Map<String, dynamic>> timeline,
    required List<MapEntry<String, double>> sortedCats,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : null,
            gradient:
                isDarkMode
                    ? null
                    : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(Colors.white, primaryColor, 0.05)!,
                        Color.lerp(Colors.white, primaryColor, 0.15)!,
                        Color.lerp(Colors.white, primaryColor, 0.05)!,
                      ],
                    ),
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

              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : primaryColor,
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Income",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "+RM ${incomeSum.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "Expenses",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "-RM ${expenseSum.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.grey.withOpacity(0.2)),
              const SizedBox(height: 10),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Top Spending Categories",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (sortedCats.isEmpty)
                        const Text(
                          "No expenses recorded.",
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        ...sortedCats
                            .take(3)
                            .map(
                              (cat) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _getCategoryIcon(cat.key),
                                          size: 18,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          cat.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "RM ${cat.value.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                      const SizedBox(height: 20),
                      Divider(color: Colors.grey.withOpacity(0.2)),
                      const SizedBox(height: 10),

                      const Text(
                        "Events & Festivals",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (timeline.isEmpty)
                        const Text(
                          "No special events this period.",
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        ...timeline.map((item) {
                          bool isFestival = item['type'] == 'festival';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "• ",
                                  style: TextStyle(
                                    color:
                                        isFestival
                                            ? Colors.amber
                                            : primaryColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    "${item['title']} (${DateFormat('MMM d').format(item['date'])})",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          isDarkMode
                                              ? Colors.white70
                                              : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('food') ||
        name.contains('dining') ||
        name.contains('restaurant')) {
      return Icons.restaurant;
    }
    if (name.contains('transport') ||
        name.contains('petrol') ||
        name.contains('car')) {
      return Icons.directions_car;
    }
    if (name.contains('bill') ||
        name.contains('utilit') ||
        name.contains('internet')) {
      return Icons.receipt;
    }
    if (name.contains('shop') ||
        name.contains('cloth') ||
        name.contains('retail')) {
      return Icons.shopping_bag;
    }
    if (name.contains('health') ||
        name.contains('medical') ||
        name.contains('clinic')) {
      return Icons.medical_services;
    }
    if (name.contains('educat') ||
        name.contains('book') ||
        name.contains('school')) {
      return Icons.school;
    }
    if (name.contains('entertain') ||
        name.contains('movie') ||
        name.contains('game')) {
      return Icons.sports_esports;
    }
    if (name.contains('grocer') || name.contains('market')) {
      return Icons.shopping_cart;
    }
    if (name.contains('salary') ||
        name.contains('payroll') ||
        name.contains('dividend') ||
        name.contains('invest')) {
      return Icons.account_balance_wallet;
    }
    return Icons.category;
  }

  Widget _buildUnifiedHeaderControls(Color primaryColor, bool isDarkMode) {
    return Showcase.withWidget(
      key: _calendarKey,
      width: 280,
      height: 160,
      container: _buildCustomTooltip(
        context: context,
        title: 'Time Views',
        description:
            'Switch between Months, Years, or tap the Calendar icon to see your spending broken down day by day.',
        isLastStep: true,
        primaryColor: primaryColor,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CalendarPage()),
                );
                _fetchData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_month,
                  color: primaryColor,
                  size: 18,
                ),
              ),
            ),

            Container(
              width: 1,
              height: 20,
              color: Colors.grey.withOpacity(0.5),
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),

            GestureDetector(
              onTap: () {
                if (_isYearlyView) {
                  setState(() {
                    _isYearlyView = false;
                    _isLoading = true;
                  });
                  _fetchData();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: !_isYearlyView ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow:
                      !_isYearlyView && !isDarkMode
                          ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ]
                          : [],
                ),
                child: Text(
                  "Months",
                  style: TextStyle(
                    color: !_isYearlyView ? primaryColor : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            GestureDetector(
              onTap: () {
                if (!_isYearlyView) {
                  setState(() {
                    _isYearlyView = true;
                    _isLoading = true;
                  });
                  _fetchData();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isYearlyView ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow:
                      _isYearlyView && !isDarkMode
                          ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ]
                          : [],
                ),
                child: Text(
                  "Years",
                  style: TextStyle(
                    color: _isYearlyView ? primaryColor : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final titleColor = isDarkMode ? Colors.white : primaryColor;

    final total = _currentMonthIncome + _currentMonthExpenses;
    double incomePercent = total > 0 ? (_currentMonthIncome / total) * 100 : 0;
    double expensePercent =
        total > 0 ? (_currentMonthExpenses / total) * 100 : 0;

    // --- CALCULATE COMMITMENT & GOAL TOTALS ---
    double totalMonthlyCommitments = 0;
    for (var debt in _allCommitments) {
      totalMonthlyCommitments +=
          (debt['monthly_payment'] as num?)?.toDouble() ?? 0.0;
    }
    double totalSaved = 0;
    for (var goal in _allGoals) {
      totalSaved += (goal['saved_amount'] as num?)?.toDouble() ?? 0.0;
    }

    final List<Color> pieColors = [
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.amber,
      Colors.deepOrange,
      Colors.pinkAccent,
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : RefreshIndicator(
                color: primaryColor,
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 600));
                  await _fetchData(isRefresh: true);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    top: 60,
                    left: 20,
                    right: 20,
                    bottom: 180,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Showcase.withWidget(
                            key: _barChartKey,
                            width: 280,
                            height: 160,
                            container: _buildCustomTooltip(
                              context: context,
                              title: 'Cashflow Analytics',
                              description:
                                  'Your spending habits and cashflow over time are visualized here.',
                              isLastStep: false,
                              primaryColor: primaryColor,
                            ),
                            child: Text(
                              "Cashflow",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                            ),
                          ),
                          _buildUnifiedHeaderControls(primaryColor, isDarkMode),
                        ],
                      ),
                      const SizedBox(height: 15),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Wrap(
                            spacing: 12,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Income",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Expenses",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Container(
                        height: 250,
                        padding: const EdgeInsets.only(top: 20, right: 10),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[850] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade200,
                            width: 1.5,
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
                        child:
                            _yearlyBarGroups.isEmpty
                                ? Center(
                                  child: Text(
                                    "No data for $_selectedYear.",
                                    style: TextStyle(
                                      color: titleColor.withOpacity(0.5),
                                    ),
                                  ),
                                )
                                : BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: _maxBarY,
                                    gridData: const FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                    barTouchData: BarTouchData(
                                      enabled: true,
                                      touchCallback: (
                                        FlTouchEvent event,
                                        barTouchResponse,
                                      ) {
                                        if (event is FlTapUpEvent &&
                                            barTouchResponse?.spot != null) {
                                          int tappedIndex =
                                              barTouchResponse!
                                                  .spot!
                                                  .touchedBarGroupIndex;
                                          if (_isYearlyView) {
                                            int tappedYear =
                                                (_selectedYear - 4) +
                                                tappedIndex;
                                            _showYearDiscoverySheet(
                                              tappedYear,
                                              primaryColor,
                                            );
                                          } else {
                                            _showMonthDiscoverySheet(
                                              tappedIndex + 1,
                                              primaryColor,
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 28,
                                          getTitlesWidget: (value, meta) {
                                            String label = "";
                                            if (!_isYearlyView) {
                                              label =
                                                  _monthNames[value.toInt()];
                                            } else {
                                              int yearStr =
                                                  (_selectedYear - 4) +
                                                  value.toInt();
                                              label = yearStr.toString();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8.0,
                                              ),
                                              child: Text(
                                                label,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) {
                                            if (value == 0) {
                                              return const SizedBox();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                right: 8.0,
                                              ),
                                              child: Text(
                                                NumberFormat.compact().format(
                                                  value,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    barGroups: _yearlyBarGroups,
                                  ),
                                ),
                      ),

                      const SizedBox(height: 40),
                      Divider(
                        thickness: 1,
                        color: Colors.grey.withOpacity(0.2),
                      ),
                      const SizedBox(height: 20),

                      // --- NEW: COMMITMENTS BREAKDOWN ---
                      Text(
                        "Commitment Spread",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 15),
                      if (_allCommitments.isEmpty ||
                          totalMonthlyCommitments == 0)
                        Center(
                          child: Text(
                            "No active monthly commitments.",
                            style: TextStyle(
                              color: titleColor.withOpacity(0.5),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 220,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[850] : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  isDarkMode
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade200,
                              width: 1.5,
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
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 35,
                                    sections: List.generate(
                                      _allCommitments.length,
                                      (index) {
                                        final debt = _allCommitments[index];
                                        final monthly =
                                            (debt['monthly_payment'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                        final pct =
                                            (monthly /
                                                totalMonthlyCommitments) *
                                            100;
                                        return PieChartSectionData(
                                          value: monthly,
                                          title: '${pct.toStringAsFixed(0)}%',
                                          color:
                                              pieColors[index %
                                                  pieColors.length],
                                          radius: 40,
                                          titleStyle: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 1,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _allCommitments.length,
                                  itemBuilder: (context, index) {
                                    final debt = _allCommitments[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color:
                                                  pieColors[index %
                                                      pieColors.length],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              debt['name'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black87,
                                              ),
                                              overflow: TextOverflow.ellipsis,
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
                        ),

                      const SizedBox(height: 20),

                      // --- NEW: TOTAL SAVINGS SUMMARY CARD ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade700,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            if (!isDarkMode)
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.savings,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Total Locked Savings",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              NumberFormat.currency(
                                locale: 'en_MY',
                                symbol: 'RM ',
                              ).format(totalSaved),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "Across ${_allGoals.length} Active Goals",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                      Divider(
                        thickness: 1,
                        color: Colors.grey.withOpacity(0.2),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        "Monthly Breakdown",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 15),

                      SizedBox(
                        height: 45,
                        child: ListView.builder(
                          controller: _monthScrollController,
                          scrollDirection: Axis.horizontal,
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            int monthNum = index + 1;
                            bool isSelected = _selectedMonth == monthNum;

                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedMonth = monthNum);
                                _processMonthData(monthNum);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 85,
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? primaryColor
                                          : (isDarkMode
                                              ? Colors.grey[800]
                                              : Colors.white),
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    if (!isDarkMode)
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _monthNames[index],
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : (isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black87),
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- MONTHLY SUMMARY (PIE CHART) RESTORED ---
                      Text(
                        "${_monthNames[_selectedMonth - 1]} $_selectedYear Summary",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 15),

                      SizedBox(
                        height: 200,
                        child:
                            total == 0
                                ? Center(
                                  child: Text(
                                    "No data for ${_monthNames[_selectedMonth - 1]} $_selectedYear.",
                                    style: TextStyle(
                                      color: titleColor.withOpacity(0.5),
                                    ),
                                  ),
                                )
                                : PieChart(
                                  PieChartData(
                                    sectionsSpace: 5,
                                    centerSpaceRadius: 50,
                                    sections: [
                                      PieChartSectionData(
                                        value: _currentMonthIncome,
                                        title:
                                            '${incomePercent.toStringAsFixed(1)}%',
                                        color: Colors.green,
                                        radius: 45,
                                        titleStyle: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      PieChartSectionData(
                                        value: _currentMonthExpenses,
                                        title:
                                            '${expensePercent.toStringAsFixed(1)}%',
                                        color: Colors.red,
                                        radius: 45,
                                        titleStyle: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                      const SizedBox(height: 30),

                      _buildSummaryCard(
                        "Total Income",
                        _currentMonthIncome,
                        Colors.green,
                        isDarkMode,
                      ),
                      const SizedBox(height: 15),
                      _buildSummaryCard(
                        "Total Expenses",
                        _currentMonthExpenses,
                        Colors.redAccent,
                        isDarkMode,
                      ),
                      const SizedBox(height: 15),
                      _buildSummaryCard(
                        "Net Balance",
                        _currentMonthIncome - _currentMonthExpenses,
                        primaryColor,
                        isDarkMode,
                      ),

                      const SizedBox(height: 40),
                      Divider(
                        thickness: 1,
                        color: Colors.grey.withOpacity(0.2),
                      ),
                      const SizedBox(height: 20),

                      // --- 1. INCOME BREAKDOWN ---
                      Text(
                        "Income Breakdown",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_sortedIncomeCategories.isEmpty)
                        Center(
                          child: Text(
                            "No income for ${_monthNames[_selectedMonth - 1]} $_selectedYear.",
                            style: TextStyle(
                              color: titleColor.withOpacity(0.5),
                            ),
                          ),
                        )
                      else
                        ..._sortedIncomeCategories.map(
                          (entry) => _buildCategoryRow(
                            name: entry.key,
                            amount: entry.value,
                            total: _currentMonthIncome,
                            isDark: isDarkMode,
                            primaryColor: primaryColor,
                            isIncome: true,
                          ),
                        ),

                      const SizedBox(height: 40),
                      Divider(
                        thickness: 1,
                        color: Colors.grey.withOpacity(0.2),
                      ),
                      const SizedBox(height: 20),

                      // --- 2. EXPENSE BREAKDOWN ---
                      Text(
                        "Expenses Breakdown",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_sortedExpenseCategories.isEmpty)
                        Center(
                          child: Text(
                            "No expenses for ${_monthNames[_selectedMonth - 1]} $_selectedYear.",
                            style: TextStyle(
                              color: titleColor.withOpacity(0.5),
                            ),
                          ),
                        )
                      else
                        ..._sortedExpenseCategories.map(
                          (entry) => _buildCategoryRow(
                            name: entry.key,
                            amount: entry.value,
                            total: _currentMonthExpenses,
                            isDark: isDarkMode,
                            primaryColor: primaryColor,
                            isIncome: false,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(Icons.show_chart, color: color),
              ),
              const SizedBox(width: 15),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          Text(
            NumberFormat.currency(
              locale: 'en_MY',
              symbol: 'RM ',
            ).format(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow({
    required String name,
    required double amount,
    required double total,
    required bool isDark,
    required Color primaryColor,
    required bool isIncome,
  }) {
    double percent = total > 0 ? (amount / total) : 0;
    IconData catIcon = _getCategoryIcon(name);
    Color dynamicColor = isIncome ? Colors.green : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: InkWell(
        onTap: () => _showCategoryDetailsSheet(name, isIncome, primaryColor),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: dynamicColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(catIcon, color: dynamicColor, size: 22),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    "${isIncome ? '+' : '-'}RM ${amount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: dynamicColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: percent,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      color: dynamicColor,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 45,
                    child: Text(
                      "${(percent * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
