import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';
import '../models/category.dart';
import 'database_service.dart';

class BudgetMonitorService {
  static final BudgetMonitorService instance = BudgetMonitorService._init();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  BudgetMonitorService._init();

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    _isInitialized = true;
  }

  /// Check all budgets after a transaction change
  Future<List<BudgetAlert>> checkBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final alertsEnabled = prefs.getBool('budget_alerts_enabled') ?? true;

    if (!alertsEnabled) return [];

    final db = DatabaseService.instance;
    final budgets = await db.getBudgets();
    final alerts = <BudgetAlert>[];

    for (var budget in budgets) {
      final alert = await _checkBudget(budget);
      if (alert != null) {
        alerts.add(alert);
      }
    }

    return alerts;
  }

  /// Check a specific budget
  Future<BudgetAlert?> _checkBudget(Budget budget) async {
    final prefs = await SharedPreferences.getInstance();
    final threshold80 = prefs.getInt('alert_threshold_80') ?? 80;
    final threshold100 = prefs.getInt('alert_threshold_100') ?? 100;
    final threshold120 = prefs.getInt('alert_threshold_120') ?? 120;

    final db = DatabaseService.instance;
    final category = await db.getCategoryById(budget.categoryId);

    final startDate = budget.startDate;
    final endDate = budget.endDate ?? DateTime.now();
    final spent =
        await db.getTotalByCategory(budget.categoryId, startDate, endDate);

    final percentage = (spent / budget.amount * 100).round();

    // Check thresholds
    if (percentage >= threshold120) {
      return BudgetAlert(
        budget: budget,
        category: category,
        spent: spent,
        percentage: percentage,
        level: AlertLevel.critical,
        message:
            'You\'ve exceeded your ${category?.name ?? 'budget'} budget by ${percentage - 100}%!',
      );
    } else if (percentage >= threshold100) {
      return BudgetAlert(
        budget: budget,
        category: category,
        spent: spent,
        percentage: percentage,
        level: AlertLevel.danger,
        message:
            'You\'ve reached your ${category?.name ?? 'budget'} budget limit!',
      );
    } else if (percentage >= threshold80) {
      return BudgetAlert(
        budget: budget,
        category: category,
        spent: spent,
        percentage: percentage,
        level: AlertLevel.warning,
        message:
            'You\'ve used ${percentage}% of your ${category?.name ?? 'budget'} budget.',
      );
    }

    return null;
  }

  /// Send notification for budget alert
  Future<void> sendNotification(BudgetAlert alert) async {
    await initialize();

    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('budget_alerts_enabled') ?? true;

    if (!notificationsEnabled) return;

    // Check if we already sent a notification for this alert level today
    final lastAlertKey = 'last_alert_${alert.budget.id}_${alert.level.name}';
    final lastAlert = prefs.getString(lastAlertKey);
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastAlert == today) return; // Already sent today

    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Notifications for budget thresholds',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      alert.budget.id ?? 0,
      '${_getAlertIcon(alert.level)} Budget Alert',
      alert.message,
      details,
    );

    // Save that we sent this alert today
    await prefs.setString(lastAlertKey, today);
  }

  String _getAlertIcon(AlertLevel level) {
    switch (level) {
      case AlertLevel.warning:
        return '⚠️';
      case AlertLevel.danger:
        return '🚨';
      case AlertLevel.critical:
        return '❌';
    }
  }

  /// Get color for alert level
  Color getAlertColor(AlertLevel level) {
    switch (level) {
      case AlertLevel.warning:
        return Colors.orange;
      case AlertLevel.danger:
        return Colors.red;
      case AlertLevel.critical:
        return Colors.red.shade900;
    }
  }

  /// Check if immediate alerts are enabled
  Future<bool> shouldSendImmediateAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final frequency = prefs.getString('alert_frequency') ?? 'immediate';
    return frequency == 'immediate';
  }
}

enum AlertLevel {
  warning, // 80%
  danger, // 100%
  critical, // 120%
}

class BudgetAlert {
  final Budget budget;
  final Category? category;
  final double spent;
  final int percentage;
  final AlertLevel level;
  final String message;

  BudgetAlert({
    required this.budget,
    required this.category,
    required this.spent,
    required this.percentage,
    required this.level,
    required this.message,
  });
}
