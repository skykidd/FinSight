import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class GoalsPage extends StatefulWidget {
  final bool showTutorial;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;

  const GoalsPage({
    super.key,
    this.showTutorial = false,
    this.onTutorialNext,
    this.onTutorialSkip,
  });

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _commitments = [];
  List<Map<String, dynamic>> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- DATABASE FETCHING ---
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final commitmentsData = await supabase
          .from('commitments')
          .select()
          .order('created_at', ascending: true);

      final goalsData = await supabase
          .from('goals')
          .select()
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _commitments = List<Map<String, dynamic>>.from(commitmentsData);
          _goals = List<Map<String, dynamic>>.from(goalsData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching goals/commitments: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACTUAL DELETE FUNCTION ---
  Future<void> _deleteItem(String table, int id) async {
    try {
      await supabase.from(table).delete().eq('id', id);
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Item deleted successfully"),
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

  // --- HELPER: CALCULATE MONTHS BETWEEN NOW AND TARGET DATE ---
  int _calculateMonthsLeft(DateTime targetDate) {
    final now = DateTime.now();
    int months =
        (targetDate.year - now.year) * 12 + targetDate.month - now.month;
    return months > 0 ? months : 1; // Minimum 1 month to avoid dividing by zero
  }

  // --- DELETE CONFIRMATION DIALOG ---
  void _showDeleteConfirmationDialog(String table, int id, String itemName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Confirm Deletion"),
            content: Text(
              "Are you sure you want to delete '$itemName'?\n\nThis action cannot be undone.",
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context); // Close the dialog first
                  _deleteItem(table, id); // Actually delete it
                },
                child: const Text("Delete"),
              ),
            ],
          ),
    );
  }

  // --- ADD UI DIALOG (WITH STATEFUL BUILDER FOR LIVE MATH) ---
  void _showAddDialog() {
    bool isCommitment = _tabController.index == 0;

    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final monthlyCtrl = TextEditingController();

    DateTime? selectedTargetDate;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              // Live calculation for recommendation
              double targetAmount = double.tryParse(targetCtrl.text) ?? 0.0;
              double recommendedMonthly = 0.0;
              if (!isCommitment &&
                  targetAmount > 0 &&
                  selectedTargetDate != null) {
                int monthsLeft = _calculateMonthsLeft(selectedTargetDate!);
                recommendedMonthly = targetAmount / monthsLeft;
              }

              return AlertDialog(
                title: Text(
                  isCommitment ? "Add New Commitment" : "Add Savings Goal",
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText:
                              isCommitment
                                  ? "Loan Name (e.g. Car Loan)"
                                  : "Goal Name (e.g. Vacation)",
                          prefixIcon: Icon(
                            isCommitment ? Icons.receipt_long : Icons.flag,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: targetCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (val) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText:
                              isCommitment
                                  ? "Total Debt Amount (RM)"
                                  : "Target Amount (RM)",
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                      ),

                      if (isCommitment) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: monthlyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: "Monthly Payment (RM)",
                            prefixIcon: Icon(Icons.calendar_month),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 20),
                        // OPTIONAL TARGET DATE PICKER FOR GOALS
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(
                                const Duration(days: 30),
                              ),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2050),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedTargetDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.5),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event, color: Colors.green),
                                const SizedBox(width: 10),
                                Text(
                                  selectedTargetDate == null
                                      ? "Set Target Date (Optional)"
                                      : "Target: ${DateFormat('dd MMM yyyy').format(selectedTargetDate!)}",
                                  style: TextStyle(
                                    color:
                                        selectedTargetDate == null
                                            ? Colors.grey[600]
                                            : Colors.green,
                                    fontWeight:
                                        selectedTargetDate == null
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // LIVE RECOMMENDATION UI
                        if (selectedTargetDate != null && targetAmount > 0) ...[
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lightbulb,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "💡 Recommended: Save RM ${recommendedMonthly.toStringAsFixed(0)} / month to hit your goal on time!",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isCommitment ? Colors.redAccent : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.isEmpty || targetCtrl.text.isEmpty)
                        return;

                      final targetAmount =
                          double.tryParse(targetCtrl.text) ?? 0.0;
                      final user = supabase.auth.currentUser;
                      if (user == null) return;

                      try {
                        if (isCommitment) {
                          final monthly =
                              double.tryParse(monthlyCtrl.text) ?? 0.0;
                          await supabase.from('commitments').insert({
                            'user_id': user.id,
                            'name': nameCtrl.text,
                            'total_amount': targetAmount,
                            'monthly_payment': monthly,
                            'paid_amount': 0.0,
                          });
                        } else {
                          await supabase.from('goals').insert({
                            'user_id': user.id,
                            'name': nameCtrl.text,
                            'target_amount': targetAmount,
                            'saved_amount': 0.0,
                            'target_date':
                                selectedTargetDate?.toIso8601String(),
                          });
                        }
                        if (mounted) Navigator.pop(context);
                        _fetchData();
                      } catch (e) {
                        debugPrint("Insert Error: $e");
                      }
                    },
                    child: const Text("Save"),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _showUpdateProgressDialog(Map<String, dynamic> item, bool isCommitment) {
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(isCommitment ? "Log Payment" : "Add Funds"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "How much did you ${isCommitment ? 'pay towards' : 'save for'} ${item['name']}?",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: "Amount (RM)",
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isCommitment ? Colors.redAccent : Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (amountCtrl.text.isEmpty) return;
                  final addedAmount = double.tryParse(amountCtrl.text) ?? 0.0;
                  final user = supabase.auth.currentUser;
                  if (user == null) return;

                  try {
                    if (isCommitment) {
                      // 1. Update the progress bar on the Commitment
                      final newTotal =
                          (item['paid_amount'] as num).toDouble() + addedAmount;
                      await supabase
                          .from('commitments')
                          .update({'paid_amount': newTotal})
                          .eq('id', item['id']);

                      // 2. SMART SYNC: Auto-log this as an expense so the balance drops!
                      await supabase.from('expenses').insert({
                        'user_id': user.id,
                        'amount': addedAmount,
                        'merchant': 'Payment: ${item['name']}',
                        'category': 'Debt Repayment',
                        'created_at': DateTime.now().toIso8601String(),
                      });
                    } else {
                      // 1. Update the progress bar on the Savings Goal
                      final newTotal =
                          (item['saved_amount'] as num).toDouble() +
                          addedAmount;
                      await supabase
                          .from('goals')
                          .update({'saved_amount': newTotal})
                          .eq('id', item['id']);

                      // 2. SMART SYNC: Auto-log this as an expense (moving cash to savings)
                      await supabase.from('expenses').insert({
                        'user_id': user.id,
                        'amount': addedAmount,
                        'merchant': 'Saved: ${item['name']}',
                        'category': 'Savings',
                        'created_at': DateTime.now().toIso8601String(),
                      });
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Success! RM ${addedAmount.toStringAsFixed(0)} automatically synced to Expenses.",
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    _fetchData(); // Refresh the UI
                  } catch (e) {
                    debugPrint("Update Error: $e");
                  }
                },
                child: const Text("Confirm"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isCommitmentTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          "Targets & Commitments",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isCommitmentTab ? Colors.redAccent : Colors.green,
          labelColor: isCommitmentTab ? Colors.redAccent : Colors.green,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.credit_score), text: "Commitments"),
            Tab(icon: Icon(Icons.savings), text: "Savings Goals"),
          ],
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildListView(
                    _commitments,
                    isCommitment: true,
                    isDarkMode: isDarkMode,
                  ),
                  _buildListView(
                    _goals,
                    isCommitment: false,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: isCommitmentTab ? Colors.redAccent : Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(isCommitmentTab ? "Add Debt" : "Add Goal"),
      ),
    );
  }

  Widget _buildListView(
    List<Map<String, dynamic>> items, {
    required bool isCommitment,
    required bool isDarkMode,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCommitment ? Icons.money_off : Icons.account_balance_wallet,
              size: 64,
              color: Colors.grey.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              "No ${isCommitment ? 'commitments' : 'goals'} found.",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap the button below to start tracking.",
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: isCommitment ? Colors.redAccent : Colors.green,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: 20,
          left: 16,
          right: 16,
          bottom: 100,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          final name = item['name'] ?? "Unknown";
          final target =
              (isCommitment
                      ? item['total_amount']
                      : item['target_amount'] as num?)
                  ?.toDouble() ??
              0.0;
          final current =
              (isCommitment
                      ? item['paid_amount']
                      : item['saved_amount'] as num?)
                  ?.toDouble() ??
              0.0;
          final monthly =
              isCommitment
                  ? ((item['monthly_payment'] as num?)?.toDouble() ?? 0.0)
                  : null;

          double rawProgress = target > 0 ? (current / target) : 0.0;
          double progress = rawProgress.clamp(0.0, 1.0);
          int percent = (progress * 100).toInt();

          final themeColor = isCommitment ? Colors.redAccent : Colors.green;

          // Goal Recommendation Logic for the Card
          String? targetDateStr =
              isCommitment ? null : item['target_date'] as String?;
          double recommendedMonthly = 0.0;
          DateTime? parsedDate;

          if (!isCommitment && targetDateStr != null) {
            parsedDate = DateTime.tryParse(targetDateStr);
            if (parsedDate != null) {
              int monthsLeft = _calculateMonthsLeft(parsedDate);
              double remainingAmount = target - current;
              if (remainingAmount > 0) {
                recommendedMonthly = remainingAmount / monthsLeft;
              }
            }
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: isDarkMode ? 0 : 4,
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side:
                  isDarkMode
                      ? BorderSide(color: Colors.grey[800]!)
                      : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
                        onPressed:
                            () => _showDeleteConfirmationDialog(
                              isCommitment ? 'commitments' : 'goals',
                              item['id'],
                              name,
                            ),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Monthly Payment Subtitle (If Commitment)
                  if (isCommitment && monthly != null && monthly > 0)
                    Text(
                      "RM ${monthly.toStringAsFixed(2)} / month",
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                  // Target Date Subtitle (If Goal and Date Exists)
                  if (!isCommitment && parsedDate != null)
                    Text(
                      "Target Date: ${DateFormat('MMM yyyy').format(parsedDate)} ${recommendedMonthly > 0 ? ' • Save RM ${recommendedMonthly.toStringAsFixed(0)}/mo' : ''}",
                      style: TextStyle(
                        color: themeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "RM ${current.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      Text(
                        "RM ${target.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: themeColor.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$percent% ${isCommitment ? 'Paid Off' : 'Saved'}",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed:
                            () => _showUpdateProgressDialog(item, isCommitment),
                        icon: Icon(
                          isCommitment ? Icons.payment : Icons.add_circle,
                          size: 18,
                          color: themeColor,
                        ),
                        label: Text(
                          isCommitment ? "Log Payment" : "Add Funds",
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: themeColor.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
