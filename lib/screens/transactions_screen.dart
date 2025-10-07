import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import 'add_transaction_screen.dart';
import 'edit_transaction_screen.dart';
import 'view_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Transaction> _allTransactions = [];
  List<Transaction> _dayTransactions = [];
  Map<int, Category> _categories = {};
  bool _isLoading = true;
  String _filterType = 'all';
  DateTime _selectedDate = DateTime.now();
  final ScrollController _scrollController = ScrollController();
  double _headerOpacity = 1.0;
  bool _carryOverEnabled = false;
  double _carriedOverAmount = 0.0;

  // Search and filter properties
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';
  Set<int> _selectedCategoryIds = {};
  double? _minAmount;
  double? _maxAmount;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String _sortBy = 'date_desc'; // date_desc, date_asc, amount_desc, amount_asc
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadData();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _carryOverEnabled = prefs.getBool('carry_over_enabled') ?? false;
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final newOpacity = (1.0 - (offset / 150)).clamp(0.0, 1.0);
    if (newOpacity != _headerOpacity) {
      setState(() {
        _headerOpacity = newOpacity;
      });
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = DatabaseService.instance;
    final transactions = await db.getAllTransactions();
    final categories = await db.getCategories();

    setState(() {
      _allTransactions = transactions;
      _categories = {for (var cat in categories) cat.id!: cat};
      _isLoading = false;
    });

    _filterTransactionsByDate();
  }

  void _filterTransactionsByDate() {
    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    setState(() {
      _dayTransactions = _allTransactions.where((transaction) {
        return transaction.date.isAfter(startOfDay) &&
            transaction.date.isBefore(endOfDay);
      }).toList();
    });

    if (_carryOverEnabled) {
      _calculateCarriedOverAmount();
    }
  }

  Future<void> _calculateCarriedOverAmount() async {
    final startOfSelectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    double totalCarriedOver = 0.0;

    final previousTransactions = _allTransactions.where((transaction) {
      return transaction.date.isBefore(startOfSelectedDay);
    }).toList();

    for (var transaction in previousTransactions) {
      if (transaction.type == 'income') {
        totalCarriedOver += transaction.amount;
      } else {
        totalCarriedOver -= transaction.amount;
      }
    }

    setState(() {
      _carriedOverAmount = totalCarriedOver;
    });
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _filterTransactionsByDate();
  }

  void _nextDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (selectedDay.isBefore(today)) {
      setState(() {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      });
      _filterTransactionsByDate();
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
      _filterTransactionsByDate();
    }
  }

  double get _income {
    return _dayTransactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _expense {
    return _dayTransactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _balance {
    final dailyBalance = _income - _expense;
    return _carryOverEnabled ? dailyBalance + _carriedOverAmount : dailyBalance;
  }

  double get _endingBalance {
    return _balance;
  }

  List<Transaction> get _filteredTransactions {
    List<Transaction> filtered = _dayTransactions;

    // Apply type filter
    if (_filterType != 'all') {
      filtered = filtered.where((t) => t.type == _filterType).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((transaction) {
        final category = _categories[transaction.categoryId];
        final categoryName = category?.name.toLowerCase() ?? '';
        final notes = transaction.notes?.toLowerCase() ?? '';
        final amount = transaction.amount.toString();

        return categoryName.contains(_searchQuery) ||
            notes.contains(_searchQuery) ||
            amount.contains(_searchQuery);
      }).toList();
    }

    // Apply category filter
    if (_selectedCategoryIds.isNotEmpty) {
      filtered = filtered
          .where((t) => _selectedCategoryIds.contains(t.categoryId))
          .toList();
    }

    // Apply amount range filter
    if (_minAmount != null) {
      filtered = filtered.where((t) => t.amount >= _minAmount!).toList();
    }
    if (_maxAmount != null) {
      filtered = filtered.where((t) => t.amount <= _maxAmount!).toList();
    }

    // Apply custom date range filter
    if (_customStartDate != null && _customEndDate != null) {
      filtered = filtered.where((t) {
        return t.date
                .isAfter(_customStartDate!.subtract(const Duration(days: 1))) &&
            t.date.isBefore(_customEndDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'date_desc':
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'date_asc':
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'amount_desc':
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'amount_asc':
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }

    return filtered;
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _selectedCategoryIds.isNotEmpty ||
        _minAmount != null ||
        _maxAmount != null ||
        _customStartDate != null ||
        _customEndDate != null ||
        _sortBy != 'date_desc';
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategoryIds.clear();
      _minAmount = null;
      _maxAmount = null;
      _customStartDate = null;
      _customEndDate = null;
      _sortBy = 'date_desc';
    });
  }

  Future<void> _exportTransactions() async {
    // Show date range selection dialog
    final dateRange = await _showExportRangeDialog();

    if (dateRange == null) return; // User cancelled

    try {
      // Filter transactions by selected date range
      final transactionsToExport = _allTransactions.where((transaction) {
        return transaction.date.isAfter(dateRange['start']!) &&
            transaction.date
                .isBefore(dateRange['end']!.add(const Duration(days: 1)));
      }).toList();

      if (transactionsToExport.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No transactions found in selected range')),
          );
        }
        return;
      }

      final path = await ExportService.exportToCSV(transactionsToExport);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Exported ${transactionsToExport.length} transactions to: $path'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<Map<String, DateTime>?> _showExportRangeDialog() async {
    String selectedRange = 'day';
    DateTime? customStartDate;
    DateTime? customEndDate;

    return await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Export Transactions'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select time period:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRangeOption(
                  'Today',
                  'day',
                  selectedRange,
                  (value) => setState(() => selectedRange = value),
                ),
                _buildRangeOption(
                  'This Week',
                  'week',
                  selectedRange,
                  (value) => setState(() => selectedRange = value),
                ),
                _buildRangeOption(
                  'This Month',
                  'month',
                  selectedRange,
                  (value) => setState(() => selectedRange = value),
                ),
                _buildRangeOption(
                  'This Year',
                  'year',
                  selectedRange,
                  (value) => setState(() => selectedRange = value),
                ),
                _buildRangeOption(
                  'All Time',
                  'all',
                  selectedRange,
                  (value) => setState(() => selectedRange = value),
                ),
                _buildRangeOption(
                  'Custom Range',
                  'custom',
                  selectedRange,
                  (value) => setState(() => selectedRange = value),
                ),
                if (selectedRange == 'custom') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      customStartDate == null
                          ? 'Select Start Date'
                          : 'From: ${DateFormat('MMM d, yyyy').format(customStartDate!)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: customStartDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => customStartDate = date);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      customEndDate == null
                          ? 'Select End Date'
                          : 'To: ${DateFormat('MMM d, yyyy').format(customEndDate!)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: customEndDate ?? DateTime.now(),
                        firstDate: customStartDate ?? DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => customEndDate = date);
                      }
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Map<String, DateTime>? result = _getDateRange(
                    selectedRange,
                    customStartDate,
                    customEndDate,
                  );

                  if (result == null && selectedRange == 'custom') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select both start and end dates'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context, result);
                },
                child: const Text('Export'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRangeOption(
    String label,
    String value,
    String selectedValue,
    Function(String) onChanged,
  ) {
    return RadioListTile<String>(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 15)),
      value: value,
      groupValue: selectedValue,
      onChanged: (val) => onChanged(val!),
    );
  }

  Map<String, DateTime>? _getDateRange(
    String range,
    DateTime? customStart,
    DateTime? customEnd,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (range) {
      case 'day':
        return {
          'start': today,
          'end': today,
        };
      case 'week':
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return {
          'start': startOfWeek,
          'end': today,
        };
      case 'month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return {
          'start': startOfMonth,
          'end': today,
        };
      case 'year':
        final startOfYear = DateTime(now.year, 1, 1);
        return {
          'start': startOfYear,
          'end': today,
        };
      case 'all':
        return {
          'start': DateTime(2000, 1, 1),
          'end': today,
        };
      case 'custom':
        if (customStart != null && customEnd != null) {
          return {
            'start': customStart,
            'end': customEnd,
          };
        }
        return null;
      default:
        return {
          'start': today,
          'end': today,
        };
    }
  }

  Color _getCategoryColor(Category? category) {
    if (category?.colorValue == null) return Colors.grey;
    return Color(category!.colorValue!);
  }

  IconData _getCategoryIcon(Category? category) {
    if (category?.iconCodePoint == null) return Icons.help_outline;
    return IconData(category!.iconCodePoint!, fontFamily: 'MaterialIcons');
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAdvancedFiltersSheet(),
    );
  }

  Widget _buildAdvancedFiltersSheet() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Advanced Filters',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _clearAllFilters();
                        });
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.clear_all, color: Colors.white),
                      label: const Text(
                        'Clear All',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Category Filter
                    _buildFilterSection(
                      title: 'Categories',
                      icon: Icons.category_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.values.map((category) {
                          final isSelected =
                              _selectedCategoryIds.contains(category.id);
                          return FilterChip(
                            selected: isSelected,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCategoryIcon(category),
                                  size: 16,
                                  color: _getCategoryColor(category),
                                ),
                                const SizedBox(width: 4),
                                Text(category.name),
                              ],
                            ),
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  _selectedCategoryIds.add(category.id!);
                                } else {
                                  _selectedCategoryIds.remove(category.id!);
                                }
                              });
                              setState(() {});
                            },
                            backgroundColor: Colors.grey[100],
                            selectedColor:
                                _getCategoryColor(category).withOpacity(0.2),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Amount Range Filter
                    _buildFilterSection(
                      title: 'Amount Range',
                      icon: Icons.attach_money,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Min Amount',
                                prefixText: '\$ ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              controller: TextEditingController(
                                text: _minAmount?.toStringAsFixed(2) ?? '',
                              ),
                              onChanged: (value) {
                                setModalState(() {
                                  _minAmount = double.tryParse(value);
                                });
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'Max Amount',
                                prefixText: '\$ ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              controller: TextEditingController(
                                text: _maxAmount?.toStringAsFixed(2) ?? '',
                              ),
                              onChanged: (value) {
                                setModalState(() {
                                  _maxAmount = double.tryParse(value);
                                });
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Date Range Filter
                    _buildFilterSection(
                      title: 'Custom Date Range',
                      icon: Icons.date_range,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _customStartDate == null
                                  ? 'Start Date'
                                  : DateFormat('MMM d, yyyy')
                                      .format(_customStartDate!),
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _customStartDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setModalState(() {
                                  _customStartDate = date;
                                });
                                setState(() {});
                              }
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _customEndDate == null
                                  ? 'End Date'
                                  : DateFormat('MMM d, yyyy')
                                      .format(_customEndDate!),
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _customEndDate ?? DateTime.now(),
                                firstDate: _customStartDate ?? DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setModalState(() {
                                  _customEndDate = date;
                                });
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Sort Options
                    _buildFilterSection(
                      title: 'Sort By',
                      icon: Icons.sort,
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Date (Newest First)'),
                            value: 'date_desc',
                            groupValue: _sortBy,
                            onChanged: (value) {
                              setModalState(() {
                                _sortBy = value!;
                              });
                              setState(() {});
                            },
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Date (Oldest First)'),
                            value: 'date_asc',
                            groupValue: _sortBy,
                            onChanged: (value) {
                              setModalState(() {
                                _sortBy = value!;
                              });
                              setState(() {});
                            },
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Amount (High to Low)'),
                            value: 'amount_desc',
                            groupValue: _sortBy,
                            onChanged: (value) {
                              setModalState(() {
                                _sortBy = value!;
                              });
                              setState(() {});
                            },
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Amount (Low to High)'),
                            value: 'amount_asc',
                            groupValue: _sortBy,
                            onChanged: (value) {
                              setModalState(() {
                                _sortBy = value!;
                              });
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Apply Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check),
                        const SizedBox(width: 8),
                        Text(
                          'Apply Filters (${_filteredTransactions.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildActiveFiltersChips() {
    if (!_hasActiveFilters) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Active Filters:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_searchQuery.isNotEmpty)
                _buildActiveFilterChip(
                  'Search: "$_searchQuery"',
                  () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              if (_selectedCategoryIds.isNotEmpty)
                _buildActiveFilterChip(
                  '${_selectedCategoryIds.length} Categories',
                  () => setState(() => _selectedCategoryIds.clear()),
                ),
              if (_minAmount != null)
                _buildActiveFilterChip(
                  'Min: \$${_minAmount!.toStringAsFixed(2)}',
                  () => setState(() => _minAmount = null),
                ),
              if (_maxAmount != null)
                _buildActiveFilterChip(
                  'Max: \$${_maxAmount!.toStringAsFixed(2)}',
                  () => setState(() => _maxAmount = null),
                ),
              if (_customStartDate != null && _customEndDate != null)
                _buildActiveFilterChip(
                  '${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d').format(_customEndDate!)}',
                  () => setState(() {
                    _customStartDate = null;
                    _customEndDate = null;
                  }),
                ),
              if (_sortBy != 'date_desc')
                _buildActiveFilterChip(
                  'Sorted: ${_getSortLabel()}',
                  () => setState(() => _sortBy = 'date_desc'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'date_asc':
        return 'Date ↑';
      case 'amount_desc':
        return 'Amount ↓';
      case 'amount_asc':
        return 'Amount ↑';
      default:
        return 'Date ↓';
    }
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      deleteIconColor: Theme.of(context).primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: _carryOverEnabled ? 360 : 320,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Theme.of(context).primaryColor,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Column(
                      children: [
                        const SizedBox(height: 60),
                        Opacity(
                          opacity: _headerOpacity,
                          child: Column(
                            children: [
                              _buildDateSelector(),
                              const SizedBox(height: 8),
                              if (_carryOverEnabled) _buildCarryOverInfo(),
                              _buildSummaryCard(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: _buildFilterChips(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      children: [
                        _buildSearchBar(),
                        _buildActiveFiltersChips(),
                        _buildTransactionsList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by category, notes, or amount...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCarryOverInfo() {
    if (_carriedOverAmount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    );
  }

  Widget _buildDateSelector() {
    final formatter = DateFormat('EEEE, MMM d');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final isToday = selectedDay.isAtSameMomentAs(today);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousDay,
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            iconSize: 32,
          ),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              width: 220,
              height: 62,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isToday ? 'Today' : formatter.format(_selectedDate),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isToday)
                          Text(
                            DateFormat('yyyy').format(_selectedDate),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: isToday ? null : _nextDay,
            icon: Icon(
              Icons.chevron_right,
              color: isToday ? Colors.white30 : Colors.white,
            ),
            iconSize: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _carryOverEnabled ? 'Current Balance' : 'Daily Balance',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            NumberFormat.currency(symbol: '\$').format(_balance),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _balance >= 0 ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem(
                'Income',
                _income,
                Colors.green,
                Icons.arrow_downward,
              ),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              _buildSummaryItem(
                'Expense',
                _expense,
                Colors.red,
                Icons.arrow_upward,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormat.currency(symbol: '\$').format(amount),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Income', 'income'),
          const SizedBox(width: 8),
          _buildFilterChip('Expense', 'expense'),
          const Spacer(),
          IconButton(
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _showAdvancedFilters,
            tooltip: 'Advanced Filters',
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportTransactions,
            tooltip: 'Export to CSV',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildTransactionsList() {
    if (_filteredTransactions.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTransactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final transaction = _filteredTransactions[index];
        final category = _categories[transaction.categoryId];
        return _buildTransactionCard(transaction, category);
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters
                ? 'Try adjusting your filters'
                : 'Add your first transaction to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction, Category? category) {
    final isExpense = transaction.type == 'expense';
    final categoryColor = _getCategoryColor(category);
    final categoryIcon = _getCategoryIcon(category);

    return Dismissible(
      key: Key(transaction.id.toString()),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe left to right = Edit
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditTransactionScreen(
                transaction: transaction,
              ),
            ),
          );
          if (result == true) {
            _loadData();
          }
          return false;
        } else {
          // Swipe right to left = Delete
          return await _showDeleteDialog(transaction);
        }
      },
      child: InkWell(
        onTap: () async {
          // Navigate to view transaction screen on tap
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewTransactionScreen(
                transaction: transaction,
              ),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Hero(
              tag: 'transaction_${transaction.id}',
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(categoryIcon, color: categoryColor, size: 24),
              ),
            ),
            title: Text(
              category?.name ?? 'Unknown',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  DateFormat.jm().format(transaction.date),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (transaction.notes != null && transaction.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      transaction.notes!,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? '-' : '+'}\$${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isExpense ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (transaction.photoPath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.photo_camera,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(Transaction transaction) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Transaction'),
        content:
            const Text('Are you sure you want to delete this transaction?'),
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
      await DatabaseService.instance.deleteTransaction(transaction.id!);
      _loadData();
    }

    return confirmed;
  }
}
