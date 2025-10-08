class RecurringBill {
  final int? id;
  final String name;
  final double amount;
  final int categoryId;
  final String frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? lastProcessed;

  RecurringBill({
    this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.lastProcessed,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'categoryId': categoryId,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'lastProcessed': lastProcessed?.toIso8601String(),
    };
  }

  factory RecurringBill.fromMap(Map<String, dynamic> map) {
    return RecurringBill(
      id: map['id'],
      name: map['name'],
      amount: map['amount'],
      categoryId: map['categoryId'],
      frequency: map['frequency'],
      startDate: DateTime.parse(map['startDate']),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      lastProcessed: map['lastProcessed'] != null ? DateTime.parse(map['lastProcessed']) : null,
    );
  }
}
