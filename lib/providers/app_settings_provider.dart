import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AppSettingsProvider extends ChangeNotifier {
  // Default categories
  int? _defaultExpenseCategoryId;
  int? _defaultIncomeCategoryId;

  // Currency settings
  String _currencySymbol = '\$';
  String _decimalSeparator = '.';
  String _thousandsSeparator = ',';

  // Date/Time format
  String _dateFormat = 'MM/dd/yyyy';
  bool _use24HourTime = false;

  // Getters
  int? get defaultExpenseCategoryId => _defaultExpenseCategoryId;
  int? get defaultIncomeCategoryId => _defaultIncomeCategoryId;
  String get currencySymbol => _currencySymbol;
  String get decimalSeparator => _decimalSeparator;
  String get thousandsSeparator => _thousandsSeparator;
  String get dateFormat => _dateFormat;
  bool get use24HourTime => _use24HourTime;

  AppSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultExpenseCategoryId = prefs.getInt('default_expense_category');
    _defaultIncomeCategoryId = prefs.getInt('default_income_category');
    _currencySymbol = prefs.getString('currency_symbol') ?? '\$';
    _decimalSeparator = prefs.getString('decimal_separator') ?? '.';
    _thousandsSeparator = prefs.getString('thousands_separator') ?? ',';
    _dateFormat = prefs.getString('date_format') ?? 'MM/dd/yyyy';
    _use24HourTime = prefs.getBool('use_24hour_time') ?? false;
    notifyListeners();
  }

  Future<void> setDefaultExpenseCategory(int? categoryId) async {
    _defaultExpenseCategoryId = categoryId;
    final prefs = await SharedPreferences.getInstance();
    if (categoryId != null) {
      await prefs.setInt('default_expense_category', categoryId);
    } else {
      await prefs.remove('default_expense_category');
    }
    notifyListeners();
  }

  Future<void> setDefaultIncomeCategory(int? categoryId) async {
    _defaultIncomeCategoryId = categoryId;
    final prefs = await SharedPreferences.getInstance();
    if (categoryId != null) {
      await prefs.setInt('default_income_category', categoryId);
    } else {
      await prefs.remove('default_income_category');
    }
    notifyListeners();
  }

  Future<void> setCurrencySymbol(String symbol) async {
    _currencySymbol = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_symbol', symbol);
    notifyListeners();
  }

  Future<void> setDecimalSeparator(String separator) async {
    _decimalSeparator = separator;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('decimal_separator', separator);
    notifyListeners();
  }

  Future<void> setThousandsSeparator(String separator) async {
    _thousandsSeparator = separator;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('thousands_separator', separator);
    notifyListeners();
  }

  Future<void> setDateFormat(String format) async {
    _dateFormat = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('date_format', format);
    notifyListeners();
  }

  Future<void> set24HourTime(bool use24Hour) async {
    _use24HourTime = use24Hour;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_24hour_time', use24Hour);
    notifyListeners();
  }

  // Format currency with user preferences
  String formatCurrency(double amount) {
    final formattedNumber = amount.toStringAsFixed(2);
    final parts = formattedNumber.split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    // Add thousands separator
    String formattedInteger = '';
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        formattedInteger += _thousandsSeparator;
      }
      formattedInteger += integerPart[i];
    }

    return '$_currencySymbol$formattedInteger$_decimalSeparator$decimalPart';
  }

  // Format date with user preferences
  String formatDate(DateTime date) {
    switch (_dateFormat) {
      case 'dd/MM/yyyy':
        return DateFormat('dd/MM/yyyy').format(date);
      case 'yyyy-MM-dd':
        return DateFormat('yyyy-MM-dd').format(date);
      default:
        return DateFormat('MM/dd/yyyy').format(date);
    }
  }

  // Format time with user preferences
  String formatTime(DateTime time) {
    return _use24HourTime
        ? DateFormat('HH:mm').format(time)
        : DateFormat('h:mm a').format(time);
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_expense_category');
    await prefs.remove('default_income_category');
    await prefs.remove('currency_symbol');
    await prefs.remove('decimal_separator');
    await prefs.remove('thousands_separator');
    await prefs.remove('date_format');
    await prefs.remove('use_24hour_time');
    
    _defaultExpenseCategoryId = null;
    _defaultIncomeCategoryId = null;
    _currencySymbol = '\$';
    _decimalSeparator = '.';
    _thousandsSeparator = ',';
    _dateFormat = 'MM/dd/yyyy';
    _use24HourTime = false;
    
    notifyListeners();
  }
}