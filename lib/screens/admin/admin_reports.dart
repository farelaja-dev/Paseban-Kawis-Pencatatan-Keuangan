import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/report_service.dart';
import '../../models/report_model.dart';

class AdminReports extends StatefulWidget {
  const AdminReports({super.key});

  @override
  State<AdminReports> createState() => _AdminReportsState();
}

class _AdminReportsState extends State<AdminReports>
    with TickerProviderStateMixin {
  final ReportService _reportService = ReportService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ReportModel> _reports = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();
  late TabController _tabController;
  Map<String, String> _umkmNames = {}; // Cache untuk nama UMKM

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUmkmNames(List<ReportModel> reports) async {
    try {
      final userIds = reports.map((report) => report.userId).toSet();

      for (String userId in userIds) {
        if (!_umkmNames.containsKey(userId)) {
          final userDoc = await _firestore
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            _umkmNames[userId] =
                userData['businessName'] ?? userData['name'] ?? 'UMKM';
          } else {
            _umkmNames[userId] = 'UMKM $userId';
          }
        }
      }
    } catch (e) {
      print('Error loading UMKM names: $e');
    }
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _reportService.getAllMonthlyReports(
        _selectedMonth.month,
        _selectedMonth.year,
      );
      await _loadUmkmNames(reports); // Load UMKM names
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading reports: $e')));
      }
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
      });
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          'Laporan Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Grafik'),
            Tab(text: 'Top 5 UMKM'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _selectMonth,
            tooltip: 'Pilih Bulan',
            color: Colors.white,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildChartTab(),
                _buildTopUmkmTab(),
              ],
            ),
    );
  }

  Widget _buildSummaryTab() {
    final totalIncome = _reports.fold(0.0, (sum, r) => sum + r.totalIncome);
    final totalExpense = _reports.fold(0.0, (sum, r) => sum + r.totalExpense);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Laporan Bulan ${DateFormat.yMMMM('id_ID').format(_selectedMonth)}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Total Pendapatan',
                  _formatCompactCurrency(totalIncome),
                  Icons.arrow_upward,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard(
                  'Total Pengeluaran',
                  _formatCompactCurrency(totalExpense),
                  Icons.arrow_downward,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Net Income',
                  _formatCompactCurrency(totalIncome - totalExpense),
                  Icons.account_balance_wallet,
                  (totalIncome - totalExpense) >= 0 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewCard(
                  'Total Transaksi',
                  '${_reports.length}',
                  Icons.receipt_long,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartTab() {
    if (_reports.isEmpty) {
      return const Center(child: Text('Tidak ada data untuk ditampilkan'));
    }

    final incomeData = <String, double>{};
    final expenseData = <String, double>{};

    for (var report in _reports) {
      // Aggregate income by category from all reports
      report.incomeByCategory.forEach((category, amount) {
        incomeData[category] = (incomeData[category] ?? 0) + amount;
      });

      // Aggregate expense by category from all reports
      report.expenseByCategory.forEach((category, amount) {
        expenseData[category] = (expenseData[category] ?? 0) + amount;
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (incomeData.isNotEmpty) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Pendapatan per Kategori',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: incomeData.entries
                              .map(
                                (entry) => PieChartSectionData(
                                  color: Colors.green.shade300,
                                  value: entry.value,
                                  title:
                                      '${entry.key}\n${NumberFormat.compact().format(entry.value)}',
                                  radius: 80,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (expenseData.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Pengeluaran per Kategori',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: expenseData.entries
                              .map(
                                (entry) => PieChartSectionData(
                                  color: Colors.red.shade300,
                                  value: entry.value,
                                  title:
                                      '${entry.key}\n${NumberFormat.compact().format(entry.value)}',
                                  radius: 80,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopUmkmTab() {
    if (_reports.isEmpty) {
      return const Center(child: Text('Tidak ada data untuk ditampilkan'));
    }

    // Group by userId and calculate net income
    final umkmPerformance = <String, double>{};
    final umkmTransactionCount = <String, int>{};

    for (var report in _reports) {
      final userId = report.userId;
      umkmPerformance[userId] =
          (umkmPerformance[userId] ?? 0) + report.netProfit;
      umkmTransactionCount[userId] =
          (umkmTransactionCount[userId] ?? 0) + report.transactionCount;
    }

    // Sort by performance (net income)
    final sortedUmkm = umkmPerformance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 5
    final top5 = sortedUmkm.take(5).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 5 UMKM Terbaik',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: top5.length,
              itemBuilder: (context, index) {
                final entry = top5[index];
                final userId = entry.key;
                final netIncome = entry.value;
                final transactionCount = umkmTransactionCount[userId] ?? 0;
                final umkmName = _umkmNames[userId] ?? 'UMKM $userId';

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getRankColor(index),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                umkmName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(netIncome),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: netIncome >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              Text(
                                'Total Transaksi: $transactionCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.trending_up,
                          color: netIncome >= 0 ? Colors.green : Colors.red,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompactCurrency(double amount) {
    if (amount.abs() >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)}Jt';
    } else if (amount.abs() >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}rb';
    } else {
      return 'Rp ${amount.toStringAsFixed(0)}';
    }
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber; // Gold
      case 1:
        return Colors.grey; // Silver
      case 2:
        return Colors.brown; // Bronze
      default:
        return Colors.blue;
    }
  }
}
