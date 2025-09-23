import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add new transaction
  Future<String?> addTransaction(TransactionModel transaction) async {
    try {
      await _firestore
          .collection('transactions')
          .add(transaction.toFirestore());
      return null; // Success
    } catch (e) {
      return 'Error adding transaction: $e';
    }
  }

  // Update transaction
  Future<String?> updateTransaction(TransactionModel transaction) async {
    try {
      await _firestore
          .collection('transactions')
          .doc(transaction.id)
          .update(transaction.toFirestore());
      return null; // Success
    } catch (e) {
      return 'Error updating transaction: $e';
    }
  }

  // Delete transaction
  Future<String?> deleteTransaction(String transactionId) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).delete();
      return null; // Success
    } catch (e) {
      return 'Error deleting transaction: $e';
    }
  }

  // Get transactions for a user
  Stream<List<TransactionModel>> getUserTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList(),
        );
  }

  // Get transactions for a user on a specific date
  Future<List<TransactionModel>> getUserTransactionsByDate(
    String userId,
    DateTime date,
  ) async {
    try {
      print('Getting transactions for userId: $userId on date: $date');

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      print('Date range: $startOfDay to $endOfDay');

      // Get all transactions for user, then filter by date in-memory
      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .get();

      print('Found ${snapshot.docs.length} total transactions for user');

      final allTransactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      // Filter by date range in memory
      final filteredTransactions = allTransactions.where((transaction) {
        return transaction.date.isAfter(
              startOfDay.subtract(const Duration(milliseconds: 1)),
            ) &&
            transaction.date.isBefore(
              endOfDay.add(const Duration(milliseconds: 1)),
            );
      }).toList();

      // Sort by date descending
      filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

      print(
        'Filtered to ${filteredTransactions.length} transactions for today',
      );

      return filteredTransactions;
    } catch (e) {
      print('Error getting transactions by date: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get transactions for a user in a month
  Future<List<TransactionModel>> getUserTransactionsByMonth(
    String userId,
    int month,
    int year,
  ) async {
    try {
      print(
        'Getting transactions for userId: $userId, month: $month, year: $year',
      );

      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      print('Date range: $startOfMonth to $endOfMonth');

      // First get all transactions for user, then filter by date in-memory
      // This avoids compound index issues
      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .get();

      print('Found ${snapshot.docs.length} total transactions for user');

      final allTransactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();

      // Filter by date range in memory
      final filteredTransactions = allTransactions.where((transaction) {
        return transaction.date.isAfter(
              startOfMonth.subtract(const Duration(days: 1)),
            ) &&
            transaction.date.isBefore(endOfMonth.add(const Duration(days: 1)));
      }).toList();

      // Sort by date descending
      filteredTransactions.sort((a, b) => b.date.compareTo(a.date));

      print(
        'Filtered to ${filteredTransactions.length} transactions for the month',
      );

      return filteredTransactions;
    } catch (e) {
      print('Error getting transactions by month: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get transactions for a user in a year
  Future<List<TransactionModel>> getUserTransactionsByYear(
    String userId,
    int year,
  ) async {
    try {
      final startOfYear = DateTime(year, 1, 1);
      final endOfYear = DateTime(year, 12, 31, 23, 59, 59);

      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear),
          )
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfYear))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting transactions by year: $e');
      return [];
    }
  }

  // Get today's transactions summary
  Future<Map<String, double>> getTodaysSummary(String userId) async {
    final today = DateTime.now();
    final transactions = await getUserTransactionsByDate(userId, today);

    double totalIncome = 0;
    double totalExpense = 0;

    for (var transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        totalIncome += transaction.amount;
      } else {
        totalExpense += transaction.amount;
      }
    }

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': totalIncome - totalExpense,
    };
  }

  // Get monthly summary
  Future<Map<String, double>> getMonthlySummary(
    String userId,
    int month,
    int year,
  ) async {
    final transactions = await getUserTransactionsByMonth(userId, month, year);

    double totalIncome = 0;
    double totalExpense = 0;

    for (var transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        totalIncome += transaction.amount;
      } else {
        totalExpense += transaction.amount;
      }
    }

    return {
      'income': totalIncome,
      'expense': totalExpense,
      'balance': totalIncome - totalExpense,
    };
  }

  // Get category breakdown for a month
  Future<Map<String, Map<String, double>>> getCategoryBreakdown(
    String userId,
    int month,
    int year,
  ) async {
    final transactions = await getUserTransactionsByMonth(userId, month, year);

    Map<String, double> incomeByCategory = {};
    Map<String, double> expenseByCategory = {};

    for (var transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        incomeByCategory[transaction.category] =
            (incomeByCategory[transaction.category] ?? 0) + transaction.amount;
      } else {
        expenseByCategory[transaction.category] =
            (expenseByCategory[transaction.category] ?? 0) + transaction.amount;
      }
    }

    return {'income': incomeByCategory, 'expense': expenseByCategory};
  }
}
