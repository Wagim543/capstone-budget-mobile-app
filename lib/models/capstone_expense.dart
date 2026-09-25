class ExpenseItem {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String paidBy;
  final String category;
  bool isReimbursed;

  ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.paidBy,
    required this.category,
    this.isReimbursed = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'date': date.toIso8601String(),
    'paidBy': paidBy,
    'category': category,
    'isReimbursed': isReimbursed,
  };

  factory ExpenseItem.fromMap(Map<String, dynamic> map) => ExpenseItem(
    id: map['id'],
    title: map['title'],
    amount: (map['amount'] as num).toDouble(),
    date: DateTime.parse(map['date']),
    paidBy: map['paidBy'] ?? 'Unknown',
    category: map['category'] ?? 'Miscellaneous',
    isReimbursed: map['isReimbursed'] ?? false,
  );
}
