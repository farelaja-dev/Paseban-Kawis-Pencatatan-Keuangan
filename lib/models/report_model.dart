import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String userId;
  final int month;
  final int year;
  final double totalIncome;
  final double totalExpense;
  final double netProfit;
  final Map<String, double> incomeByCategory;
  final Map<String, double> expenseByCategory;
  final DateTime generatedAt;
  final int transactionCount;

  ReportModel({
    required this.id,
    required this.userId,
    required this.month,
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.generatedAt,
    required this.transactionCount,
  });

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      month: data['month'] ?? 0,
      year: data['year'] ?? 0,
      totalIncome: (data['totalIncome'] ?? 0).toDouble(),
      totalExpense: (data['totalExpense'] ?? 0).toDouble(),
      netProfit: (data['netProfit'] ?? 0).toDouble(),
      incomeByCategory: Map<String, double>.from(
        (data['incomeByCategory'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0).toDouble()),
        ),
      ),
      expenseByCategory: Map<String, double>.from(
        (data['expenseByCategory'] ?? {}).map(
          (key, value) => MapEntry(key, (value ?? 0).toDouble()),
        ),
      ),
      generatedAt: (data['generatedAt'] as Timestamp).toDate(),
      transactionCount: data['transactionCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'month': month,
      'year': year,
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'netProfit': netProfit,
      'incomeByCategory': incomeByCategory,
      'expenseByCategory': expenseByCategory,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'transactionCount': transactionCount,
    };
  }

  String get periodString => '$month/$year';

  String get monthName {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  bool get isProfitable => netProfit > 0;

  double get profitMargin =>
      totalIncome > 0 ? (netProfit / totalIncome) * 100 : 0;
}

class YearlyReportModel {
  final String id;
  final String userId;
  final int year;
  final double totalIncome;
  final double totalExpense;
  final double netProfit;
  final List<ReportModel> monthlyReports;
  final DateTime generatedAt;

  YearlyReportModel({
    required this.id,
    required this.userId,
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.monthlyReports,
    required this.generatedAt,
  });

  factory YearlyReportModel.fromMonthlyReports(
    String userId,
    int year,
    List<ReportModel> monthlyReports,
  ) {
    double totalIncome = 0;
    double totalExpense = 0;

    for (var report in monthlyReports) {
      totalIncome += report.totalIncome;
      totalExpense += report.totalExpense;
    }

    return YearlyReportModel(
      id: '${userId}_$year',
      userId: userId,
      year: year,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netProfit: totalIncome - totalExpense,
      monthlyReports: monthlyReports,
      generatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'year': year,
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'netProfit': netProfit,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  bool get isProfitable => netProfit > 0;

  double get profitMargin =>
      totalIncome > 0 ? (netProfit / totalIncome) * 100 : 0;
}
