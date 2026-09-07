import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:showcaseview/showcaseview.dart';

class IncomePage extends StatefulWidget {
  final bool showTutorial;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;

  const IncomePage({
    super.key,
    this.showTutorial = false,
    this.onTutorialNext,
    this.onTutorialSkip,
  });

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  final supabase = Supabase.instance.client;

  final GlobalKey _toggleKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

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
  void didUpdateWidget(IncomePage oldWidget) {
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

  Future<void> _deleteIncome(int id) async {
    try {
      await supabase.from('income').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Income deleted successfully"),
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

  void _showAddIncomeSheet(Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddIncomeForm(themeColor: primaryColor),
    );
  }

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
    final primaryColor = Theme.of(context).colorScheme.primary;
    final titleColor = isDarkMode ? Colors.white70 : primaryColor;
    final amountColor = isDarkMode ? Colors.white : primaryColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('income')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false),
        builder: (context, incomeSnapshot) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('expenses')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, expenseSnapshot) {
              double totalIncome = 0.0;
              List<Map<String, dynamic>> incomes = [];
              List<Map<String, dynamic>> expenses = [];

              if (incomeSnapshot.hasData) {
                incomes = incomeSnapshot.data!;
                for (var item in incomes) {
                  final date = DateTime.parse(item['created_at']).toLocal();
                  final now = DateTime.now();
                  if (_isYearlyView) {
                    if (date.year == now.year) {
                      totalIncome += (item['amount'] ?? 0.0);
                    }
                  } else {
                    if (date.year == now.year && date.month == now.month) {
                      totalIncome += (item['amount'] ?? 0.0);
                    }
                  }
                }
              }

              if (expenseSnapshot.hasData) expenses = expenseSnapshot.data!;

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
                            color: isDarkMode ? Colors.grey[850] : Colors.white,
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
                                        ? "This Year's Cashflow"
                                        : "This Month's Cashflow",
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  Showcase.withWidget(
                                    key: _toggleKey,
                                    width: 280,
                                    height: 160,
                                    container: _buildCustomTooltip(
                                      context: context,
                                      title: 'Time Views',
                                      description:
                                          'Switch between Monthly and Yearly cashflow views to track your trends over time.',
                                      isLastStep: false,
                                      primaryColor: primaryColor,
                                    ),
                                    child: GestureDetector(
                                      onTap:
                                          () => setState(
                                            () =>
                                                _isYearlyView = !_isYearlyView,
                                          ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                                ).format(totalIncome),
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
                                              if (value % 5 == 0 && value > 0) {
                                                text = value.toInt().toString();
                                              }
                                            }
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              space: 4,
                                              child: Text(text, style: style),
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
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.blueAccent.withOpacity(
                                            0.1,
                                          ),
                                        ),
                                      ),
                                      LineChartBarData(
                                        spots: chartSpots['expenses']!,
                                        isCurved: true,
                                        color: Colors.redAccent,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.redAccent.withOpacity(
                                            0.1,
                                          ),
                                        ),
                                      ),
                                      LineChartBarData(
                                        spots: chartSpots['balance']!,
                                        isCurved: true,
                                        color: primaryColor,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(show: false),
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

                    if (incomeSnapshot.connectionState ==
                        ConnectionState.waiting)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (incomes.isEmpty)
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
                            final item = incomes[index];
                            return _buildDismissibleCard(
                              item,
                              isDarkMode,
                              primaryColor,
                            );
                          }, childCount: incomes.length),
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

      floatingActionButton: Showcase.withWidget(
        key: _fabKey,
        width: 280,
        height: 160,
        targetShapeBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        container: _buildCustomTooltip(
          context: context,
          title: 'Log Income',
          description: 'Tap here to manually add a new income record.',
          isLastStep: true,
          primaryColor: Colors.green,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddIncomeSheet(primaryColor),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add),
          label: const Text(
            "Add Income",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  IconData _getIconForSource(String source) {
    final s = source.toLowerCase();
    if (s.contains('salary') || s.contains('wage') || s.contains('pay'))
      return Icons.work;
    if (s.contains('invest') ||
        s.contains('dividend') ||
        s.contains('interest'))
      return Icons.trending_up;
    if (s.contains('gift') || s.contains('ang pow') || s.contains('bonus'))
      return Icons.card_giftcard;
    if (s.contains('sale') || s.contains('business') || s.contains('freelance'))
      return Icons.storefront;
    if (s.contains('withdraw') || s.contains('refund'))
      return Icons.account_balance_wallet;
    return Icons.arrow_downward;
  }

  Widget _buildDismissibleCard(
    Map<String, dynamic> item,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final source = item['source'] ?? "Unknown";
    final isSynced = source.startsWith('Withdrawal:');

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
              title: const Text("Delete Income?"),
              content: Text(
                isSynced
                    ? "This is an auto-synced record from your Targets.\n\nAre you sure you want to remove it?\n\n(Note: This will not undo your Goal/Commitment progress)."
                    : "Are you sure you want to remove this record?",
              ),
              actions: [
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
      onDismissed: (direction) => _deleteIncome(item['id']),
      child: _buildIncomeCard(item, isDarkMode, primaryColor),
    );
  }

  Widget _buildIncomeCard(
    Map<String, dynamic> item,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final amount = item['amount'] ?? 0.0;
    final source = item['source'] ?? "Unknown";
    final date = DateTime.parse(item['created_at']).toLocal();
    final formattedDate = DateFormat('dd MMM • h:mm a').format(date);
    final bool isRecurring = item['is_recurring'] ?? false;

    IconData cardIcon = _getIconForSource(source);
    Color iconColor = Colors.green;

    if (source.startsWith('Withdrawal:')) {
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                source,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isRecurring)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.autorenew,
                  color: Colors.blueAccent,
                  size: 16,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                if (isRecurring)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "Monthly",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Text(
          "+RM ${amount.toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: iconColor,
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
            Icons.account_balance_wallet_outlined,
            size: 60,
            color:
                isDarkMode
                    ? Colors.grey.shade600
                    : primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 15),
          Text(
            "No Income Yet",
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

class _AddIncomeForm extends StatefulWidget {
  final Color themeColor;
  const _AddIncomeForm({required this.themeColor});

  @override
  State<_AddIncomeForm> createState() => _AddIncomeFormState();
}

class _AddIncomeFormState extends State<_AddIncomeForm> {
  final supabase = Supabase.instance.client;
  final _amountController = TextEditingController();
  final _sourceController = TextEditingController();

  final _customCategoryController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;

  bool _isSaving = false;
  bool _isRecurring = false;
  bool _isLoadingCategories = true;

  bool _showCustomCategoryInput = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final data = await supabase
          .from('income_categories')
          .select('id, name')
          .order('name');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);

          bool hasOther = _categories.any(
            (c) => c['name'].toString().toLowerCase() == 'other',
          );
          if (!hasOther) {
            _categories.add({'id': -1, 'name': 'Other'});
          }

          if (_categories.isNotEmpty) {
            _selectedCategoryId = _categories.first['id'];

            final catName =
                _categories
                    .firstWhere((c) => c['id'] == _selectedCategoryId)['name']
                    .toString()
                    .toLowerCase();
            _showCustomCategoryInput = catName == 'other';
          }

          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      if (mounted) setState(() => _isLoadingCategories = false);
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
      setState(
        () =>
            _selectedDate = DateTime(
              newDate.year,
              newDate.month,
              newDate.day,
              now.hour,
              now.minute,
            ),
      );
    }
  }

  Future<void> _saveIncome() async {
    if (_amountController.text.isEmpty || _sourceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
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
      int? finalCategoryId = _selectedCategoryId;

      if (_showCustomCategoryInput) {
        String newCatName = _customCategoryController.text.trim();

        try {
          final existing =
              await supabase
                  .from('income_categories')
                  .select()
                  .ilike('name', newCatName)
                  .maybeSingle();

          if (existing != null) {
            finalCategoryId = existing['id'];
          } else {
            final inserted =
                await supabase
                    .from('income_categories')
                    .insert({'name': newCatName})
                    .select()
                    .single();
            finalCategoryId = inserted['id'];
          }
        } catch (e) {
          debugPrint(
            "Notice: Custom category insert failed or not permitted. Falling back to source tracking. $e",
          );
          _sourceController.text = "${_sourceController.text} ($newCatName)";
          if (finalCategoryId == -1) finalCategoryId = null;
        }
      } else {
        if (finalCategoryId == -1) finalCategoryId = null;
      }

      await supabase.from('income').insert({
        'user_id': supabase.auth.currentUser!.id,
        'amount': double.parse(_amountController.text),
        'source': _sourceController.text,
        'category_id': finalCategoryId,
        'is_recurring': _isRecurring,
        'created_at': _selectedDate.toUtc().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Income Saved!"),
            backgroundColor: Colors.green,
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
              "Add New Income",
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
              controller: _sourceController,
              decoration: InputDecoration(
                labelText: "Source (e.g., Salary, Client Name)",
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.business, color: widget.themeColor),
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
                child: Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 15),

            _isLoadingCategories
                ? Center(
                  child: CircularProgressIndicator(color: widget.themeColor),
                )
                : DropdownButtonFormField<int?>(
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
                  value: _selectedCategoryId,
                  items:
                      _categories.isEmpty
                          ? [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text("No categories available"),
                            ),
                          ]
                          : _categories
                              .map(
                                (cat) => DropdownMenuItem<int>(
                                  value: cat['id'],
                                  child: Text(cat['name']),
                                ),
                              )
                              .toList(),
                  onChanged:
                      _categories.isEmpty
                          ? null
                          : (val) {
                            setState(() {
                              _selectedCategoryId = val;
                              final catName =
                                  _categories
                                      .firstWhere((c) => c['id'] == val)['name']
                                      .toString()
                                      .toLowerCase();
                              _showCustomCategoryInput = catName == 'other';
                            });
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

            const SizedBox(height: 15),

            Container(
              decoration: BoxDecoration(
                color: inputFillColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                title: const Text(
                  "Repeat Monthly",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  "Automatically re-log this income on the same day next month.",
                  style: TextStyle(fontSize: 12),
                ),
                value: _isRecurring,
                activeColor: Colors.blueAccent,
                secondary: const Icon(
                  Icons.autorenew,
                  color: Colors.blueAccent,
                ),
                onChanged: (bool value) => setState(() => _isRecurring = value),
              ),
            ),
            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveIncome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
                          "Save Income",
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
