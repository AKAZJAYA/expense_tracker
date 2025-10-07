import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../models/recurring_bill.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/recurring_bills_processor.dart';

class RecurringBillsScreen extends StatefulWidget {
  const RecurringBillsScreen({super.key});

  @override
  State<RecurringBillsScreen> createState() => _RecurringBillsScreenState();
}

class _RecurringBillsScreenState extends State<RecurringBillsScreen> {
  List<RecurringBill> _bills = [];
  Map<int, Category> _categories = {};
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkAndProcessDueBills();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseService.instance;
    final bills = await db.getRecurringBills();
    final categories = await db.getCategories();
    
    setState(() {
      _bills = bills;
      _categories = {for (var cat in categories) cat.id!: cat};
      _isLoading = false;
    });
  }

  Future<void> _checkAndProcessDueBills() async {
    final processor = RecurringBillsProcessor.instance;
    final hasDue = await processor.hasDueBills();

    if (hasDue && mounted) {
      final count = await processor.getDueBillsCount();
      _showProcessBillsDialog(count);
    }
  }

  Future<void> _showProcessBillsDialog(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Process Due Bills'),
        content: Text(
          'You have $count recurring bill${count == 1 ? '' : 's'} due. Would you like to process ${count == 1 ? 'it' : 'them'} now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Process Now'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processAllDueBills();
    }
  }

  Future<void> _processAllDueBills() async {
    setState(() => _isProcessing = true);

    try {
      final processor = RecurringBillsProcessor.instance;
      final processedBills = await processor.processDueBills();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Processed ${processedBills.length} recurring bill${processedBills.length == 1 ? '' : 's'}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing bills: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processSpecificBill(RecurringBill bill) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Process Bill Now'),
        content: Text(
          'Create a transaction for "${bill.name}" (${NumberFormat.currency(symbol: '\$').format(bill.amount)})?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Process'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);

      try {
        final processor = RecurringBillsProcessor.instance;
        final success = await processor.processSpecificBill(bill);

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Transaction created for ${bill.name}'),
                duration: const Duration(seconds: 2),
              ),
            );
            _loadData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bill has ended and cannot be processed'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing bill: $e')),
          );
        }
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Bills'),
        actions: [
          if (_bills.isNotEmpty)
            IconButton(
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync),
              onPressed: _isProcessing ? null : _processAllDueBills,
              tooltip: 'Process Due Bills',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _bills.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bills.length,
                  itemBuilder: (context, index) {
                    final bill = _bills[index];
                    final category = _categories[bill.categoryId];
                    return _buildBillCard(bill, category);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBillDialog,
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
            Icons.repeat_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No recurring bills',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add bills that repeat regularly',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(RecurringBill bill, Category? category) {
    final processor = RecurringBillsProcessor.instance;
    final dueDescription = processor.getNextDueDescription(bill);
    final isOverdue = dueDescription.startsWith('Overdue');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category?.color.withOpacity(0.2),
          child: Icon(category?.icon ?? Icons.help_outline, color: category?.color),
        ),
        title: Text(bill.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${category?.name ?? 'Unknown'} • ${_capitalizeFirst(bill.frequency)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dueDescription,
                style: TextStyle(
                  fontSize: 11,
                  color: isOverdue ? Colors.red : Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.currency(symbol: '\$').format(bill.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'process') {
                  _processSpecificBill(bill);
                } else if (value == 'delete') {
                  _deleteBill(bill);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'process',
                  child: Row(
                    children: [
                      Icon(Icons.payment, size: 20),
                      SizedBox(width: 8),
                      Text('Process Now'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // ...existing code for _showAddBillDialog and _deleteBill...
  Future<void> _showAddBillDialog() async {
    final categories = await DatabaseService.instance.getCategories(type: 'expense');
    if (!mounted) return;
    
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expense categories available')),
      );
      return;
    }

    int? selectedCategoryId = categories.first.id;
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String selectedFrequency = 'monthly';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Recurring Bill'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Bill Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 16),
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
                    setDialogState(() => selectedCategoryId = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedFrequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'biweekly', child: Text('Bi-weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedFrequency = value!);
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
              onPressed: () {
                if (nameController.text.isEmpty || amountController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedCategoryId != null && 
        nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
      final amount = double.tryParse(amountController.text);
      if (amount == null || amount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')),
        );
        return;
      }

      final bill = RecurringBill(
        name: nameController.text,
        amount: amount,
        categoryId: selectedCategoryId!,
        frequency: selectedFrequency,
        startDate: DateTime.now(),
      );
      await DatabaseService.instance.createRecurringBill(bill);
      if (!mounted) return;
      _loadData();
    }
  }

  Future<void> _deleteBill(RecurringBill bill) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Bill'),
        content: const Text('Are you sure you want to delete this recurring bill?'),
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
      await DatabaseService.instance.deleteRecurringBill(bill.id!);
      if (!mounted) return;
      _loadData();
    }
  }
}