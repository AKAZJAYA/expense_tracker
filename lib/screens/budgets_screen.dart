import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/budget.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/budget_monitor_service.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<Budget> _budgets = [];
  Map<int, Category> _categories = {};
  Map<int, double> _spending = {};
  Map<int, BudgetAlert?> _alerts = {};
  bool _isLoading = true;

  // Search properties
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  List<Budget> get _filteredBudgets {
    if (_searchQuery.isEmpty) {
      return _budgets;
    }

    return _budgets.where((budget) {
      final category = _categories[budget.categoryId];
      final categoryName = category?.name.toLowerCase() ?? '';
      final period = budget.period.toLowerCase();

      return categoryName.contains(_searchQuery) ||
          period.contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final db = DatabaseService.instance;
      final budgets = await db.getBudgets();
      final categories = await db.getCategories();

      Map<int, double> spending = {};
      Map<int, BudgetAlert?> alerts = {};

      for (var budget in budgets) {
        final startDate = budget.startDate;
        final endDate = budget.endDate ?? DateTime.now();
        final total =
            await db.getTotalByCategory(budget.categoryId, startDate, endDate);
        spending[budget.categoryId] = total;

        // Check alert status
        final allAlerts = await BudgetMonitorService.instance.checkBudgets();
        alerts[budget.id ?? 0] = allAlerts.firstWhere(
          (a) => a.budget.id == budget.id,
          orElse: () => BudgetAlert(
            budget: budget,
            category: null,
            spent: 0,
            percentage: 0,
            level: AlertLevel.warning,
            message: '',
          ),
        );
      }

      if (mounted) {
        setState(() {
          _budgets = budgets;
          _categories = {for (var cat in categories) cat.id!: cat};
          _spending = spending;
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading budgets: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search budgets...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                ),
              )
            : const Text('Budgets'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _filteredBudgets.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredBudgets.length,
                  itemBuilder: (context, index) {
                    final budget = _filteredBudgets[index];
                    final category = _categories[budget.categoryId];
                    final spent = _spending[budget.categoryId] ?? 0.0;
                    return _buildBudgetCard(budget, category, spent);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBudgetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.savings_outlined : Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No budgets yet' : 'No results found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Create a budget to track your spending'
                : 'Try adjusting your search terms',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetCard(Budget budget, Category? category, double spent) {
    final percentage = (spent / budget.amount * 100).clamp(0, 100);
    final isOverBudget = spent > budget.amount;
    final alert = _alerts[budget.id];
    final hasAlert = alert != null && alert.percentage >= 80;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: category?.color.withOpacity(0.2),
                      child: Icon(category?.icon ?? Icons.help_outline,
                          color: category?.color),
                    ),
                    if (hasAlert)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: BudgetMonitorService.instance
                                .getAlertColor(alert.level),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.name ?? 'Unknown',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        budget.period,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (hasAlert)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: BudgetMonitorService.instance
                          .getAlertColor(alert.level)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${alert.percentage}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: BudgetMonitorService.instance
                            .getAlertColor(alert.level),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteBudget(budget),
                ),
              ],
            ),
            if (hasAlert) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BudgetMonitorService.instance
                      .getAlertColor(alert.level)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: BudgetMonitorService.instance
                        .getAlertColor(alert.level)
                        .withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: BudgetMonitorService.instance
                          .getAlertColor(alert.level),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: BudgetMonitorService.instance
                              .getAlertColor(alert.level),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spent: ${NumberFormat.currency(symbol: '\$').format(spent)}',
                  style: TextStyle(
                    color: isOverBudget ? Colors.red : Colors.grey[700],
                  ),
                ),
                Text(
                  'of ${NumberFormat.currency(symbol: '\$').format(budget.amount)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverBudget
                      ? Colors.red
                      : (percentage > 80 ? Colors.orange : Colors.green),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${percentage.toStringAsFixed(1)}% used',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  '${NumberFormat.currency(symbol: '\$').format(budget.amount - spent)} remaining',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddBudgetDialog() async {
    final categories =
        await DatabaseService.instance.getCategories(type: 'expense');
    if (!mounted) return;

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expense categories available')),
      );
      return;
    }

    int? selectedCategoryId = categories.first.id;
    final amountController = TextEditingController();
    String selectedPeriod = 'monthly';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Budget'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat.id,
                      child: Row(
                        children: [
                          Icon(cat.icon, color: cat.color, size: 20),
                          const SizedBox(width: 8),
                          Text(cat.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedCategoryId = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Budget Amount',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPeriod,
                  decoration: const InputDecoration(labelText: 'Period'),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedPeriod = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true &&
        selectedCategoryId != null &&
        amountController.text.isNotEmpty) {
      try {
        final amount = double.parse(amountController.text);
        final budget = Budget(
          categoryId: selectedCategoryId!,
          amount: amount,
          period: selectedPeriod,
          startDate: DateTime.now(),
        );
        await DatabaseService.instance.createBudget(budget);
        if (mounted) {
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating budget: $e')),
          );
        }
      }
    }

    amountController.dispose();
  }

  Future<void> _deleteBudget(Budget budget) async {
    if (budget.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete budget without ID')),
      );
      return;
    }

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Budget'),
        content: const Text('Are you sure you want to delete this budget?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService.instance.deleteBudget(budget.id!);
        if (mounted) {
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting budget: $e')),
          );
        }
      }
    }
  }
}
