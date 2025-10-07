class ValidationUtils {
  // Amount validation constants
  static const double maxAmount = 999999.99;
  static const double minAmount = 0.01;
  static const int maxDecimalPlaces = 2;
  
  // String validation constants
  static const int maxNotesLength = 500;
  static const int maxCategoryNameLength = 50;
  static const int maxBillNameLength = 100;
  
  // Date validation constants
  static final DateTime minDate = DateTime(2000, 1, 1);
  static final DateTime maxFutureDate = DateTime.now().add(const Duration(days: 365));

  /// Validates amount input
  /// Returns null if valid, error message otherwise
  static String? validateAmount(String? value, {bool allowFuture = false}) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }

    // Remove currency symbols and spaces
    final cleanValue = value.replaceAll(RegExp(r'[\$,\s]'), '');

    // Check for scientific notation
    if (cleanValue.contains(RegExp(r'[eE]'))) {
      return 'Invalid amount format';
    }

    final amount = double.tryParse(cleanValue);
    
    if (amount == null) {
      return 'Please enter a valid number';
    }

    if (amount < minAmount) {
      return 'Amount must be at least \$${minAmount.toStringAsFixed(2)}';
    }

    if (amount > maxAmount) {
      return 'Amount cannot exceed \$${maxAmount.toStringAsFixed(0)}';
    }

    // Check decimal places
    final parts = cleanValue.split('.');
    if (parts.length > 1 && parts[1].length > maxDecimalPlaces) {
      return 'Amount can only have $maxDecimalPlaces decimal places';
    }

    return null;
  }

  /// Validates date input
  static String? validateDate(DateTime? date, {bool allowFuture = false}) {
    if (date == null) {
      return 'Date is required';
    }

    if (date.isBefore(minDate)) {
      return 'Date cannot be before ${minDate.year}';
    }

    if (!allowFuture && date.isAfter(DateTime.now())) {
      return 'Date cannot be in the future';
    }

    if (allowFuture && date.isAfter(maxFutureDate)) {
      return 'Date is too far in the future';
    }

    return null;
  }

  /// Validates notes/description input
  static String? validateNotes(String? value, {bool required = false}) {
    if (required && (value == null || value.trim().isEmpty)) {
      return 'Notes are required';
    }

    if (value != null && value.length > maxNotesLength) {
      return 'Notes cannot exceed $maxNotesLength characters';
    }

    // Check for potentially harmful content
    if (value != null && _containsHarmfulContent(value)) {
      return 'Notes contain invalid characters';
    }

    return null;
  }

  /// Validates category name
  static String? validateCategoryName(String? value, {List<String>? existingNames, String? currentName}) {
    if (value == null || value.trim().isEmpty) {
      return 'Category name is required';
    }

    if (value.trim().length < 2) {
      return 'Category name must be at least 2 characters';
    }

    if (value.length > maxCategoryNameLength) {
      return 'Category name cannot exceed $maxCategoryNameLength characters';
    }

    // Check for duplicates (case-insensitive)
    if (existingNames != null) {
      final trimmedValue = value.trim().toLowerCase();
      final isDuplicate = existingNames.any((name) => 
        name.toLowerCase() == trimmedValue && name != currentName
      );
      
      if (isDuplicate) {
        return 'A category with this name already exists';
      }
    }

    // Check for invalid characters
    if (!RegExp(r'^[a-zA-Z0-9\s\-_&]+$').hasMatch(value)) {
      return 'Category name contains invalid characters';
    }

    return null;
  }

  /// Validates bill/recurring item name
  static String? validateBillName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bill name is required';
    }

    if (value.trim().length < 2) {
      return 'Bill name must be at least 2 characters';
    }

    if (value.length > maxBillNameLength) {
      return 'Bill name cannot exceed $maxBillNameLength characters';
    }

    if (!RegExp(r'^[a-zA-Z0-9\s\-_&.]+$').hasMatch(value)) {
      return 'Bill name contains invalid characters';
    }

    return null;
  }

  /// Validates budget amount
  static String? validateBudgetAmount(String? value, double? currentSpending) {
    final amountError = validateAmount(value);
    if (amountError != null) return amountError;

    if (currentSpending != null && currentSpending > 0) {
      final amount = double.parse(value!.replaceAll(RegExp(r'[\$,\s]'), ''));
      if (amount < currentSpending) {
        return 'Budget cannot be less than current spending (\$${currentSpending.toStringAsFixed(2)})';
      }
    }

    return null;
  }

  /// Sanitizes text input
  static String sanitizeText(String input) {
    // Remove leading/trailing whitespace
    String sanitized = input.trim();
    
    // Replace multiple spaces with single space
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove null characters and other control characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    
    return sanitized;
  }

  /// Formats amount for display
  static String formatAmount(double amount) {
    if (amount.abs() > maxAmount) {
      return maxAmount.toStringAsFixed(2);
    }
    return amount.toStringAsFixed(2);
  }

  /// Parses amount from string, returns null if invalid
  static double? parseAmount(String value) {
    final cleanValue = value.replaceAll(RegExp(r'[\$,\s]'), '');
    final amount = double.tryParse(cleanValue);
    
    if (amount == null) return null;
    if (amount < 0) return null;
    if (amount > maxAmount) return null;
    
    // Round to 2 decimal places
    return double.parse(amount.toStringAsFixed(2));
  }

  /// Validates search query
  static String? validateSearchQuery(String? query) {
    if (query == null || query.isEmpty) {
      return null; // Empty search is valid
    }

    if (query.length > 100) {
      return 'Search query too long';
    }

    return null;
  }

  /// Checks if date range is valid
  static String? validateDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) {
      return 'Both start and end dates are required';
    }

    if (startDate.isAfter(endDate)) {
      return 'Start date must be before end date';
    }

    final daysDifference = endDate.difference(startDate).inDays;
    if (daysDifference > 365) {
      return 'Date range cannot exceed 1 year';
    }

    return null;
  }

  /// Helper to check for harmful content
  static bool _containsHarmfulContent(String text) {
    // Check for SQL injection patterns
    if (RegExp(r"('|(--)|;|/\*|\*/|xp_|sp_)", caseSensitive: false).hasMatch(text)) {
      return true;
    }
    
    // Check for XSS patterns
    if (RegExp(r'<script|javascript:|onerror=|onclick=', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    
    return false;
  }

  /// Real-time amount formatter for TextField
  static String formatAmountInput(String value) {
    // Remove all non-numeric except decimal point
    String cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
    
    // Ensure only one decimal point
    final parts = cleaned.split('.');
    if (parts.length > 2) {
      cleaned = '${parts[0]}.${parts.sublist(1).join('')}';
    }
    
    // Limit decimal places
    if (parts.length == 2 && parts[1].length > maxDecimalPlaces) {
      cleaned = '${parts[0]}.${parts[1].substring(0, maxDecimalPlaces)}';
    }
    
    return cleaned;
  }

  /// Validates file size for photo uploads
  static String? validatePhotoSize(int fileSizeBytes) {
    const maxSizeBytes = 10 * 1024 * 1024; // 10 MB
    
    if (fileSizeBytes > maxSizeBytes) {
      return 'Photo size cannot exceed 10 MB';
    }
    
    return null;
  }

  /// Validates export date range
  static String? validateExportRange(DateTime? start, DateTime? end, int transactionCount) {
    final rangeError = validateDateRange(start, end);
    if (rangeError != null) return rangeError;

    if (transactionCount == 0) {
      return 'No transactions found in selected date range';
    }

    if (transactionCount > 10000) {
      return 'Too many transactions (${transactionCount}). Please narrow date range.';
    }

    return null;
  }
}

/// Extension methods for easy validation
extension StringValidation on String? {
  bool get isValidAmount => ValidationUtils.validateAmount(this) == null;
  bool get isValidCategoryName => ValidationUtils.validateCategoryName(this) == null;
  bool get isValidBillName => ValidationUtils.validateBillName(this) == null;
  
  String? get asAmount => this == null ? null : ValidationUtils.parseAmount(this!)?.toString();
}

extension DateTimeValidation on DateTime? {
  bool get isValidTransactionDate => ValidationUtils.validateDate(this) == null;
  bool get isValidFutureDate => ValidationUtils.validateDate(this, allowFuture: true) == null;
}