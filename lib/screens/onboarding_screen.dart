import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'home_screen.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../models/category.dart';
import '../providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // User selections
  String _selectedCurrency = '\$';
  Set<String> _selectedExpenseCategories = {};
  Set<String> _selectedIncomeCategories = {};
  bool _importingData = false;

  // Default categories
  final List<Map<String, dynamic>> _defaultExpenseCategories = [
    {'name': 'Food & Dining', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'name': 'Transportation', 'icon': Icons.directions_car, 'color': Colors.blue},
    {'name': 'Shopping', 'icon': Icons.shopping_bag, 'color': Colors.purple},
    {'name': 'Entertainment', 'icon': Icons.movie, 'color': Colors.pink},
    {'name': 'Bills & Utilities', 'icon': Icons.receipt, 'color': Colors.red},
    {'name': 'Healthcare', 'icon': Icons.local_hospital, 'color': Colors.green},
    {'name': 'Groceries', 'icon': Icons.local_grocery_store, 'color': Colors.teal},
    {'name': 'Gas & Fuel', 'icon': Icons.local_gas_station, 'color': Colors.amber},
  ];

  final List<Map<String, dynamic>> _defaultIncomeCategories = [
    {'name': 'Salary', 'icon': Icons.work, 'color': Colors.green},
    {'name': 'Business', 'icon': Icons.business, 'color': Colors.blue},
    {'name': 'Investments', 'icon': Icons.trending_up, 'color': Colors.purple},
    {'name': 'Freelance', 'icon': Icons.laptop, 'color': Colors.orange},
  ];

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Say hi to your new\nfinance tracker',
      description:
          'You\'re amazing for taking this first step towards getting better control over your money and financial goals.',
      illustration: OnboardingIllustration.welcome,
      buttonText: 'GET STARTED',
    ),
    OnboardingData(
      title: 'Choose your currency',
      description: 'Select the currency you\'ll be using for tracking your expenses.',
      illustration: OnboardingIllustration.currency,
      buttonText: 'CONTINUE',
    ),
    OnboardingData(
      title: 'Select expense categories',
      description: 'Choose the categories you want to track. You can add more later.',
      illustration: OnboardingIllustration.categories,
      buttonText: 'CONTINUE',
    ),
    OnboardingData(
      title: 'Select income sources',
      description: 'Choose your income categories. These help track where money comes from.',
      illustration: OnboardingIllustration.income,
      buttonText: 'CONTINUE',
    ),
    OnboardingData(
      title: 'Import existing data?',
      description: 'If you have transaction data from another app, you can import it now.',
      illustration: OnboardingIllustration.import,
      buttonText: 'SKIP',
    ),
    OnboardingData(
      title: 'Together we\'ll reach your\nfinancial goals',
      description:
          'If you fail to plan, you plan to fail. WalletFlow will help you stay focused on tracking your spend and reach your financial goals.',
      illustration: OnboardingIllustration.goals,
      buttonText: 'LET\'S START',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Select all categories by default
    _selectedExpenseCategories = _defaultExpenseCategories.map((c) => c['name'] as String).toSet();
    _selectedIncomeCategories = _defaultIncomeCategories.map((c) => c['name'] as String).toSet();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _onButtonPressed() async {
    if (_currentPage < _pages.length - 1) {
      // Validation for category pages
      if (_currentPage == 2 && _selectedExpenseCategories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one expense category')),
        );
        return;
      }
      if (_currentPage == 3 && _selectedIncomeCategories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one income category')),
        );
        return;
      }
      
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    
    // Save currency preference
    await settings.setCurrencySymbol(_selectedCurrency);
    
    // Create selected categories
    await _createCategories();
    
    // Mark onboarding as completed
    await prefs.setBool('isFirstLaunch', false);
    await prefs.setBool('tutorial_shown', false); // Enable tutorial on first app use
    
    // Navigate to home screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _createCategories() async {
    final db = DatabaseService.instance;
    
    // Create expense categories
    for (var categoryData in _defaultExpenseCategories) {
      if (_selectedExpenseCategories.contains(categoryData['name'])) {
        final category = Category(
          name: categoryData['name'] as String,
          type: 'expense',
          colorValue: (categoryData['color'] as Color).value,
          iconCodePoint: (categoryData['icon'] as IconData).codePoint,
        );
        await db.createCategory(category);
      }
    }
    
    // Create income categories
    for (var categoryData in _defaultIncomeCategories) {
      if (_selectedIncomeCategories.contains(categoryData['name'])) {
        final category = Category(
          name: categoryData['name'] as String,
          type: 'income',
          colorValue: (categoryData['color'] as Color).value,
          iconCodePoint: (categoryData['icon'] as IconData).codePoint,
        );
        await db.createCategory(category);
      }
    }
  }

  Future<void> _skipOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Setup?'),
        content: const Text(
          'You can always customize categories and settings later from the Settings screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SKIP'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Use default settings and create all default categories
      _selectedExpenseCategories = _defaultExpenseCategories.map((c) => c['name'] as String).toSet();
      _selectedIncomeCategories = _defaultIncomeCategories.map((c) => c['name'] as String).toSet();
      await _completeOnboarding();
    }
  }

  Future<void> _importData() async {
    setState(() => _importingData = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _importingData = false);
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        throw Exception('Invalid file path');
      }

      // Show progress dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Importing data...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );

      final importResult = await ExportService.restoreFromBackup(
        filePath: filePath,
        clearExisting: false,
        onProgress: (current, total) {},
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(importResult.success ? 'Import Complete' : 'Import Failed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (importResult.success) ...[
                  Text('✅ Imported: ${importResult.imported} transactions'),
                  if (importResult.skipped > 0)
                    Text('⏭️ Skipped: ${importResult.skipped} (duplicates)'),
                  if (importResult.errors > 0)
                    Text('❌ Errors: ${importResult.errors}'),
                ] else
                  Text(importResult.message),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    } finally {
      setState(() => _importingData = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF63B4A0),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with skip button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                      Text(
                        'App Store',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (_currentPage > 0 && _currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        'SKIP',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], index);
                },
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildDot(index),
                ),
              ),
            ),

            // Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _importingData ? null : _onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF63B4A0),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: _importingData
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _pages[_currentPage].buttonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingData data, int pageIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Illustration or interactive content
          _buildPageContent(data.illustration, pageIndex),

          const SizedBox(height: 60),

          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPageContent(OnboardingIllustration type, int pageIndex) {
    switch (type) {
      case OnboardingIllustration.welcome:
        return _buildWelcomeIllustration();
      case OnboardingIllustration.currency:
        return _buildCurrencySelector();
      case OnboardingIllustration.categories:
        return _buildCategorySelector(true);
      case OnboardingIllustration.income:
        return _buildCategorySelector(false);
      case OnboardingIllustration.import:
        return _buildImportOptions();
      case OnboardingIllustration.goals:
        return _buildGoalsIllustration();
      default:
        return const SizedBox();
    }
  }

  Widget _buildCurrencySelector() {
    final currencies = [
      {'symbol': '\$', 'name': 'US Dollar', 'code': 'USD'},
      {'symbol': '€', 'name': 'Euro', 'code': 'EUR'},
      {'symbol': '£', 'name': 'British Pound', 'code': 'GBP'},
      {'symbol': '¥', 'name': 'Japanese Yen', 'code': 'JPY'},
      {'symbol': '₹', 'name': 'Indian Rupee', 'code': 'INR'},
      {'symbol': '₽', 'name': 'Russian Ruble', 'code': 'RUB'},
      {'symbol': 'R\$', 'name': 'Brazilian Real', 'code': 'BRL'},
      {'symbol': 'C\$', 'name': 'Canadian Dollar', 'code': 'CAD'},
      {'symbol': 'A\$', 'name': 'Australian Dollar', 'code': 'AUD'},
    ];

    return Container(
      height: 300,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: currencies.length,
        shrinkWrap: true,
        itemBuilder: (context, index) {
          final currency = currencies[index];
          final isSelected = _selectedCurrency == currency['symbol'];
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCurrency = currency['symbol'] as String;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currency['symbol'] as String,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF63B4A0) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currency['code'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? const Color(0xFF63B4A0) : Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySelector(bool isExpense) {
    final categories = isExpense ? _defaultExpenseCategories : _defaultIncomeCategories;
    final selectedCategories = isExpense ? _selectedExpenseCategories : _selectedIncomeCategories;

    return Container(
      height: 320,
      child: Column(
        children: [
          // Select/Deselect all button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  if (selectedCategories.length == categories.length) {
                    selectedCategories.clear();
                  } else {
                    selectedCategories.addAll(categories.map((c) => c['name'] as String));
                  }
                });
              },
              icon: Icon(
                selectedCategories.length == categories.length
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: Colors.white,
              ),
              label: Text(
                selectedCategories.length == categories.length ? 'Deselect All' : 'Select All',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: categories.length,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final category = categories[index];
                final categoryName = category['name'] as String;
                final isSelected = selectedCategories.contains(categoryName);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedCategories.remove(categoryName);
                      } else {
                        selectedCategories.add(categoryName);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          category['icon'] as IconData,
                          color: isSelected
                              ? (category['color'] as Color)
                              : Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            categoryName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF63B4A0)
                                  : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF63B4A0),
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportOptions() {
    return Container(
      height: 300,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.9),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _importData,
            icon: const Icon(Icons.file_upload),
            label: const Text('IMPORT CSV FILE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF63B4A0),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'or skip to start fresh',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Keep existing illustration methods
  Widget _buildWelcomeIllustration() {
    return Container(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xFF4A9985),
              shape: BoxShape.circle,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF2C5F6F),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              Container(
                width: 140,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF2C3E50),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(70),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 20,
            top: 100,
            child: Transform.rotate(
              angle: -0.3,
              child: Container(
                width: 60,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A7C8F),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 100,
            child: Transform.rotate(
              angle: 0.3,
              child: Container(
                width: 60,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A7C8F),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            left: 40,
            bottom: 40,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A7C59),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(40),
                    ),
                  ),
                ),
                Container(
                  width: 50,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsIllustration() {
    return Container(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomPaint(
                  size: const Size(120, 100),
                  painter: MountainPainter(const Color(0xFF5A8B7C)),
                ),
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    CustomPaint(
                      size: const Size(150, 130),
                      painter: MountainPainter(const Color(0xFF4A7C6D)),
                    ),
                    Positioned(
                      top: 0,
                      child: Container(
                        width: 100,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(50),
                            topRight: Radius.circular(50),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 35,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2C5F6F),
                                  borderRadius: BorderRadius.all(Radius.circular(3)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 8,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2C5F6F),
                                  borderRadius: BorderRadius.all(Radius.circular(3)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 30,
                            height: 15,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFF2C5F6F),
                                  width: 3,
                                ),
                              ),
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -10,
                      child: Container(
                        width: 3,
                        height: 60,
                        color: const Color(0xFF5A7C8F),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      left: 78,
                      child: ClipPath(
                        clipper: FlagClipper(),
                        child: Container(
                          width: 30,
                          height: 25,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 30,
            top: 80,
            child: _buildCloud(60, 35),
          ),
          Positioned(
            right: 150,
            top: 100,
            child: _buildCloud(70, 40),
          ),
          Positioned(
            bottom: 40,
            child: Container(
              width: 300,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF4A9985).withOpacity(0.2),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloud(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(50),
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? Colors.white
            : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class MountainPainter extends CustomPainter {
  final Color color;

  MountainPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FlagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class OnboardingData {
  final String title;
  final String description;
  final OnboardingIllustration illustration;
  final String buttonText;

  OnboardingData({
    required this.title,
    required this.description,
    required this.illustration,
    required this.buttonText,
  });
}

enum OnboardingIllustration {
  welcome,
  currency,
  categories,
  income,
  import,
  goals,
}