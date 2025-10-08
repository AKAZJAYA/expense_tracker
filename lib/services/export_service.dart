import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
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
}
