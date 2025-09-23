import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_model.dart';
import '../models/transaction_model.dart';
import 'transaction_service.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TransactionService _transactionService = TransactionService();

  // Generate monthly report
  Future<ReportModel?> generateMonthlyReport(
    String userId,
    int month,
    int year,
  ) async {
    try {
      print(
        'Generating monthly report for userId: $userId, month: $month, year: $year',
      );

      final transactions = await _transactionService.getUserTransactionsByMonth(
        userId,
        month,
        year,
      );

      print('Found ${transactions.length} transactions for report generation');

      double totalIncome = 0;
      double totalExpense = 0;
      Map<String, double> incomeByCategory = {};
      Map<String, double> expenseByCategory = {};

      for (var transaction in transactions) {
        print(
          'Processing transaction: ${transaction.description}, amount: ${transaction.amount}, type: ${transaction.type}',
        );

        if (transaction.type == TransactionType.income) {
          totalIncome += transaction.amount;
          incomeByCategory[transaction.category] =
              (incomeByCategory[transaction.category] ?? 0) +
              transaction.amount;
        } else {
          totalExpense += transaction.amount;
          expenseByCategory[transaction.category] =
              (expenseByCategory[transaction.category] ?? 0) +
              transaction.amount;
        }
      }

      print(
        'Report totals - Income: $totalIncome, Expense: $totalExpense, Net: ${totalIncome - totalExpense}',
      );

      final report = ReportModel(
        id: '${userId}_${month}_$year',
        userId: userId,
        month: month,
        year: year,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        netProfit: totalIncome - totalExpense,
        incomeByCategory: incomeByCategory,
        expenseByCategory: expenseByCategory,
        generatedAt: DateTime.now(),
        transactionCount: transactions.length,
      );

      // Save to Firestore
      await _firestore
          .collection('reports')
          .doc(report.id)
          .set(report.toFirestore());

      print('Report saved to Firestore with ID: ${report.id}');

      return report;
    } catch (e) {
      print('Error generating monthly report: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // Get monthly report (generate if not exists)
  Future<ReportModel?> getMonthlyReport(
    String userId,
    int month,
    int year,
  ) async {
    try {
      print(
        'Getting monthly report for userId: $userId, month: $month, year: $year',
      );

      final reportId = '${userId}_${month}_$year';
      final doc = await _firestore.collection('reports').doc(reportId).get();

      if (doc.exists) {
        print('Found existing report in Firestore');
        final existingReport = ReportModel.fromFirestore(doc);

        // Check if report is empty (no transactions), force regenerate
        if (existingReport.transactionCount == 0) {
          print(
            'Existing report has 0 transactions, checking if we have new transactions...',
          );
          final transactions = await _transactionService
              .getUserTransactionsByMonth(userId, month, year);

          if (transactions.isNotEmpty) {
            print(
              'Found ${transactions.length} transactions, regenerating report...',
            );
            return await generateMonthlyReport(userId, month, year);
          } else {
            print('No transactions found, keeping existing empty report');
          }
        }

        return existingReport;
      } else {
        print('No existing report found, generating new one...');
        // Generate new report if not exists
        return await generateMonthlyReport(userId, month, year);
      }
    } catch (e) {
      print('Error getting monthly report: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // Get yearly report
  Future<YearlyReportModel?> getYearlyReport(String userId, int year) async {
    try {
      List<ReportModel> monthlyReports = [];

      for (int month = 1; month <= 12; month++) {
        final report = await getMonthlyReport(userId, month, year);
        if (report != null) {
          monthlyReports.add(report);
        }
      }

      if (monthlyReports.isNotEmpty) {
        return YearlyReportModel.fromMonthlyReports(
          userId,
          year,
          monthlyReports,
        );
      }
      return null;
    } catch (e) {
      print('Error getting yearly report: $e');
      return null;
    }
  }

  // Get all UMKM users' monthly reports (for admin) - exclude admin reports
  Future<List<ReportModel>> getAllMonthlyReports(int month, int year) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .get();

      final allReports = snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .toList();

      // Filter out admin reports - only include UMKM reports
      final umkmReports = <ReportModel>[];

      for (var report in allReports) {
        try {
          // Check if this user is UMKM
          final userDoc = await _firestore
              .collection('users')
              .doc(report.userId)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            if (userData['role'] == 'umkm') {
              umkmReports.add(report);
            } else {
              print(
                'Excluding report from non-UMKM user: ${report.userId} (role: ${userData['role']})',
              );
            }
          }
        } catch (e) {
          print('Error checking user role for ${report.userId}: $e');
          // Skip this report if we can't verify the user
        }
      }

      print(
        'Total reports: ${allReports.length}, UMKM reports: ${umkmReports.length}',
      );
      return umkmReports;
    } catch (e) {
      print('Error getting all monthly reports: $e');
      return [];
    }
  }

  // Get reports for a specific user
  Future<List<ReportModel>> getUserReports(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('userId', isEqualTo: userId)
          .orderBy('year', descending: true)
          .orderBy('month', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting user reports: $e');
      return [];
    }
  }

  // Regenerate all reports for a user (useful after data correction)
  Future<bool> regenerateUserReports(String userId, int year) async {
    try {
      for (int month = 1; month <= 12; month++) {
        await generateMonthlyReport(userId, month, year);
      }
      return true;
    } catch (e) {
      print('Error regenerating user reports: $e');
      return false;
    }
  }

  // Get consolidated summary for admin dashboard
  Future<Map<String, dynamic>> getConsolidatedSummary(
    int month,
    int year,
  ) async {
    try {
      final reports = await getAllMonthlyReports(month, year);

      print('Consolidated Summary Debug:');
      print('Total reports found: ${reports.length}');
      for (var report in reports) {
        print(
          'Report - UserID: ${report.userId}, Income: ${report.totalIncome}, Expense: ${report.totalExpense}',
        );
      }

      double totalIncome = 0;
      double totalExpense = 0;

      // Get unique UMKM IDs to avoid counting duplicates
      Set<String> uniqueUmkmIds = reports.map((r) => r.userId).toSet();
      int activeUMKMs = uniqueUmkmIds.length;

      // Calculate profitable UMKMs by unique userId
      Set<String> profitableUmkmIds = {};

      for (var report in reports) {
        totalIncome += report.totalIncome;
        totalExpense += report.totalExpense;
        if (report.isProfitable) {
          profitableUmkmIds.add(report.userId);
        }
      }

      int profitableUMKMs = profitableUmkmIds.length;

      print('Unique UMKM IDs: $uniqueUmkmIds');
      print('Profitable UMKM IDs: $profitableUmkmIds');
      print('Active UMKMs: $activeUMKMs, Profitable UMKMs: $profitableUMKMs');

      return {
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'netProfit': totalIncome - totalExpense,
        'activeUMKMs': activeUMKMs,
        'profitableUMKMs': profitableUMKMs,
        'averageIncome': activeUMKMs > 0 ? totalIncome / activeUMKMs : 0,
        'averageExpense': activeUMKMs > 0 ? totalExpense / activeUMKMs : 0,
      };
    } catch (e) {
      print('Error getting consolidated summary: $e');
      return {};
    }
  }
}
