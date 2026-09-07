import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaxPage extends StatefulWidget {
  // --- INJECTED FROM HOMEPAGE ---
  final bool showTutorial;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;

  const TaxPage({
    super.key,
    this.showTutorial = false,
    this.onTutorialNext,
    this.onTutorialSkip,
  });

  @override
  State<TaxPage> createState() => _TaxPageState();
}

class _TaxPageState extends State<TaxPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  // --- TUTORIAL KEYS ---
  final GlobalKey _taxCardKey = GlobalKey();

  final int _currentYear = DateTime.now().year;

  double _totalIncome = 0;

  // Tax Relief Categories
  final double _baseRelief = 9000.0; // Automatic individual relief in Malaysia

  // --- NEW: Dynamic Reliefs List ---
  List<Map<String, dynamic>> _dynamicReliefs = [];

  double _chargeableIncome = 0;
  double _estimatedTax = 0;

  @override
  void initState() {
    super.initState();
    _calculateTax();

    // Trigger tutorial if active on load
    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerTutorial();
      });
    }
  }

  @override
  void didUpdateWidget(TaxPage oldWidget) {
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
          ShowCaseWidget.of(context).startShowCase([_taxCardKey]);
          await prefs.setBool('has_seen_tax_tutorial_${user.id}', true);
        }
      }
    });
  }

  // --- CUSTOM TUTORIAL POP-UP BUILDER ---
  Widget _buildCustomTooltip({
    required BuildContext context,
    required String title,
    required String description,
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 10,
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  ShowCaseWidget.of(context).dismiss();

                  // --- GRAND FINALE SUCCESS MESSAGE ---
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        "🎉 Tutorial Complete! You are ready to use FinSight.",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );

                  widget.onTutorialNext
                      ?.call(); // THIS FINISHES THE ENTIRE TOUR!
                },
                child: const Text(
                  "Finish Tour",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _calculateTax() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final startOfYear = '$_currentYear-01-01T00:00:00Z';
      final endOfYear = '$_currentYear-12-31T23:59:59Z';

      // 1. Fetch Taxable Income
      final incomeData = await supabase
          .from('income')
          .select('amount, is_taxable')
          .gte('created_at', startOfYear)
          .lte('created_at', endOfYear);

      double tempIncome = 0;
      for (var row in incomeData) {
        bool isTaxable = row['is_taxable'] ?? true;
        if (isTaxable) {
          tempIncome += (row['amount'] ?? 0).toDouble();
        }
      }

      // 2. Fetch Dynamic Tax Deductions from Admin Table
      List<Map<String, dynamic>> activeReliefs = [];
      try {
        final deductionsData = await supabase.from('tax_deductions').select();
        for (var d in deductionsData) {
          activeReliefs.add({
            'name': d['name'],
            'cap': (d['amount'] ?? 0).toDouble(),
            'spent': 0.0,
          });
        }
      } catch (e) {
        debugPrint("Notice: tax_deductions table not found or empty. $e");
      }

      // 3. Fetch Expenses for Reliefs
      final expenseData = await supabase
          .from('expenses')
          .select('amount, category')
          .gte('created_at', startOfYear)
          .lte('created_at', endOfYear);

      // --- IMPROVED KEYWORD MAPPING ---
      final Map<String, List<String>> reliefKeywords = {
        'Lifestyle': [
          'book',
          'internet',
          'smartphone',
          'lifestyle',
          'journal',
          'gym',
          'computer',
          'laptop',
        ],
        'Education': [
          'tuition',
          'fee',
          'university',
          'college',
          'course',
          'school',
          'student',
        ],
        'Medical': [
          'klinik',
          'clinic',
          'hospital',
          'medical',
          'doctor',
          'health',
        ],
      };

      for (var row in expenseData) {
        double amt = (row['amount'] ?? 0).toDouble();
        String cat = (row['category'] ?? '').toString().toLowerCase();

        for (var relief in activeReliefs) {
          String reliefName = relief['name'].toString();

          // Check for direct match OR keyword match
          bool isMatch = cat == reliefName.toLowerCase();
          if (!isMatch && reliefKeywords.containsKey(reliefName)) {
            for (var keyword in reliefKeywords[reliefName]!) {
              if (cat.contains(keyword.toLowerCase())) {
                isMatch = true;
                break;
              }
            }
          }

          if (isMatch) {
            relief['spent'] += amt;
            break;
          }
        }
      }

      // 4. Apply Legal Caps & Calculate Total
      double totalDynamicRelief = 0;
      for (var relief in activeReliefs) {
        if (relief['spent'] > relief['cap']) {
          relief['spent'] = relief['cap'];
        }
        totalDynamicRelief += relief['spent'];
      }

      // 5. Calculate Chargeable Income
      double totalReliefs = _baseRelief + totalDynamicRelief;
      double chargeable = tempIncome - totalReliefs;
      if (chargeable < 0) chargeable = 0;

      // --- 6. DYNAMIC TAX CALCULATION ---
      double tax = 0;

      if (chargeable > 0) {
        try {
          final bracketData =
              await supabase
                  .from('tax_brackets')
                  .select()
                  .eq('year', _currentYear)
                  .lte('min_income', chargeable)
                  .gte('max_income', chargeable)
                  .single();

          double baseTax = (bracketData['base_tax'] ?? 0).toDouble();
          double taxRate = (bracketData['tax_rate'] ?? 0).toDouble();
          double minIncomeBound = (bracketData['min_income'] ?? 0).toDouble();

          double excessAmount =
              chargeable - (minIncomeBound > 0 ? minIncomeBound - 1 : 0);
          tax = baseTax + (excessAmount * taxRate);
        } catch (e) {
          debugPrint("Notice: tax_brackets missing or no bracket found. $e");
        }

        if (chargeable > 0 && chargeable <= 35000) {
          tax -= 400;
          if (tax < 0) tax = 0;
        }
      }

      if (mounted) {
        setState(() {
          _totalIncome = tempIncome;
          _dynamicReliefs = activeReliefs;
          _chargeableIncome = chargeable;
          _estimatedTax = tax;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Tax calculation error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // --- DYNAMIC THEME EXTRACTION ---
    final primaryColor = Theme.of(context).colorScheme.primary;
    final titleColor = isDarkMode ? Colors.white : primaryColor;
    final cardColor = isDarkMode ? Colors.grey[850] : Colors.white;

    final currencyFormat = NumberFormat.currency(
      locale: 'en_MY',
      symbol: 'RM ',
    );

    return Scaffold(
      backgroundColor: Colors.transparent, // Respects homepage ombre gradient
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: 60,
                  left: 20,
                  right: 20,
                  bottom:
                      120, // <--- UX FIX: Prevents nav bar from covering bottom text!
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- TEXT HEADER ---
                    Text(
                      "Annual e-Filing ($_currentYear)",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: titleColor, // Follows Theme
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    // --- TUTORIAL STEP 1: AUTOMATED TAX CARD ---
                    Showcase.withWidget(
                      key: _taxCardKey,
                      width: 280,
                      height: 160,
                      container: _buildCustomTooltip(
                        context: context,
                        title: 'Automated Tax Estimation',
                        description:
                            'FinSight actively calculates your estimated LHDN e-Filing taxes based on your logged income and deductible expenses.',
                        primaryColor: primaryColor,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color.lerp(primaryColor, Colors.white, 0.2)!,
                              primaryColor,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            if (!isDarkMode)
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Estimated Tax Payable",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              currencyFormat.format(_estimatedTax),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    Text(
                      "Calculation Breakdown",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: titleColor, // Follows Theme
                      ),
                    ),
                    const SizedBox(height: 15),

                    // --- FLOATING BREAKDOWN CARD ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
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
                      child: Column(
                        children: [
                          _buildRow(
                            "Total Annual Income",
                            _totalIncome,
                            Colors.green,
                            isDarkMode,
                          ),
                          const Divider(),

                          // Reliefs
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Minus Tax Reliefs:",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          _buildRow(
                            "Individual Base Relief",
                            -_baseRelief,
                            Colors.redAccent,
                            isDarkMode,
                          ),

                          // --- DYNAMIC RELIEFS DISPLAY ---
                          ..._dynamicReliefs.map((relief) {
                            String capFormatted = NumberFormat(
                              '#,##0',
                            ).format(relief['cap']);

                            return _buildRow(
                              "${relief['name']} (Max RM$capFormatted)",
                              -relief['spent'],
                              Colors.redAccent,
                              isDarkMode,
                            );
                          }),

                          const Divider(thickness: 2),

                          // Chargeable Income
                          _buildRow(
                            "Chargeable Income",
                            _chargeableIncome,
                            Colors.blue,
                            isDarkMode,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- Information Box ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "This is an estimation based on your logged expenses and income. For official submissions, please refer to the official LHDN portal.",
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildRow(
    String title,
    double amount,
    Color amountColor,
    bool isDark, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isDark ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            NumberFormat.currency(
              locale: 'en_MY',
              symbol: 'RM ',
            ).format(amount),
            style: TextStyle(
              fontSize: 15,
              color: amountColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
