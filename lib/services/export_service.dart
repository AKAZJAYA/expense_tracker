import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import 'database_service.dart';

class ExportService {
  static Future<String> exportToCSV(List<Transaction> transactions) async {
    final db = DatabaseService.instance;
    List<List<dynamic>> rows = [];
    
    rows.add(['Date', 'Type', 'Category', 'Amount', 'Notes']);

    for (var transaction in transactions) {
      final category = await db.getCategoryById(transaction.categoryId);
      rows.add([
        transaction.date.toIso8601String().split('T')[0],
        transaction.type,
        category?.name ?? 'Unknown',
        transaction.amount,
        transaction.notes ?? '',
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/transactions_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    
    return file.path;
  }

  /// Import transactions from CSV file
  static Future<ImportResult> importFromCSV({
    required Function(int current, int total) onProgress,
  }) async {
    try {
      // Pick CSV file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ImportResult(
          success: false,
          message: 'No file selected',
          imported: 0,
          skipped: 0,
          errors: 0,
        );
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        return ImportResult(
          success: false,
          message: 'Invalid file path',
          imported: 0,
          skipped: 0,
          errors: 0,
        );
      }

      final file = File(filePath);
      final csvString = await file.readAsString();
      
      // Parse CSV
      final csvData = const CsvToListConverter().convert(csvString);
      
      if (csvData.isEmpty || csvData.length < 2) {
        return ImportResult(
          success: false,
          message: 'CSV file is empty or invalid',
          imported: 0,
          skipped: 0,
          errors: 0,
        );
      }

      // Validate header
      final header = csvData[0];
      if (!_isValidHeader(header)) {
        return ImportResult(
          success: false,
          message: 'Invalid CSV format. Expected columns: Date, Type, Category, Amount, Notes',
          imported: 0,
          skipped: 0,
          errors: 0,
        );
      }

      final db = DatabaseService.instance;
      final existingTransactions = await db.getAllTransactions();
      final categories = await db.getCategories();
      
      int imported = 0;
      int skipped = 0;
      int errors = 0;
      
      // Process each row (skip header)
      for (int i = 1; i < csvData.length; i++) {
        onProgress(i, csvData.length - 1);
        
        try {
          final row = csvData[i];
          if (row.length < 4) {
            errors++;
            continue;
          }

          final dateStr = row[0].toString();
          final type = row[1].toString().toLowerCase();
          final categoryName = row[2].toString();
          final amount = double.tryParse(row[3].toString());
          final notes = row.length > 4 ? row[4]?.toString() : null;

          // Validate data
          if (amount == null || amount <= 0) {
            errors++;
            continue;
          }

          if (type != 'expense' && type != 'income') {
            errors++;
            continue;
          }

          // Parse date
          DateTime? date;
          try {
            date = DateTime.parse(dateStr);
          } catch (e) {
            errors++;
            continue;
          }

          // Find or create category
          Category? category = categories.firstWhere(
            (cat) => cat.name.toLowerCase() == categoryName.toLowerCase() && cat.type == type,
            orElse: () => Category(
              name: categoryName,
              type: type,
              colorValue: type == 'expense' ? 0xFFFF5252 : 0xFF4CAF50,
              iconCodePoint: type == 'expense' ? 0xe59c : 0xe227,
            ),
          );

          // Create category if it doesn't exist
          if (category.id == null) {
            final categoryId = await db.createCategory(category);
            category = await db.getCategoryById(categoryId);
            categories.add(category!);
          }

          // Check for duplicates (same date, amount, and category)
          final isDuplicate = existingTransactions.any((t) =>
            t.date.year == date!.year &&
            t.date.month == date.month &&
            t.date.day == date.day &&
            t.amount == amount &&
            t.categoryId == category!.id
          );

          if (isDuplicate) {
            skipped++;
            continue;
          }

          // Create transaction
          final transaction = Transaction(
            type: type,
            amount: amount,
            categoryId: category.id!,
            date: date,
            notes: notes?.isEmpty == true ? null : notes,
          );

          await db.insertTransaction(transaction);
          imported++;
          
        } catch (e) {
          errors++;
        }
      }

      return ImportResult(
        success: true,
        message: 'Import completed',
        imported: imported,
        skipped: skipped,
        errors: errors,
      );

    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Import failed: $e',
        imported: 0,
        skipped: 0,
        errors: 0,
      );
    }
  }

  /// Get list of backup files
  static Future<List<BackupFile>> getBackupFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      
      final backupFiles = <BackupFile>[];
      
