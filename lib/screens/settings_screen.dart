import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _carryOverEnabled = false;
  bool _notificationsEnabled = true;
  String _selectedTheme = 'Light';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _carryOverEnabled = prefs.getBool('carry_over_enabled') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _selectedTheme = prefs.getString('theme') ?? 'Light';
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

  Future<void> _showThemeDialog() async {
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
              groupValue: _selectedTheme,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              title: const Text('Dark'),
              value: 'Dark',
              groupValue: _selectedTheme,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            RadioListTile<String>(
              title: const Text('System'),
              value: 'System',
              groupValue: _selectedTheme,
              onChanged: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme', result);
      setState(() {
        _selectedTheme = result;
      });
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
    setState(() => _isLoading = true);

    try {
      final transactions = await DatabaseService.instance.getAllTransactions();
      final categories = await DatabaseService.instance.getCategories();

      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No transactions to export')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final path = await ExportService.exportToCSV(transactions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data exported successfully to: $path'),
            duration: const Duration(seconds: 3),
          ),
        );
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
                  if (result.errors > 0)
                    Text('❌ Errors: ${result.errors}'),
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
                  if (result.errors > 0)
                    Text('❌ Errors: ${result.errors}'),
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
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: _selectedTheme,
                onTap: _showThemeDialog,
              ),
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
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
                onTap: _showNotificationsDialog,
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

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
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
        color: isDestructive ? Colors.red : Colors.grey[700],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.grey[700]),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ImportProgressDialog extends StatelessWidget {
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
