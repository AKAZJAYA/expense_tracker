import 'package:flutter/material.dart';
import '../models/recurring_bill.dart';
import '../models/transaction.dart';
import 'database_service.dart';

class RecurringBillsProcessor {
  static final RecurringBillsProcessor instance = RecurringBillsProcessor._init();
  
  RecurringBillsProcessor._init();

  /// Process all due recurring bills and create transactions
  Future<List<RecurringBill>> processDueBills() async {
    final db = DatabaseService.instance;
    final bills = await db.getRecurringBills();
    final now = DateTime.now();
    final processedBills = <RecurringBill>[];

    for (var bill in bills) {
      // Skip if bill has ended
      if (bill.endDate != null && now.isAfter(bill.endDate!)) {
        continue;
      }

      final dueDate = _calculateNextDueDate(bill);
      
      // Check if bill is due (due date has passed and not yet processed)
      if (dueDate != null && _isDue(dueDate, now, bill.lastProcessed)) {
        await _createTransactionForBill(bill, dueDate);
        
        // Update lastProcessed date
        final updatedBill = RecurringBill(
          id: bill.id,
          name: bill.name,
          amount: bill.amount,
          categoryId: bill.categoryId,
          frequency: bill.frequency,
          startDate: bill.startDate,
          endDate: bill.endDate,
          lastProcessed: now,
        );
        
        await db.updateRecurringBill(updatedBill);
        processedBills.add(updatedBill);
      }
    }

    return processedBills;
  }

  /// Process a specific bill manually
  Future<bool> processSpecificBill(RecurringBill bill) async {
    final db = DatabaseService.instance;
    final now = DateTime.now();

    // Skip if bill has ended
    if (bill.endDate != null && now.isAfter(bill.endDate!)) {
      return false;
    }

    final dueDate = _calculateNextDueDate(bill) ?? now;
    await _createTransactionForBill(bill, dueDate);

    // Update lastProcessed date
    final updatedBill = RecurringBill(
      id: bill.id,
      name: bill.name,
      amount: bill.amount,
      categoryId: bill.categoryId,
      frequency: bill.frequency,
      startDate: bill.startDate,
      endDate: bill.endDate,
      lastProcessed: now,
    );

    await db.updateRecurringBill(updatedBill);
    return true;
  }

  /// Calculate the next due date for a recurring bill
  DateTime? _calculateNextDueDate(RecurringBill bill) {
    final lastProcessed = bill.lastProcessed ?? bill.startDate;
    final now = DateTime.now();

    switch (bill.frequency.toLowerCase()) {
      case 'weekly':
        return _addWeeks(lastProcessed, 1);
      
      case 'biweekly':
        return _addWeeks(lastProcessed, 2);
      
      case 'monthly':
        return _addMonths(lastProcessed, 1);
      
      case 'quarterly':
        return _addMonths(lastProcessed, 3);
      
      case 'yearly':
        return _addYears(lastProcessed, 1);
      
      default:
        return null;
    }
  }

  /// Check if a bill is due based on due date and last processed date
  bool _isDue(DateTime dueDate, DateTime now, DateTime? lastProcessed) {
    // Bill is due if the due date has passed
    if (now.isAfter(dueDate) || _isSameDay(now, dueDate)) {
      // If never processed, it's due
      if (lastProcessed == null) {
        return true;
      }
      
      // Check if it hasn't been processed since the due date
      return lastProcessed.isBefore(dueDate);
    }
    
    return false;
  }

  /// Create a transaction for a recurring bill
  Future<void> _createTransactionForBill(
    RecurringBill bill,
    DateTime dueDate,
  ) async {
    final transaction = Transaction(
      type: 'expense',
      amount: bill.amount,
      categoryId: bill.categoryId,
      notes: 'Recurring: ${bill.name}',
      date: dueDate,
      photoPath: null,
    );

    await DatabaseService.instance.insertTransaction(transaction);
  }

  /// Add weeks to a date
  DateTime _addWeeks(DateTime date, int weeks) {
    return date.add(Duration(days: 7 * weeks));
  }

  /// Add months to a date, handling edge cases
  DateTime _addMonths(DateTime date, int months) {
    int year = date.year;
    int month = date.month + months;
    int day = date.day;

    // Handle year overflow
    while (month > 12) {
      month -= 12;
      year++;
    }

    // Handle day overflow (e.g., Jan 31 -> Feb 28/29)
    final daysInMonth = _getDaysInMonth(year, month);
    if (day > daysInMonth) {
      day = daysInMonth;
    }

    return DateTime(year, month, day, date.hour, date.minute, date.second);
  }

  /// Add years to a date, handling leap year edge case
  DateTime _addYears(DateTime date, int years) {
    int year = date.year + years;
    int month = date.month;
    int day = date.day;

    // Handle Feb 29 on non-leap years
    if (month == 2 && day == 29 && !_isLeapYear(year)) {
      day = 28;
    }

    return DateTime(year, month, day, date.hour, date.minute, date.second);
  }

  /// Get the number of days in a month
  int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      return _isLeapYear(year) ? 29 : 28;
    }
    
    if (month == 4 || month == 6 || month == 9 || month == 11) {
      return 30;
    }
    
    return 31;
  }

  /// Check if a year is a leap year
  bool _isLeapYear(int year) {
    if (year % 4 != 0) return false;
    if (year % 100 != 0) return true;
    return year % 400 == 0;
  }

  /// Check if two dates are on the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Get a human-readable description of when a bill is due
  String getNextDueDescription(RecurringBill bill) {
    final nextDue = _calculateNextDueDate(bill);
    if (nextDue == null) return 'Unknown';

    final now = DateTime.now();
    final difference = nextDue.difference(now).inDays;

    if (difference < 0) {
      return 'Overdue by ${-difference} day${-difference == 1 ? '' : 's'}';
    } else if (difference == 0) {
      return 'Due today';
    } else if (difference == 1) {
      return 'Due tomorrow';
    } else if (difference <= 7) {
      return 'Due in $difference days';
    } else {
      return 'Due on ${_formatDate(nextDue)}';
    }
  }

  /// Format a date for display
  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Check if any bills need processing
  Future<bool> hasDueBills() async {
    final bills = await DatabaseService.instance.getRecurringBills();
    final now = DateTime.now();

    for (var bill in bills) {
      if (bill.endDate != null && now.isAfter(bill.endDate!)) {
        continue;
      }

      final dueDate = _calculateNextDueDate(bill);
      if (dueDate != null && _isDue(dueDate, now, bill.lastProcessed)) {
        return true;
      }
    }

    return false;
  }

  /// Get count of due bills
  Future<int> getDueBillsCount() async {
    final bills = await DatabaseService.instance.getRecurringBills();
    final now = DateTime.now();
    int count = 0;

    for (var bill in bills) {
      if (bill.endDate != null && now.isAfter(bill.endDate!)) {
        continue;
      }

      final dueDate = _calculateNextDueDate(bill);
      if (dueDate != null && _isDue(dueDate, now, bill.lastProcessed)) {
        count++;
      }
    }

    return count;
  }
}