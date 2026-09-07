import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <-- ADDED DOTENV IMPORT

// DEAD IMPORT REMOVED FROM HERE!

class ScanPage extends StatefulWidget {
  final bool showTutorial;
  final VoidCallback? onTutorialNext;
  final VoidCallback? onTutorialSkip;

  const ScanPage({
    super.key,
    this.showTutorial = false,
    this.onTutorialNext,
    this.onTutorialSkip,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final supabase = Supabase.instance.client;
  File? _imageFile;
  Uint8List? _webImage;

  bool _isScanning = false;
  bool _isSaving = false;
  String _extractedText = "";

  final GlobalKey _buttonsKey = GlobalKey();
  final GlobalKey _typeToggleKey = GlobalKey();

  bool _isIncome = false;
  bool _isTaxable = false;
  bool _isTaxDeductible = false;

  final _amountController = TextEditingController();
  final _sourceMerchantController = TextEditingController();
  final _customCategoryController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _expenseCategories = [];
  List<Map<String, dynamic>> _incomeCategories = [];

  String? _selectedExpenseCategory;
  int? _selectedIncomeCategoryId;

  bool _isLoadingCategories = true;
  bool _showCustomCategoryInput = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();

    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerTutorial();
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _sourceMerchantController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScanPage oldWidget) {
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
          ShowCaseWidget.of(
            context,
          ).startShowCase([_buttonsKey, _typeToggleKey]);
          await prefs.setBool('has_seen_scan_tutorial_${user.id}', true);
        }
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

  Future<void> _fetchCategories({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoadingCategories = true);

    try {
      final expResponse = await supabase
          .from('expense_categories')
          .select('name')
          .order('name');
      final incResponse = await supabase
          .from('income_categories')
          .select('id, name')
          .order('name');

      if (mounted) {
        setState(() {
          _expenseCategories = List<Map<String, dynamic>>.from(expResponse);
          if (!_expenseCategories.any(
            (c) => c['name'].toString().toLowerCase() == 'other',
          )) {
            _expenseCategories.add({'name': 'Other'});
          }
          if (_expenseCategories.isNotEmpty &&
              _selectedExpenseCategory == null) {
            _selectedExpenseCategory = _expenseCategories.first['name'];
          }

          _incomeCategories = List<Map<String, dynamic>>.from(incResponse);
          if (!_incomeCategories.any(
            (c) => c['name'].toString().toLowerCase() == 'other',
          )) {
            _incomeCategories.add({'id': -1, 'name': 'Other'});
          }
          if (_incomeCategories.isNotEmpty &&
              _selectedIncomeCategoryId == null) {
            _selectedIncomeCategoryId = _incomeCategories.first['id'];
          }

          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      if (mounted && !isRefresh) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _deleteRecord(int id) async {
    final table = _isIncome ? 'income' : 'expenses';
    try {
      await supabase.from(table).delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Scan record deleted successfully"),
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

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('food') ||
        name.contains('dining') ||
        name.contains('restaurant'))
      return Icons.restaurant;
    if (name.contains('transport') ||
        name.contains('petrol') ||
        name.contains('car'))
      return Icons.directions_car;
    if (name.contains('bill') ||
        name.contains('utilit') ||
        name.contains('internet'))
      return Icons.receipt;
    if (name.contains('shop') ||
        name.contains('cloth') ||
        name.contains('retail'))
      return Icons.shopping_bag;
    if (name.contains('health') ||
        name.contains('medical') ||
        name.contains('clinic'))
      return Icons.medical_services;
    if (name.contains('educat') ||
        name.contains('book') ||
        name.contains('school'))
      return Icons.school;
    if (name.contains('entertain') ||
        name.contains('movie') ||
        name.contains('game'))
      return Icons.sports_esports;
    if (name.contains('grocer') || name.contains('market')) {
      return Icons.shopping_cart;
    }
    return Icons.category;
  }

  // --- UNIFIED IMAGE PICKER ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 50,
        maxWidth: 1200,
      );

      if (pickedFile == null) return;

      setState(() => _isScanning = true);
      final bytes = await pickedFile.readAsBytes();

      if (kIsWeb) {
        setState(() {
          _webImage = bytes;
          _imageFile = null;
        });
      } else {
        setState(() {
          _imageFile = File(pickedFile.path);
          _webImage = null;
        });
      }

      await _scanWithCustomAPI(bytes);
    } catch (e) {
      setState(() => _isScanning = false);
    }
  }

  // --- CUSTOM API CALL (UPDATED FOR DOTENV) ---
  Future<void> _scanWithCustomAPI(Uint8List imageBytes) async {
    try {
      // PULL URL FROM .ENV FILE
      final apiUrl = dotenv.env['RECEIPT_SCANNER_API_URL']!;
      final uri = Uri.parse(apiUrl);

      var request = http.MultipartRequest('POST', uri);

      // We send raw bytes instead of a file path!
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename:
              'scanned_receipt.jpg', // Forces Python to recognize it as an image
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        final errorBody = response.body;
        print("PYTHON SERVER ERROR: $errorBody");
        throw Exception("Server Error ${response.statusCode}: $errorBody");
      }

      // --- BULLETPROOF JSON EXTRACTION ---
      final decodedBody = jsonDecode(response.body);

      if (decodedBody['status'] == 'success' &&
          decodedBody['extracted_data'] != null) {
        dynamic rawData = decodedBody['extracted_data'];
        Map<String, dynamic> extractedData = {};

        if (rawData is List && rawData.isNotEmpty) {
          extractedData = rawData[0] as Map<String, dynamic>;
        } else if (rawData is Map) {
          extractedData = Map<String, dynamic>.from(rawData);
        }

        _analyzeDonutData(extractedData);
      } else {
        throw Exception("Failed to parse receipt data");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Scan Failed: $e\nMake sure the Python server is running.",
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      setState(() => _isScanning = false);
    }
  }

  // --- BULLETPROOF RECURSIVE DONUT ANALYZER ---
  void _analyzeDonutData(Map<String, dynamic> data) {
    // HELPER 1: Recursively find text
    String? findTextValue(dynamic json, List<String> targetKeys) {
      if (json is Map) {
        for (var key in json.keys) {
          if (targetKeys.contains(key.toString().toLowerCase())) {
            var val = json[key];
            if (val != null && val is! Map && val is! List)
              return val.toString();
          }
          String? found = findTextValue(json[key], targetKeys);
          if (found != null) return found;
        }
      } else if (json is List) {
        for (var item in json) {
          String? found = findTextValue(item, targetKeys);
          if (found != null) return found;
        }
      }
      return null;
    }

    // HELPER 2: Recursively find prices, rejecting barcodes and crazy numbers
    double? findPriceValue(dynamic json, List<String> targetKeys) {
      if (json is Map) {
        for (var key in json.keys) {
          if (targetKeys.contains(key.toString().toLowerCase())) {
            var val = json[key];
            if (val != null && val is! Map && val is! List) {
              String cleaned = val
                  .toString()
                  .replaceAll(',', '.')
                  .replaceAll(RegExp(r'[^0-9.]'), '');
              double? parsed = double.tryParse(cleaned);
              if (parsed != null && parsed > 0 && parsed < 20000) return parsed;
            }
          }
          double? found = findPriceValue(json[key], targetKeys);
          if (found != null) return found;
        }
      } else if (json is List) {
        for (var item in json) {
          double? found = findPriceValue(item, targetKeys);
          if (found != null) return found;
        }
      }
      return null;
    }

    // 1. Extract Merchant Name
    String merchant =
        findTextValue(data, [
          'nm',
          'name',
          'store_name',
          'merchant',
          'company',
          'store',
        ]) ??
        "Unknown Merchant";

    // 2. Extract Total Amount
    double finalTotal =
        findPriceValue(data, ['total_price', 'grand_total', 'amount']) ??
        findPriceValue(data, ['subtotal_price', 'total', 'sub_total']) ??
        findPriceValue(data, ['cashprice', 'creditcardprice', 'pay']) ??
        0.0;

    // THE FAIL-SAFE HEURISTIC
    if (finalTotal == 0.0) {
      String rawString = data.toString();
      RegExp priceReg = RegExp(r'\b\d{1,4}\.\d{2}\b');
      Iterable<RegExpMatch> matches = priceReg.allMatches(rawString);
      double maxPrice = 0.0;
      for (var m in matches) {
        double? val = double.tryParse(m.group(0)!);
        if (val != null && val > maxPrice) maxPrice = val;
      }
      finalTotal = maxPrice;
    }

    String detectedTotal = finalTotal > 0 ? finalTotal.toStringAsFixed(2) : "";
    DateTime detectedDate = DateTime.now();

    // 3. Date Extraction
    String dateStr = findTextValue(data, ['date', 'timestamp', 'time']) ?? "";
    final RegExp dateRegex = RegExp(
      r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b',
    );
    String fullOutputString = data.toString();
    final Iterable<RegExpMatch> dateMatches = dateRegex.allMatches(
      dateStr.isNotEmpty ? dateStr : fullOutputString,
    );

    if (dateMatches.isNotEmpty) {
      try {
        final match = dateMatches.first;
        int day = int.parse(match.group(1)!);
        int month = int.parse(match.group(2)!);
        int year = int.parse(match.group(3)!);

        if (year < 100) year += 2000;
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          detectedDate = DateTime(
            year,
            month,
            day,
            DateTime.now().hour,
            DateTime.now().minute,
          );
        }
      } catch (e) {
        // Fallback silently
      }
    }

    // 4. Smart Category Detection
    String lowerText = fullOutputString.toLowerCase();
    bool autoDetectedIsIncome = _isIncome;
    bool autoDetectedTaxDeductible = false;

    final Map<String, List<String>> keywordMap = {
      'Food': [
        'kuey teow',
        'nasi',
        'ayam',
        'restaurant',
        'cafe',
        'makan',
        'kfc',
        'food',
        'minuman',
        'burger',
        'tealive',
        'maggi',
        'indomie',
      ],
      'Groceries': [
        'aeon',
        'mydin',
        'speedmart',
        'tesco',
        'grocery',
        'supermarket',
        'mart',
        'susu',
        'biskut',
        'sayur',
        'milk',
        'cracker',
      ],
      'Transport': [
        'petronas',
        'shell',
        'caltex',
        'toll',
        'touch n go',
        'parking',
        'parkir',
        'train',
        'lrt',
      ],
      'Medical': [
        'klinik',
        'hospital',
        'farmasi',
        'pharmacy',
        'ubat',
        'panadol',
        'clinic',
        'medical',
      ],
      'Education': [
        'book',
        'buku',
        'sekolah',
        'school',
        'university',
        'tuition',
        'stationery',
        'kertas',
      ],
      'Utilities': [
        'tnb',
        'syabas',
        'water',
        'elektrik',
        'bill',
        'bil ',
        'celcom',
        'maxis',
        'digi',
        'internet',
      ],
    };

    if (lowerText.contains('salary') ||
        lowerText.contains('gaji') ||
        lowerText.contains('payroll') ||
        lowerText.contains('dividend') ||
        lowerText.contains('invest')) {
      autoDetectedIsIncome = true;
    } else {
      autoDetectedIsIncome = false;
    }

    if (!autoDetectedIsIncome && _expenseCategories.isNotEmpty) {
      String detectedCat = _expenseCategories.first['name'];
      bool categoryFound = false;

      for (var category in keywordMap.keys) {
        for (var keyword in keywordMap[category]!) {
          if (lowerText.contains(keyword)) {
            detectedCat = _findMatchingCategory(_expenseCategories, category);
            categoryFound = true;
            break;
          }
        }
        if (categoryFound) break;
      }
      _selectedExpenseCategory = detectedCat;

      final List<String> taxReliefKeywords = [
        'complete medical examination',
        'full medical checkup',
        'pemeriksaan perubatan penuh',
        'medical check-up',
        'life insurance',
        'education insurance',
      ];

      for (String keyword in taxReliefKeywords) {
        if (lowerText.contains(keyword)) {
          autoDetectedTaxDeductible = true;
          break;
        }
      }
    } else if (autoDetectedIsIncome && _incomeCategories.isNotEmpty) {
      int detectedCatId = _incomeCategories.first['id'];
      if (lowerText.contains('salary') ||
          lowerText.contains('gaji') ||
          lowerText.contains('payroll')) {
        detectedCatId =
            _findMatchingIncomeCategory(_incomeCategories, 'Salary') ??
            detectedCatId;
      } else if (lowerText.contains('dividend') ||
          lowerText.contains('invest')) {
        detectedCatId =
            _findMatchingIncomeCategory(_incomeCategories, 'Investment') ??
            detectedCatId;
      }
      _selectedIncomeCategoryId = detectedCatId;
    }

    setState(() {
      _isIncome = autoDetectedIsIncome;
      _extractedText = const JsonEncoder.withIndent('  ').convert(data);
      _amountController.text = detectedTotal;
      _sourceMerchantController.text = merchant;
      _selectedDate = detectedDate;
      _isTaxDeductible = autoDetectedTaxDeductible;
      _isScanning = false;
      _showCustomCategoryInput = false;
      _customCategoryController.clear();
      _updateCategoryToggleVisibility();
    });
  }

  String _findMatchingCategory(
    List<Map<String, dynamic>> cats,
    String keyword,
  ) {
    for (var c in cats) {
      if (c['name'].toString().toLowerCase().contains(keyword.toLowerCase())) {
        return c['name'];
      }
    }
    return cats.first['name'];
  }

  int? _findMatchingIncomeCategory(
    List<Map<String, dynamic>> cats,
    String keyword,
  ) {
    for (var c in cats) {
      if (c['name'].toString().toLowerCase().contains(keyword.toLowerCase())) {
        return c['id'];
      }
    }
    return null;
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

  Future<void> _saveRecord() async {
    final amountText = _amountController.text;
    String sourceName =
        _sourceMerchantController.text.isEmpty
            ? "Unknown"
            : _sourceMerchantController.text;
    final user = supabase.auth.currentUser;

    if (user == null) return;
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter an amount")));
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
      int? finalIncomeCategoryId = _selectedIncomeCategoryId;
      String? finalExpenseCategory = _selectedExpenseCategory;

      if (_showCustomCategoryInput) {
        String newCatName = _customCategoryController.text.trim();

        if (_isIncome) {
          try {
            final existing =
                await supabase
                    .from('income_categories')
                    .select()
                    .ilike('name', newCatName)
                    .maybeSingle();
            if (existing != null) {
              finalIncomeCategoryId = existing['id'];
            } else {
              final inserted =
                  await supabase
                      .from('income_categories')
                      .insert({'name': newCatName})
                      .select()
                      .single();
              finalIncomeCategoryId = inserted['id'];
            }
          } catch (e) {
            sourceName = "$sourceName ($newCatName)";
            if (finalIncomeCategoryId == -1) finalIncomeCategoryId = null;
          }
        } else {
          finalExpenseCategory = newCatName;
          try {
            final existing =
                await supabase
                    .from('expense_categories')
                    .select()
                    .ilike('name', newCatName)
                    .maybeSingle();
            if (existing == null) {
              await supabase.from('expense_categories').insert({
                'name': newCatName,
              });
            }
          } catch (e) {}
        }
      } else {
        if (_isIncome && finalIncomeCategoryId == -1) {
          finalIncomeCategoryId = null;
        }
        if (!_isIncome && finalExpenseCategory?.toLowerCase() == 'other') {
          finalExpenseCategory = 'Other';
        }
      }

      if (_isIncome) {
        await supabase.from('income').insert({
          'user_id': user.id,
          'source': sourceName,
          'amount': double.tryParse(amountText) ?? 0.00,
          'created_at': _selectedDate.toUtc().toIso8601String(),
          'category_id': finalIncomeCategoryId,
          'is_taxable': _isTaxable,
          'is_scanned': true,
        });
      } else {
        await supabase.from('expenses').insert({
          'user_id': user.id,
          'merchant': sourceName,
          'amount': double.tryParse(amountText) ?? 0.00,
          'created_at': _selectedDate.toUtc().toIso8601String(),
          'category': finalExpenseCategory,
          'is_scanned': true,
          'is_tax_deductible': _isTaxDeductible,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${_isIncome ? 'Income' : 'Expense'} Saved Successfully!",
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _imageFile = null;
          _webImage = null;
          _amountController.clear();
          _sourceMerchantController.clear();
          _customCategoryController.clear();
          _showCustomCategoryInput = false;
          _extractedText = "";
          _selectedDate = DateTime.now();
          _isTaxable = false;
          _isTaxDeductible = false;
        });
        _fetchCategories(isRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  void _showFullTextDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              "Raw Donut Output",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: SingleChildScrollView(
              child: SelectableText(_extractedText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
    );
  }

  void _updateCategoryToggleVisibility() {
    if (_isIncome) {
      if (_selectedIncomeCategoryId != null && _incomeCategories.isNotEmpty) {
        final catName =
            _incomeCategories
                .firstWhere(
                  (c) => c['id'] == _selectedIncomeCategoryId,
                  orElse: () => {'name': ''},
                )['name']
                .toString()
                .toLowerCase();
        _showCustomCategoryInput = catName == 'other';
      }
    } else {
      _showCustomCategoryInput =
          _selectedExpenseCategory?.toLowerCase() == 'other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final dateDisplay = DateFormat('dd MMM yyyy').format(_selectedDate);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final titleColor = isDarkMode ? Colors.white : primaryColor;
    final inputFillColor = isDarkMode ? Colors.grey[850] : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body:
          _isLoadingCategories
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : RefreshIndicator(
                color: primaryColor,
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 600));
                  await _fetchCategories(isRefresh: true);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(
                    top: 30,
                    left: 20,
                    right: 20,
                    bottom: 120,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Smart Scanner",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: inputFillColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
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
                            (_imageFile == null && _webImage == null)
                                ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.document_scanner,
                                      size: 60,
                                      color: primaryColor.withOpacity(0.4),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "Scan a receipt, payslip, or invoice",
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                                : ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child:
                                      kIsWeb
                                          ? Image.memory(
                                            _webImage!,
                                            fit: BoxFit.cover,
                                          )
                                          : Image.file(
                                            _imageFile!,
                                            fit: BoxFit.cover,
                                          ),
                                ),
                      ),
                      const SizedBox(height: 20),

                      Showcase.withWidget(
                        key: _buttonsKey,
                        width: 280,
                        height: 160,
                        targetPadding: const EdgeInsets.all(4),
                        container: _buildCustomTooltip(
                          context: context,
                          title: 'Snap a Receipt',
                          description:
                              'Use your camera to snap a live picture, or upload an existing receipt from your gallery.',
                          isLastStep: false,
                          primaryColor: primaryColor,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Camera",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  elevation: 4,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    () => _pickImage(ImageSource.gallery),
                                icon: Icon(Icons.image, color: primaryColor),
                                label: Text(
                                  "Gallery",
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isDarkMode
                                          ? Colors.grey[800]
                                          : Colors.white,
                                  elevation: 4,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      Showcase.withWidget(
                        key: _typeToggleKey,
                        width: 280,
                        height: 160,
                        targetShapeBorder: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        container: _buildCustomTooltip(
                          context: context,
                          title: 'Smart Categorization',
                          description:
                              'Our AI tries to guess if the receipt is an Income or Expense, but you can always toggle it manually here.',
                          isLastStep: true,
                          primaryColor: primaryColor,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? Colors.grey[900]
                                    : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isIncome = false;
                                      _updateCategoryToggleVisibility();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          !_isIncome
                                              ? Colors.white
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow:
                                          !_isIncome && !isDarkMode
                                              ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 4,
                                                ),
                                              ]
                                              : [],
                                    ),
                                    child: Text(
                                      "Expense",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            !_isIncome
                                                ? Colors.redAccent
                                                : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isIncome = true;
                                      _updateCategoryToggleVisibility();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _isIncome
                                              ? Colors.white
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow:
                                          _isIncome && !isDarkMode
                                              ? [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 4,
                                                ),
                                              ]
                                              : [],
                                    ),
                                    child: Text(
                                      "Income",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _isIncome
                                                ? Colors.green
                                                : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_isScanning)
                        Center(
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              CircularProgressIndicator(color: primaryColor),
                              const SizedBox(height: 15),
                              Text(
                                "Analyzing Document with AI...",
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        )
                      else if (_imageFile != null || _webImage != null) ...[
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: "Scanned Amount (RM)",
                            filled: true,
                            fillColor: inputFillColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(
                              Icons.attach_money,
                              color:
                                  _isIncome ? Colors.green : Colors.redAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        TextField(
                          controller: _sourceMerchantController,
                          decoration: InputDecoration(
                            labelText:
                                _isIncome
                                    ? "Source (e.g. Salary, Client)"
                                    : "Store / Merchant",
                            filled: true,
                            fillColor: inputFillColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: Icon(
                              _isIncome ? Icons.business : Icons.storefront,
                              color:
                                  _isIncome ? Colors.green : Colors.redAccent,
                            ),
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
                                color:
                                    _isIncome ? Colors.green : Colors.redAccent,
                              ),
                            ),
                            child: Text(
                              dateDisplay,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        if (!_isIncome)
                          DropdownButtonFormField<String>(
                            value: _selectedExpenseCategory,
                            decoration: InputDecoration(
                              labelText: "Category",
                              filled: true,
                              fillColor: inputFillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(
                                Icons.category,
                                color: Colors.redAccent,
                              ),
                            ),
                            items:
                                _expenseCategories
                                    .map(
                                      (cat) => DropdownMenuItem<String>(
                                        value: cat['name'],
                                        child: Text(cat['name']),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (val) => setState(() {
                                  _selectedExpenseCategory = val;
                                  _showCustomCategoryInput =
                                      val?.toLowerCase() == 'other';
                                }),
                          )
                        else
                          DropdownButtonFormField<int>(
                            value: _selectedIncomeCategoryId,
                            decoration: InputDecoration(
                              labelText: "Category",
                              filled: true,
                              fillColor: inputFillColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(
                                Icons.category,
                                color: Colors.green,
                              ),
                            ),
                            items:
                                _incomeCategories
                                    .map(
                                      (cat) => DropdownMenuItem<int>(
                                        value: cat['id'],
                                        child: Text(cat['name']),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (val) => setState(() {
                                  _selectedIncomeCategoryId = val;
                                  final catName =
                                      _incomeCategories
                                          .firstWhere(
                                            (c) => c['id'] == val,
                                            orElse: () => {'name': ''},
                                          )['name']
                                          .toString()
                                          .toLowerCase();
                                  _showCustomCategoryInput = catName == 'other';
                                }),
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
                              prefixIcon: Icon(
                                Icons.edit,
                                color:
                                    _isIncome ? Colors.green : Colors.redAccent,
                              ),
                            ),
                            autofocus: true,
                          ),
                        ],

                        const SizedBox(height: 15),

                        Container(
                          decoration: BoxDecoration(
                            color: inputFillColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.1),
                            ),
                          ),
                          child:
                              _isIncome
                                  ? SwitchListTile(
                                    title: const Text(
                                      "Is this income taxable?",
                                    ),
                                    subtitle: const Text(
                                      "Turn off for cash gifts, specific allowances, or non-taxable sales.",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    value: _isTaxable,
                                    activeColor: Colors.green,
                                    onChanged:
                                        (bool value) =>
                                            setState(() => _isTaxable = value),
                                  )
                                  : SwitchListTile(
                                    title: const Text(
                                      "Is this tax-deductible?",
                                    ),
                                    subtitle: const Text(
                                      "Toggle for valid LHDN medical, education, or lifestyle receipts.",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    value: _isTaxDeductible,
                                    activeColor: Colors.redAccent,
                                    onChanged:
                                        (bool value) => setState(
                                          () => _isTaxDeductible = value,
                                        ),
                                  ),
                        ),

                        const SizedBox(height: 25),

                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveRecord,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isIncome ? Colors.green : Colors.redAccent,
                              foregroundColor: Colors.white,
                              elevation: 4,
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
                                    : Text(
                                      "Save ${_isIncome ? 'Income' : 'Expense'}",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.center,
                          child: TextButton.icon(
                            onPressed: _showFullTextDialog,
                            icon: const Icon(Icons.fullscreen),
                            label: const Text("View Full Raw Text"),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),
                      Divider(color: Colors.grey.withOpacity(0.2)),
                      const SizedBox(height: 15),
                      Text(
                        _isIncome
                            ? "Recent Income Scans"
                            : "Recent Expense Scans",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 15),

                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: supabase
                            .from(_isIncome ? 'income' : 'expenses')
                            .stream(primaryKey: ['id'])
                            .eq('is_scanned', true)
                            .order('created_at', ascending: false)
                            .limit(5),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 40,
                                      color: Colors.grey.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "No recent scans yet.",
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          final records = snapshot.data!;
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: records.length,
                            itemBuilder: (context, index) {
                              final item = records[index];
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
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text("Delete Record?"),
                                        content: const Text(
                                          "Are you sure you want to remove this scan?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                            child: const Text("Cancel"),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                            child: const Text(
                                              "Delete",
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                onDismissed:
                                    (direction) => _deleteRecord(item['id']),
                                child: _buildHistoryCard(
                                  item,
                                  isDarkMode,
                                  primaryColor,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildHistoryCard(
    Map<String, dynamic> item,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final sourceOrMerchant =
        _isIncome
            ? (item['source'] ?? 'Unknown')
            : (item['merchant'] ?? 'Unknown');
    final amount = item['amount'] ?? 0.0;
    final categoryString =
        _isIncome ? "Income" : (item['category'] ?? 'General');
    final date = DateTime.parse(item['created_at']).toLocal();
    final formattedDate = DateFormat('dd MMM yyyy').format(date);

    final bool isTaxDeductible =
        !_isIncome && (item['is_tax_deductible'] == true);

    final IconData catIcon =
        _isIncome ? Icons.attach_money : _getCategoryIcon(categoryString);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                _isIncome
                    ? Colors.green.withOpacity(0.1)
                    : Colors.redAccent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            catIcon,
            color: _isIncome ? Colors.green : Colors.redAccent,
            size: 22,
          ),
        ),
        title: Text(
          sourceOrMerchant,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              formattedDate,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            if (isTaxDeductible) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 12, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      "Tax Relief Eligible",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: Text(
          "${_isIncome ? '+' : '-'}RM ${amount.toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: _isIncome ? Colors.green : Colors.redAccent,
          ),
        ),
      ),
    );
  }
}
