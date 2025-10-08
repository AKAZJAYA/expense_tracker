class Transaction {
  final int? id;
  final String type;
  final double amount;
  final int categoryId;
  final String? notes;
  final DateTime date;
  final String? photoPath;

  Transaction({
    this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.notes,
    required this.date,
    this.photoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'notes': notes,
      'date': date.toIso8601String(),
      'photoPath': photoPath,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      type: map['type'],
      amount: map['amount'],
      categoryId: map['categoryId'],
      notes: map['notes'],
      date: DateTime.parse(map['date']),
      photoPath: map['photoPath'],
    );
  }
}