      for (var file in files) {
        if (file is File && file.path.endsWith('.csv')) {
          final fileName = file.path.split('/').last;
          if (fileName.startsWith('transactions_export_')) {
            final stat = await file.stat();
            backupFiles.add(BackupFile(
              path: file.path,
              name: fileName,
              size: stat.size,
              modified: stat.modified,
            ));
          }
        }
      }
      
      // Sort by date (newest first)
      backupFiles.sort((a, b) => b.modified.compareTo(a.modified));
      
      return backupFiles;
    } catch (e) {
      return [];
    }
  }

  /// Restore from backup file
  static Future<ImportResult> restoreFromBackup({
    required String filePath,
    required bool clearExisting,
    required Function(int current, int total) onProgress,
  }) async {
    try {
      final db = DatabaseService.instance;

      // Clear existing data if requested
      if (clearExisting) {
        final transactions = await db.getAllTransactions();
        for (var transaction in transactions) {
          await db.deleteTransaction(transaction.id!);
        }
      }

      final file = File(filePath);
      final csvString = await file.readAsString();
      
      // Parse CSV
      final csvData = const CsvToListConverter().convert(csvString);
      
      if (csvData.isEmpty || csvData.length < 2) {
        return ImportResult(
          success: false,
          message: 'Backup file is empty or invalid',
          imported: 0,
          skipped: 0,
          errors: 0,
        );
      }

      // Validate header
      final header = csvData[0];
      if (!_isValidHeader(header)) {
        return ImportResult(
          success: false,
          message: 'Invalid backup format',
          imported: 0,
          skipped: 0,
          errors: 0,
        );
      }

      final existingTransactions = await db.getAllTransactions();
      final categories = await db.getCategories();
      
      int imported = 0;
      int skipped = 0;
      int errors = 0;
      
      // Process each row (skip header)
      for (int i = 1; i < csvData.length; i++) {
        onProgress(i, csvData.length - 1);
        
        try {
          final row = csvData[i];
          if (row.length < 4) {
            errors++;
            continue;
          }

          final dateStr = row[0].toString();
          final type = row[1].toString().toLowerCase();
          final categoryName = row[2].toString();
          final amount = double.tryParse(row[3].toString());
          final notes = row.length > 4 ? row[4]?.toString() : null;

          // Validate data
          if (amount == null || amount <= 0) {
            errors++;
            continue;
          }

          if (type != 'expense' && type != 'income') {
            errors++;
            continue;
          }

          // Parse date
          DateTime? date;
          try {
            date = DateTime.parse(dateStr);
          } catch (e) {
            errors++;
            continue;
          }

          // Find or create category
          Category? category = categories.firstWhere(
            (cat) => cat.name.toLowerCase() == categoryName.toLowerCase() && cat.type == type,
            orElse: () => Category(
              name: categoryName,
              type: type,
              colorValue: type == 'expense' ? 0xFFFF5252 : 0xFF4CAF50,
              iconCodePoint: type == 'expense' ? 0xe59c : 0xe227,
            ),
          );

          // Create category if it doesn't exist
          if (category.id == null) {
            final categoryId = await db.createCategory(category);
            category = await db.getCategoryById(categoryId);
            categories.add(category!);
          }

          // Check for duplicates only if not clearing existing data
          if (!clearExisting) {
            final isDuplicate = existingTransactions.any((t) =>
              t.date.year == date!.year &&
              t.date.month == date.month &&
              t.date.day == date.day &&
              t.amount == amount &&
              t.categoryId == category!.id
            );

            if (isDuplicate) {
              skipped++;
              continue;
            }
          }

          // Create transaction
          final transaction = Transaction(
            type: type,
            amount: amount,
            categoryId: category.id!,
            date: date,
            notes: notes?.isEmpty == true ? null : notes,
          );

          await db.insertTransaction(transaction);
          imported++;
          
        } catch (e) {
          errors++;
        }
      }

      return ImportResult(
        success: true,
        message: 'Restore completed',
        imported: imported,
        skipped: skipped,
        errors: errors,
      );

    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Restore failed: $e',
        imported: 0,
        skipped: 0,
        errors: 0,
      );
    }
  }

  static bool _isValidHeader(List<dynamic> header) {
    if (header.length < 4) return false;
    
    final expectedHeaders = ['date', 'type', 'category', 'amount'];
    for (int i = 0; i < expectedHeaders.length; i++) {
      if (header[i].toString().toLowerCase() != expectedHeaders[i]) {
        return false;
      }
    }
    
    return true;
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int imported;
  final int skipped;
  final int errors;

  ImportResult({
    required this.success,
    required this.message,
    required this.imported,
    required this.skipped,
    required this.errors,
  });
}

class BackupFile {
  final String path;
  final String name;
  final int size;
  final DateTime modified;

  BackupFile({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
