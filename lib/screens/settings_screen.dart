import 'dart:io';
import 'package:expense_tracker/services/tutorial_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../models/category.dart';
import '../providers/theme_provider.dart';
import '../providers/app_settings_provider.dart';
import 'categories_screen.dart';
import 'recurring_bills_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _carryOverEnabled = false;
  bool _notificationsEnabled = true;
  bool _isLoading = false;
  List<Category> _categories = [];

  // Budget alert settings
  bool _budgetAlertsEnabled = true;
  String _alertFrequency = 'immediate';
  int _threshold80 = 80;
  int _threshold100 = 100;
  int _threshold120 = 120;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCategories();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _carryOverEnabled = prefs.getBool('carry_over_enabled') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _budgetAlertsEnabled = prefs.getBool('budget_alerts_enabled') ?? true;
      _alertFrequency = prefs.getString('alert_frequency') ?? 'immediate';
      _threshold80 = prefs.getInt('alert_threshold_80') ?? 80;
      _threshold100 = prefs.getInt('alert_threshold_100') ?? 100;
      _threshold120 = prefs.getInt('alert_threshold_120') ?? 120;
    });
  }

  Future<void> _loadCategories() async {
    final categories = await DatabaseService.instance.getCategories();
    setState(() {
      _categories = categories;
    });
  }

  Future<void> _toggleCarryOver(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('carry_over_enabled', value);
    setState(() {
      _carryOverEnabled = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'Balance carry-over enabled'
              : 'Balance carry-over disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showThemeDialog(ThemeProvider themeProvider) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Light'),
              value: 'Light',
              groupValue: themeProvider.themeModeName,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              title: const Text('Dark'),
              value: 'Dark',
              groupValue: themeProvider.themeModeName,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              title: const Text('System'),
              value: 'System',
              groupValue: themeProvider.themeModeName,
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await themeProvider.setThemeMode(result);
    }
  }

  Future<void> _showNotificationsDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Notifications'),
              value: _notificationsEnabled,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            const SizedBox(height: 8),
            Text(
              'Get notified about budget limits and recurring bills',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', result);
      setState(() {
        _notificationsEnabled = result;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                result ? 'Notifications enabled' : 'Notifications disabled'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _backupData() async {
    setState(() => _isLoading = true);

    try {
      final transactions = await DatabaseService.instance.getAllTransactions();
      final categories = await DatabaseService.instance.getCategories();

      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to backup')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final path = await ExportService.exportToCSV(transactions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup created successfully at: $path'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportData() async {
    // Show format selection dialog
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF Report'),
              subtitle: const Text('Formatted document'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('CSV Spreadsheet'),
              subtitle: const Text('Import to Excel'),
              onTap: () => Navigator.pop(context, 'csv'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (format == null) return;

    setState(() => _isLoading = true);

    try {
      final transactions = await DatabaseService.instance.getAllTransactions();

      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No transactions to export')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      String? path;
      if (format == 'pdf') {
        path = await ExportService.exportToPDF(transactions);

        if (path != null && mounted) {
          // Show share dialog for PDF
          final file = File(path);
          await Printing.sharePdf(
            bytes: await file.readAsBytes(),
            filename: path.split('/').last,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF exported successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        path = await ExportService.exportToCSV(transactions);

        if (mounted && path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV saved to: $path'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text(
          'Select a CSV file to import. Duplicate transactions will be skipped automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Select File'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ImportProgressDialog(),
    );

    try {
      final result = await ExportService.importFromCSV(
        onProgress: (current, total) {
          // Update progress if needed
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        // Show result dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.success ? 'Import Complete' : 'Import Failed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.success) ...[
                  Text('✅ Imported: ${result.imported} transactions'),
                  if (result.skipped > 0)
                    Text('⏭️ Skipped: ${result.skipped} (duplicates)'),
                  if (result.errors > 0) Text('❌ Errors: ${result.errors}'),
                ] else
                  Text(result.message),
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
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }

  Future<void> _restoreFromBackup() async {
    setState(() => _isLoading = true);

    try {
      final backupFiles = await ExportService.getBackupFiles();

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (backupFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No backup files found')),
          );
        }
        return;
      }

      // Show backup selection dialog
      if (!mounted) return;

      final selectedBackup = await showDialog<BackupFile>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Backup'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backupFiles.length,
              itemBuilder: (context, index) {
                final backup = backupFiles[index];
                return ListTile(
                  leading: const Icon(Icons.backup, color: Colors.blue),
                  title: Text(
                    DateFormat('MMM d, yyyy h:mm a').format(backup.modified),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(backup.formattedSize),
                  onTap: () => Navigator.pop(context, backup),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedBackup == null) return;

      // Show restore options dialog
      if (!mounted) return;

      final clearExisting = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Options'),
          content: const Text(
            'Do you want to replace existing data or merge with current transactions?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Merge'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Replace All'),
            ),
          ],
        ),
      );

      if (clearExisting == null) return;

      // Show progress dialog
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ImportProgressDialog(),
      );

      final result = await ExportService.restoreFromBackup(
        filePath: selectedBackup.path,
        clearExisting: clearExisting,
        onProgress: (current, total) {
          // Update progress if needed
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog

        // Show result dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.success ? 'Restore Complete' : 'Restore Failed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.success) ...[
                  Text('✅ Restored: ${result.imported} transactions'),
                  if (result.skipped > 0 && !clearExisting)
                    Text('⏭️ Skipped: ${result.skipped} (duplicates)'),
                  if (result.errors > 0) Text('❌ Errors: ${result.errors}'),
                ] else
                  Text(result.message),
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
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore error: $e')),
        );
      }
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all transactions, budgets, and recurring bills. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        // Delete all transactions
        final transactions =
            await DatabaseService.instance.getAllTransactions();
        for (var transaction in transactions) {
          await DatabaseService.instance.deleteTransaction(transaction.id!);
        }

        // Delete all budgets
        final budgets = await DatabaseService.instance.getBudgets();
        for (var budget in budgets) {
          await DatabaseService.instance.deleteBudget(budget.id!);
        }

        // Delete all recurring bills
        final bills = await DatabaseService.instance.getRecurringBills();
        for (var bill in bills) {
          await DatabaseService.instance.deleteRecurringBill(bill.id!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All data cleared successfully'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing data: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAboutDialog() async {
    showAboutDialog(
      context: context,
      applicationName: 'WalletFlow',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/logo/app_logo.png',
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
      ),
      children: [
        const SizedBox(height: 16),
        const Text(
          'A simple and elegant expense tracking app to help you manage your finances.',
        ),
        const SizedBox(height: 16),
        Text(
          'Features:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        const Text('• Track income and expenses'),
        const Text('• Category-based organization'),
        const Text('• Budget management'),
        const Text('• Recurring bills tracking'),
        const Text('• Statistics and charts'),
        const Text('• CSV export'),
        const Text('• Receipt photo capture'),
        const SizedBox(height: 16),
        const Text(
          '© 2024 WalletFlow\nAll rights reserved.',
          style: TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _showBudgetAlertsDialog() async {
    final prefs = await SharedPreferences.getInstance();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Budget Alert Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Budget Alerts'),
                  value: _budgetAlertsEnabled,
                  onChanged: (value) async {
                    await prefs.setBool('budget_alerts_enabled', value);
                    setDialogState(() => _budgetAlertsEnabled = value);
                    setState(() {});
                  },
                ),
                const Divider(),
                const Text(
                  'Alert Frequency',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Immediate'),
                  subtitle: const Text('Alert as soon as threshold is reached'),
                  value: 'immediate',
                  groupValue: _alertFrequency,
                  onChanged: (value) async {
                    await prefs.setString('alert_frequency', value!);
                    setDialogState(() => _alertFrequency = value);
                    setState(() {});
                  },
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily Summary'),
                  subtitle: const Text('One notification per day'),
                  value: 'daily',
                  groupValue: _alertFrequency,
                  onChanged: (value) async {
                    await prefs.setString('alert_frequency', value!);
                    setDialogState(() => _alertFrequency = value);
                    setState(() {});
                  },
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Weekly Summary'),
                  subtitle: const Text('One notification per week'),
                  value: 'weekly',
                  groupValue: _alertFrequency,
                  onChanged: (value) async {
                    await prefs.setString('alert_frequency', value!);
                    setDialogState(() => _alertFrequency = value);
                    setState(() {});
                  },
                ),
                const Divider(),
                const Text(
                  'Alert Thresholds (%)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildThresholdSlider(
                  'Warning',
                  _threshold80,
                  Colors.orange,
                  (value) async {
                    await prefs.setInt('alert_threshold_80', value);
                    setDialogState(() => _threshold80 = value);
                    setState(() {});
                  },
                ),
                _buildThresholdSlider(
                  'Danger',
                  _threshold100,
                  Colors.red,
                  (value) async {
                    await prefs.setInt('alert_threshold_100', value);
                    setDialogState(() => _threshold100 = value);
                    setState(() {});
                  },
                ),
                _buildThresholdSlider(
                  'Critical',
                  _threshold120,
                  Colors.red.shade900,
                  (value) async {
                    await prefs.setInt('alert_threshold_120', value);
                    setDialogState(() => _threshold120 = value);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdSlider(
    String label,
    int value,
    Color color,
    Function(int) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$value%',
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 50,
          max: 150,
          divisions: 20,
          activeColor: color,
          onChanged: (val) => onChanged(val.round()),
        ),
      ],
    );
  }

  Future<void> _showDefaultCategoryDialog(String type) async {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    final filteredCategories =
        _categories.where((c) => c.type == type).toList();

    if (filteredCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No $type categories available')),
      );
      return;
    }

    final currentDefault = type == 'expense'
        ? settings.defaultExpenseCategoryId
        : settings.defaultIncomeCategoryId;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            'Default ${type == 'expense' ? 'Expense' : 'Income'} Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('None'),
              leading: Radio<int?>(
                value: null,
                groupValue: currentDefault,
                onChanged: (value) async {
                  if (type == 'expense') {
                    await settings.setDefaultExpenseCategory(null);
                  } else {
                    await settings.setDefaultIncomeCategory(null);
                  }
                  if (mounted) Navigator.pop(context);
                },
              ),
            ),
            ...filteredCategories.map((category) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(category.name),
                  leading: Radio<int?>(
                    value: category.id,
                    groupValue: currentDefault,
                    onChanged: (value) async {
                      if (type == 'expense') {
                        await settings.setDefaultExpenseCategory(value);
                      } else {
                        await settings.setDefaultIncomeCategory(value);
                      }
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                  trailing: Icon(
                    category.icon,
                    color: category.color,
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _showCurrencyDialog() async {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    String? selectedSymbol = settings.currencySymbol;

    final currencies = [
      '\$',
      '€',
      '£',
      '¥',
      '₹',
      '₽',
      'R\$',
      'C\$',
      'A\$',
      'Rs'
    ];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: currencies
              .map((symbol) => RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('$symbol - ${_getCurrencyName(symbol)}'),
                    value: symbol,
                    groupValue: selectedSymbol,
                    onChanged: (value) async {
                      await settings.setCurrencySymbol(value!);
                      if (mounted) Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  String _getCurrencyName(String symbol) {
    switch (symbol) {
      case '\$':
        return 'US Dollar';
      case '€':
        return 'Euro';
      case '£':
        return 'British Pound';
      case '¥':
        return 'Japanese Yen / Chinese Yuan';
      case '₹':
        return 'Indian Rupee';
      case '₽':
        return 'Russian Ruble';
      case 'R\$':
        return 'Brazilian Real';
      case 'C\$':
        return 'Canadian Dollar';
      case 'A\$':
        return 'Australian Dollar';
      default:
        return 'Sri Lankan Rupee';
    }
  }

  Future<void> _showNumberFormatDialog() async {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Number Format'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Decimal Separator:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Radio<String>(
                    value: '.',
                    groupValue: settings.decimalSeparator,
                    onChanged: (value) async {
                      await settings.setDecimalSeparator(value!);
                      setDialogState(() {});
                    },
                  ),
                  const Text('Period (.)'),
                ],
              ),
              Row(
                children: [
                  Radio<String>(
                    value: ',',
                    groupValue: settings.decimalSeparator,
                    onChanged: (value) async {
                      await settings.setDecimalSeparator(value!);
                      setDialogState(() {});
                    },
                  ),
                  const Text('Comma (,)'),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Thousands Separator:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Radio<String>(
                    value: ',',
                    groupValue: settings.thousandsSeparator,
                    onChanged: (value) async {
                      await settings.setThousandsSeparator(value!);
                      setDialogState(() {});
                    },
                  ),
                  const Text('Comma (,)'),
                ],
              ),
              Row(
                children: [
                  Radio<String>(
                    value: '.',
                    groupValue: settings.thousandsSeparator,
                    onChanged: (value) async {
                      await settings.setThousandsSeparator(value!);
                      setDialogState(() {});
                    },
                  ),
                  const Text('Period (.)'),
                ],
              ),
              Row(
                children: [
                  Radio<String>(
                    value: ' ',
                    groupValue: settings.thousandsSeparator,
                    onChanged: (value) async {
                      await settings.setThousandsSeparator(value!);
                      setDialogState(() {});
                    },
                  ),
                  const Text('Space ( )'),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Example: ${settings.formatCurrency(1234567.89)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateFormatDialog() async {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);

    final formats = [
      'MM/dd/yyyy',
      'dd/MM/yyyy',
      'yyyy-MM-dd',
    ];

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Date Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...formats.map((format) => RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('$format - ${_formatDateExample(format)}'),
                  value: format,
                  groupValue: settings.dateFormat,
                  onChanged: (value) async {
                    await settings.setDateFormat(value!);
                    if (mounted) Navigator.pop(context);
                  },
                )),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('24-Hour Time'),
              subtitle: Text(settings.use24HourTime ? '14:30' : '2:30 PM'),
              value: settings.use24HourTime,
              onChanged: (value) async {
                await settings.set24HourTime(value);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateExample(String format) {
    final now = DateTime.now();
    switch (format) {
      case 'dd/MM/yyyy':
        return DateFormat('dd/MM/yyyy').format(now);
      case 'yyyy-MM-dd':
        return DateFormat('yyyy-MM-dd').format(now);
      default:
        return DateFormat('MM/dd/yyyy').format(now);
    }
  }

  Future<void> _showResetDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will reset all settings to their default values. Your transactions and categories will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final settings = Provider.of<AppSettingsProvider>(context, listen: false);
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();

      await settings.resetToDefaults();
      await themeProvider.setThemeMode('System');
      await prefs.setBool('carry_over_enabled', false);
      await prefs.setBool('notifications_enabled', true);
      await prefs.setBool('budget_alerts_enabled', true);
      await prefs.setString('alert_frequency', 'immediate');
      await prefs.setInt('alert_threshold_80', 80);
      await prefs.setInt('alert_threshold_100', 100);
      await prefs.setInt('alert_threshold_120', 120);

      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to defaults'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showTutorialAgain() async {
    await TutorialService.instance.resetTutorials();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tutorial will show again on next app launch'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    final themeProvider = Provider.of<ThemeProvider>(context);
    final settings = Provider.of<AppSettingsProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsSection(
            title: 'Appearance',
            children: [
              _buildSettingsTile(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: themeProvider.themeModeName,
                onTap: () => _showThemeDialog(themeProvider),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            title: 'Defaults',
            children: [
              _buildSettingsTile(
                icon: Icons.category_outlined,
                title: 'Default Expense Category',
                subtitle:
                    _getDefaultCategoryName(settings.defaultExpenseCategoryId),
                onTap: () => _showDefaultCategoryDialog('expense'),
              ),
              _buildSettingsTile(
                icon: Icons.category_outlined,
                title: 'Default Income Category',
                subtitle:
                    _getDefaultCategoryName(settings.defaultIncomeCategoryId),
                onTap: () => _showDefaultCategoryDialog('income'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            title: 'Formats',
            children: [
              _buildSettingsTile(
                icon: Icons.attach_money,
                title: 'Currency',
                subtitle:
                    '${settings.currencySymbol} - ${_getCurrencyName(settings.currencySymbol)}',
                onTap: _showCurrencyDialog,
              ),
              _buildSettingsTile(
                icon: Icons.numbers,
                title: 'Number Format',
                subtitle: settings.formatCurrency(1234.56),
                onTap: _showNumberFormatDialog,
              ),
              _buildSettingsTile(
                icon: Icons.calendar_today,
                title: 'Date & Time Format',
                subtitle:
                    '${settings.formatDate(DateTime.now())} ${settings.formatTime(DateTime.now())}',
                onTap: _showDateFormatDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            title: 'Transactions',
            children: [
              _buildToggleTile(
                icon: Icons.compare_arrows,
                title: 'Daily Balance Carry Over',
                subtitle: 'Transfer remaining balance to next day',
                value: _carryOverEnabled,
                onChanged: _toggleCarryOver,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            title: 'General',
            children: [
              _buildSettingsTile(
                icon: Icons.category_outlined,
                title: 'Manage Categories',
                subtitle: 'Add, edit, or delete categories',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoriesScreen(),
                    ),
                  ).then((_) => _loadCategories());
                },
              ),
              _buildSettingsTile(
                icon: Icons.repeat_outlined,
                title: 'Recurring Bills',
                subtitle: 'Manage recurring payments',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecurringBillsScreen(),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
                onTap: _showNotificationsDialog,
              ),
              _buildSettingsTile(
                icon: Icons.notification_important_outlined,
                title: 'Budget Alerts',
                subtitle: _budgetAlertsEnabled ? 'Enabled' : 'Disabled',
                onTap: _showBudgetAlertsDialog,
              ),
              _buildSettingsTile(
                icon: Icons.help_outline,
                title: 'Show Tutorial',
                subtitle: 'View app tutorial again',
                onTap: _showTutorialAgain,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            title: 'Data',
            children: [
              _buildSettingsTile(
                icon: Icons.backup_outlined,
                title: 'Backup',
                subtitle: 'Save your data',
                onTap: _backupData,
              ),
              _buildSettingsTile(
                icon: Icons.restore_outlined,
                title: 'Restore',
                subtitle: 'Restore from backup',
                onTap: _restoreFromBackup,
              ),
              _buildSettingsTile(
                icon: Icons.file_upload_outlined,
                title: 'Import Data',
                subtitle: 'Import from CSV file',
                onTap: _importData,
              ),
              _buildSettingsTile(
                icon: Icons.file_download_outlined,
                title: 'Export',
                subtitle: 'Export your data',
                onTap: _exportData,
              ),
              _buildSettingsTile(
                icon: Icons.delete_outline,
                title: 'Clear Data',
                subtitle: 'Delete all transactions',
                onTap: _clearData,
                isDestructive: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            title: 'Advanced',
            children: [
              _buildSettingsTile(
                icon: Icons.restore_outlined,
                title: 'Reset to Defaults',
                subtitle: 'Restore all settings to default values',
                onTap: _showResetDialog,
                isDestructive: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            title: 'About',
            children: [
              _buildSettingsTile(
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: '1.0.0',
                onTap: _showAboutDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getDefaultCategoryName(int? categoryId) {
    if (categoryId == null) return 'None';
    final category = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(
          name: 'Unknown',
          type: 'expense',
          colorValue: 0xFF757575,
          iconCodePoint: Icons.help_outline.codePoint),
    );
    return category.name;
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Theme.of(context).primaryColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).primaryColor,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 16),
          Text(
            'Processing...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
