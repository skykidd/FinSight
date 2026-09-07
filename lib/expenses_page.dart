import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:showcaseview/showcaseview.dart';

class ExpensesPage extends StatefulWidget {
  // --- INJECTED FROM HOMEPAGE ---
  final bool showTutorial;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;

  const ExpensesPage({
    super.key,
    this.showTutorial = false,
    this.onTutorialNext,
    this.onTutorialSkip,
  });

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final supabase = Supabase.instance.client;

  // --- TUTORIAL KEYS ---
  final GlobalKey _toggleKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  // --- Toggle for Monthly vs Yearly View ---
  bool _isYearlyView = false;

  @override
  void initState() {
    super.initState();
    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerTutorial();
      });
    }
  }

  @override
  void didUpdateWidget(ExpensesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showTutorial && !oldWidget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerTutorial();
      });
    }
  }

  void _triggerTutorial() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        ShowCaseWidget.of(context).startShowCase([_toggleKey, _fabKey]);
      }
    });
  }

  // --- CUSTOM TUTORIAL POP-UP BUILDER ---
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

  // --- DELETE FUNCTION ---
  Future<void> _deleteExpense(int id) async {
    try {
      await supabase.from('expenses').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Expense deleted successfully"),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- ADD EXPENSE BOTTOM SHEET ---
  void _showAddExpenseSheet(Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddExpenseForm(themeColor: primaryColor),
    );
  }

  // --- Helper to generate THREE lines of chart data ---
  Map<String, List<FlSpot>> _generateChartData(
    List<Map<String, dynamic>> incomes,
    List<Map<String, dynamic>> expenses,
  ) {
    Map<int, double> incomeData = {};
    Map<int, double> expenseData = {};
    final now = DateTime.now();

    for (var item in incomes) {
      final date = DateTime.parse(item['created_at']).toLocal();
      final amount = (item['amount'] ?? 0.0).toDouble();

      if (_isYearlyView) {
        if (date.year == now.year) {
          incomeData[date.month] = (incomeData[date.month] ?? 0) + amount;
        }
      } else {
        if (date.year == now.year && date.month == now.month) {
          incomeData[date.day] = (incomeData[date.day] ?? 0) + amount;
        }
      }
    }

    for (var item in expenses) {
      final date = DateTime.parse(item['created_at']).toLocal();
      final amount = (item['amount'] ?? 0.0).toDouble();

      if (_isYearlyView) {
        if (date.year == now.year) {
          expenseData[date.month] = (expenseData[date.month] ?? 0) + amount;
        }
      } else {
        if (date.year == now.year && date.month == now.month) {
          expenseData[date.day] = (expenseData[date.day] ?? 0) + amount;
        }
      }
    }

    List<FlSpot> incomeSpots = [];
    List<FlSpot> expenseSpots = [];
    List<FlSpot> balanceSpots = [];
    int maxLimit =
        _isYearlyView ? 12 : DateTime(now.year, now.month + 1, 0).day;

    for (int i = 1; i <= maxLimit; i++) {
      double inc = incomeData[i] ?? 0.0;
      double exp = expenseData[i] ?? 0.0;
      incomeSpots.add(FlSpot(i.toDouble(), inc));
      expenseSpots.add(FlSpot(i.toDouble(), exp));
      balanceSpots.add(FlSpot(i.toDouble(), inc - exp));
    }

    return {
      'income': incomeSpots,
      'expenses': expenseSpots,
      'balance': balanceSpots,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // --- GRAB DYNAMIC THEME ---
    final primaryColor = Theme.of(context).colorScheme.primary;
    final titleColor = isDarkMode ? Colors.white70 : primaryColor;
    final amountColor = Colors.redAccent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('expenses')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, expenseSnapshot) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase
                    .from('income')
                    .stream(primaryKey: ['id'])
                    .order('created_at', ascending: false),
                builder: (context, incomeSnapshot) {
                  double totalExpenses = 0.0;
                  List<Map<String, dynamic>> expenses = [];
                  List<Map<String, dynamic>> incomes = [];

                  if (expenseSnapshot.hasData) {
                    expenses = expenseSnapshot.data!;
                    for (var item in expenses) {
                      final date = DateTime.parse(item['created_at']).toLocal();
                      final now = DateTime.now();

                      if (_isYearlyView) {
                        if (date.year == now.year) {
                          totalExpenses += (item['amount'] ?? 0.0);
                        }
                      } else {
                        if (date.year == now.year && date.month == now.month) {
                          totalExpenses += (item['amount'] ?? 0.0);
                        }
                      }
                    }
                  }

                  if (incomeSnapshot.hasData) {
                    incomes = incomeSnapshot.data!;
                  }

                  final chartSpots = _generateChartData(incomes, expenses);

                  return RefreshIndicator(
                    color: primaryColor,
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 800));
                      setState(() {});
                    },
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        // --- 1. HEADER & GRAPH ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 30,
                              bottom: 10,
                              left: 20,
                              right: 20,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color:
                                    isDarkMode
                                        ? Colors.grey[850]
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(20),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _isYearlyView
                                            ? "This Year's Expenses"
                                            : "This Month's Expenses",
                                        style: TextStyle(
                                          color: titleColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),

                                      // --- TUTORIAL STEP 1: TOGGLE ---
                                      Showcase.withWidget(
                                        key: _toggleKey,
                                        width: 280,
                                        height: 160,
                                        container: _buildCustomTooltip(
                                          context: context,
                                          title: 'Expense Time Views',
                                          description:
                                              'Just like Income, you can switch between Monthly and Yearly views to track your spending habits.',
                                          isLastStep: false,
                                          primaryColor: Colors.redAccent,
                                        ),
                                        child: GestureDetector(
                                          onTap:
                                              () => setState(
                                                () =>
                                                    _isYearlyView =
                                                        !_isYearlyView,
                                              ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: primaryColor.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.swap_horiz,
                                                  size: 16,
                                                  color: primaryColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _isYearlyView
                                                      ? "Yearly"
                                                      : "Monthly",
                                                  style: TextStyle(
                                                    color: primaryColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),

                                  Text(
                                    NumberFormat.currency(
                                      locale: 'en_MY',
                                      symbol: 'RM ',
                                    ).format(totalExpenses),
                                    style: TextStyle(
                                      color: amountColor,
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -1,
                                    ),
                                  ),

                                  const SizedBox(height: 15),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
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
                                          const SizedBox(width: 4),
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
                                          const SizedBox(width: 4),
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
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            "Balance",
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
                                  const SizedBox(height: 20),

                                  SizedBox(
                                    height: 160,
                                    child: LineChart(
                                      LineChartData(
                                        gridData: const FlGridData(show: false),
                                        borderData: FlBorderData(show: false),
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
                                              reservedSize: 22,
                                              getTitlesWidget: (value, meta) {
                                                const style = TextStyle(
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                );
                                                String text = '';
                                                if (_isYearlyView) {
                                                  if (value == 2) text = 'Feb';
                                                  if (value == 5) text = 'May';
                                                  if (value == 8) text = 'Aug';
                                                  if (value == 11) text = 'Nov';
                                                } else {
                                                  if (value % 5 == 0 &&
                                                      value > 0) {
                                                    text =
                                                        value
                                                            .toInt()
                                                            .toString();
                                                  }
                                                }
                                                return SideTitleWidget(
                                                  axisSide: meta.axisSide,
                                                  space: 4,
                                                  child: Text(
                                                    text,
                                                    style: style,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 35,
                                              getTitlesWidget: (value, meta) {
                                                if (value == 0) {
                                                  return const SizedBox();
                                                }
                                                return Text(
                                                  NumberFormat.compact().format(
                                                    value,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        lineBarsData: [
                                          LineChartBarData(
                                            spots: chartSpots['income']!,
                                            isCurved: true,
                                            color: Colors.blueAccent,
                                            barWidth: 3,
                                            isStrokeCapRound: true,
                                            dotData: const FlDotData(
                                              show: false,
                                            ),
                                            belowBarData: BarAreaData(
                                              show: true,
                                              color: Colors.blueAccent
                                                  .withOpacity(0.1),
                                            ),
                                          ),
                                          LineChartBarData(
                                            spots: chartSpots['expenses']!,
                                            isCurved: true,
                                            color: Colors.redAccent,
                                            barWidth: 3,
                                            isStrokeCapRound: true,
                                            dotData: const FlDotData(
                                              show: false,
                                            ),
                                            belowBarData: BarAreaData(
                                              show: true,
                                              color: Colors.redAccent
                                                  .withOpacity(0.1),
                                            ),
                                          ),
                                          LineChartBarData(
                                            spots: chartSpots['balance']!,
                                            isCurved: true,
                                            color: primaryColor,
                                            barWidth: 3,
                                            isStrokeCapRound: true,
                                            dotData: const FlDotData(
                                              show: false,
                                            ),
                                            belowBarData: BarAreaData(
                                              show: false,
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
                        ),

                        // --- 2. THE TRANSACTIONS LIST ---
                        if (expenseSnapshot.connectionState ==
                            ConnectionState.waiting)
                          const SliverFillRemaining(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (expenses.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(isDarkMode, primaryColor),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final item = expenses[index];
                                return _buildDismissibleCard(
                                  item,
                                  isDarkMode,
                                  primaryColor,
                                );
                              }, childCount: expenses.length),
                            ),
                          ),

                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // --- TUTORIAL STEP 2: FLOATING ACTION BUTTON ---
          Positioned(
            bottom: 16,
            right: 16,
            child: Showcase.withWidget(
              key: _fabKey,
              width: 280,
              height: 160,
              targetShapeBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              container: _buildCustomTooltip(
                context: context,
                title: 'Log Expenses',
                description: 'Tap here to manually add a new expense record.',
                isLastStep: true,
                primaryColor: Colors.redAccent,
              ),
              child: FloatingActionButton.extended(
                onPressed: () => _showAddExpenseSheet(primaryColor),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 4,
                icon: const Icon(Icons.add),
                label: const Text(
                  "Add Expense",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SMART DISMISSIBLE CARD ---
  Widget _buildDismissibleCard(
    Map<String, dynamic> item,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final category = item['category'] ?? "General";
    final isSynced = category == 'Debt Repayment' || category == 'Savings';

    return Dismissible(
      key: Key(item['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Delete Expense?"),
              content: Text(
                isSynced
                    ? "This is an auto-synced record from your Targets.\n\nAre you sure you want to remove it?\n\n(Note: This will not undo your Goal/Commitment progress)."
                    : "Are you sure you want to remove this record?",
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    "Delete",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) => _deleteExpense(item['id']),
      child: _buildExpenseCard(item, isDarkMode),
    );
  }

  // --- UPGRADED EXPENSE CARD (HANDLES SYNCED UI) ---
  Widget _buildExpenseCard(Map<String, dynamic> item, bool isDarkMode) {
    final amount = item['amount'] ?? 0.0;
    final merchant = item['merchant'] ?? "Unknown";
    final category = item['category'] ?? "General";
    final date = DateTime.parse(item['created_at']).toLocal();
    final formattedDate = DateFormat('dd MMM • h:mm a').format(date);

    // Default icon and color
    IconData cardIcon = Icons.arrow_upward;
    Color iconColor = Colors.redAccent;

    // Catch auto-synced items to make them look distinct!
    if (category == 'Debt Repayment') {
      cardIcon = Icons.credit_score;
      iconColor = Colors.orangeAccent;
    } else if (category == 'Savings') {
      cardIcon = Icons.savings;
      iconColor = Colors.blueAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(cardIcon, color: iconColor, size: 22),
        ),
        title: Text(
          merchant,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              category,
              style: TextStyle(
                fontSize: 12,
                color: iconColor.withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              formattedDate,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: Text(
          "-RM ${amount.toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: iconColor, // Color matches the theme of the item
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 60,
            color:
                isDarkMode
                    ? Colors.grey.shade600
                    : primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 15),
          Text(
            "No Expenses Yet",
            style: TextStyle(
              fontSize: 16,
              color:
                  isDarkMode
                      ? Colors.grey.shade400
                      : primaryColor.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SEPARATE WIDGET FOR THE ADD FORM
// ==========================================
class _AddExpenseForm extends StatefulWidget {
  final Color themeColor;
  const _AddExpenseForm({required this.themeColor});

  @override
  State<_AddExpenseForm> createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<_AddExpenseForm> {
  final supabase = Supabase.instance.client;
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();

  final _customCategoryController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  List<String> _categories = [];
  String? _selectedCategory;

  bool _isSaving = false;
  bool _isLoadingCategories = true;
  bool _showCustomCategoryInput = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await supabase
          .from('expense_categories')
          .select('name')
          .order('name');

      final List<String> fetchedCats =
          (response as List).map((e) => e['name'] as String).toList();

      if (mounted) {
        setState(() {
          bool hasOther = fetchedCats.any((c) => c.toLowerCase() == 'other');
          if (!hasOther) {
            fetchedCats.add('Other');
          }

          if (fetchedCats.isNotEmpty) {
            _categories = fetchedCats;
            _selectedCategory = _categories.first;
            _showCustomCategoryInput =
                _selectedCategory?.toLowerCase() == 'other';
          } else {
            _categories = ['General', 'Other'];
            _selectedCategory = 'General';
          }
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      if (mounted) {
        setState(() {
          _categories = ['General', 'Other'];
          _selectedCategory = 'General';
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final newDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (newDate != null) {
      final newDateTime = DateTime(
        newDate.year,
        newDate.month,
        newDate.day,
        now.hour,
        now.minute,
      );
      setState(() => _selectedDate = newDateTime);
    }
  }

  Future<void> _saveExpense() async {
    if (_amountController.text.isEmpty ||
        _merchantController.text.isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    if (_showCustomCategoryInput &&
        _customCategoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please type a custom category name")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String finalCategory = _selectedCategory!;

      if (_showCustomCategoryInput) {
        finalCategory = _customCategoryController.text.trim();
        try {
          final existing =
              await supabase
                  .from('expense_categories')
                  .select()
                  .ilike('name', finalCategory)
                  .maybeSingle();

          if (existing == null) {
            await supabase.from('expense_categories').insert({
              'name': finalCategory,
            });
          }
        } catch (e) {
          debugPrint(
            "Notice: Custom category insert failed. Handled string fallback anyway. $e",
          );
        }
      } else if (finalCategory.toLowerCase() == 'other') {
        finalCategory = 'Other';
      }

      await supabase.from('expenses').insert({
        'user_id': supabase.auth.currentUser!.id,
        'amount': double.parse(_amountController.text),
        'merchant': _merchantController.text,
        'category': finalCategory,
        'created_at': _selectedDate.toUtc().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Expense Saved!"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final inputFillColor = isDarkMode ? Colors.grey[850] : Colors.white;
    final dateDisplay = DateFormat('dd MMM yyyy').format(_selectedDate);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : null,
        gradient:
            isDarkMode
                ? null
                : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(Colors.white, widget.themeColor, 0.05)!,
                    Color.lerp(Colors.white, widget.themeColor, 0.15)!,
                    Color.lerp(Colors.white, widget.themeColor, 0.05)!,
                  ],
                ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Text(
              "Add Manual Expense",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: "Amount (RM)",
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.attach_money, color: widget.themeColor),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _merchantController,
              decoration: InputDecoration(
                labelText: "Store / Merchant",
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.storefront, color: widget.themeColor),
              ),
            ),
            const SizedBox(height: 15),

            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: "Date",
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(
                    Icons.calendar_today,
                    color: widget.themeColor,
                  ),
                ),
                child: Text(dateDisplay, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 15),

            _isLoadingCategories
                ? Center(
                  child: CircularProgressIndicator(color: widget.themeColor),
                )
                : DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: "Category",
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.category, color: widget.themeColor),
                  ),
                  items:
                      _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                        _showCustomCategoryInput =
                            _selectedCategory?.toLowerCase() == 'other';
                      });
                    }
                  },
                ),

            if (_showCustomCategoryInput) ...[
              const SizedBox(height: 15),
              TextField(
                controller: _customCategoryController,
                decoration: InputDecoration(
                  labelText: "Custom Category Name",
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.edit, color: widget.themeColor),
                ),
                autofocus: true,
              ),
            ],

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child:
                    _isSaving
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          "Save Expense",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
