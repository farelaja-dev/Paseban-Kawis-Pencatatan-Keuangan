import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../services/transaction_service.dart';
import '../../models/report_model.dart';
import '../../models/transaction_model.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final ReportService _reportService = ReportService();
  final TransactionService _transactionService = TransactionService();
  late TabController _tabController;

  String? _userId;
  DateTime _selectedMonth = DateTime.now();
  int _selectedYear = DateTime.now().year;

  ReportModel? _monthlyReport;
  YearlyReportModel? _yearlyReport;
  bool _isLoadingMonthly = true;
  bool _isLoadingYearly = true;

  // Stream subscriptions for real-time updates
  late Stream<List<TransactionModel>> _transactionsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userData = await authService.getCurrentUserData();

    if (userData != null) {
      _userId = userData.id;
      // Set up transaction stream for real-time updates
      _transactionsStream = _transactionService.getUserTransactions(_userId!);
      await _loadReports();

      // Listen to transaction changes for auto-refresh
      _setupTransactionListener();
    }
  }

  void _setupTransactionListener() {
    if (_userId != null) {
      _transactionsStream.listen((_) {
        // When transactions change, reload reports after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _loadReports();
          }
        });
      });
    }
  }

  Future<void> _loadReports() async {
    if (_userId == null) {
      print('User ID is null, cannot load reports');
      return;
    }

    print('Loading reports for user: $_userId');

    setState(() {
      _isLoadingMonthly = true;
      _isLoadingYearly = true;
    });

    try {
      // Force regenerate monthly report to get latest data
      print(
        'Force generating monthly report for ${_selectedMonth.month}/${_selectedMonth.year}',
      );
      final monthlyReport = await _reportService.generateMonthlyReport(
        _userId!,
        _selectedMonth.month,
        _selectedMonth.year,
      );

      // Load yearly report
      print('Loading yearly report for $_selectedYear');
      final yearlyReport = await _reportService.getYearlyReport(
        _userId!,
        _selectedYear,
      );

      print('Monthly report: ${monthlyReport != null ? 'Found' : 'NULL'}');
      if (monthlyReport != null) {
        print(
          'Monthly report data - Income: ${monthlyReport.totalIncome}, Expense: ${monthlyReport.totalExpense}, Transactions: ${monthlyReport.transactionCount}',
        );
      }

      print('Yearly report: ${yearlyReport != null ? 'Found' : 'NULL'}');

      setState(() {
        _monthlyReport = monthlyReport;
        _yearlyReport = yearlyReport;
      });
    } catch (e) {
      print('Error loading reports: $e');
      print('Stack trace: ${StackTrace.current}');
    }

    setState(() {
      _isLoadingMonthly = false;
      _isLoadingYearly = false;
    });
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showMonthPicker(context, _selectedMonth);
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
      });
      await _loadReports();
    }
  }

  Future<void> _selectYear() async {
    final int? picked = await showYearPicker(context, _selectedYear);
    if (picked != null && picked != _selectedYear) {
      setState(() {
        _selectedYear = picked;
      });
      await _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        title: const Text('Laporan Keuangan'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Bulanan'),
            Tab(text: 'Tahunan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMonthlyReport(), _buildYearlyReport()],
      ),
    );
  }

  Widget _buildMonthlyReport() {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
    );
    final monthFormatter = DateFormat('MMMM yyyy', 'id_ID');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector
          Card(
            child: InkWell(
              onTap: _selectMonth,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Periode: ${monthFormatter.format(_selectedMonth)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.calendar_month),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoadingMonthly)
            const Center(child: CircularProgressIndicator())
          else if (_monthlyReport == null) ...[
            _buildNoDataCard('Belum ada data untuk bulan ini'),
            // Debug info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Info:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text('User ID: $_userId'),
                    Text('Month: ${_selectedMonth.month}'),
                    Text('Year: ${_selectedMonth.year}'),
                    Text('Monthly Report: $_monthlyReport'),
                    Text('Loading: $_isLoadingMonthly'),
                  ],
                ),
              ),
            ),
          ] else
            ..._buildMonthlyReportWidgets(_monthlyReport!, currencyFormatter),
        ],
      ),
    );
  }

  List<Widget> _buildMonthlyReportWidgets(
    ReportModel report,
    NumberFormat formatter,
  ) {
    return [
      // Summary Cards
      Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Pemasukan',
              report.totalIncome,
              Colors.green,
              Icons.trending_up,
              formatter,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Total Pengeluaran',
              report.totalExpense,
              Colors.red,
              Icons.trending_down,
              formatter,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _buildSummaryCard(
        report.isProfitable ? 'Keuntungan' : 'Kerugian',
        report.netProfit,
        report.isProfitable ? Colors.blue : Colors.orange,
        report.isProfitable ? Icons.trending_up : Icons.trending_down,
        formatter,
        isFullWidth: true,
      ),
      const SizedBox(height: 16),

      // Statistics
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statistik',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildStatItem('Jumlah Transaksi', '${report.transactionCount}'),
              _buildStatItem(
                'Margin Keuntungan',
                '${report.profitMargin.toStringAsFixed(1)}%',
              ),
              _buildStatItem('Periode', report.monthName),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Combined Income vs Expense Chart
      if (report.totalIncome > 0 || report.totalExpense > 0) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perbandingan Pemasukan vs Pengeluaran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                // Use LayoutBuilder to handle different screen sizes
                LayoutBuilder(
                  builder: (context, constraints) {
                    // If width is too small, use vertical layout
                    if (constraints.maxWidth < 350) {
                      return Column(
                        children: [
                          // Pie Chart
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sections:
                                    _createIncomeExpenseComparisonSections(
                                      report.totalIncome,
                                      report.totalExpense,
                                    ),
                                centerSpaceRadius: 40,
                                sectionsSpace: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Legend and Details
                          _buildCompactLegend(report, formatter),
                        ],
                      );
                    } else {
                      // Use horizontal layout for larger screens
                      return SizedBox(
                        height: 220,
                        child: Row(
                          children: [
                            // Pie Chart
                            Expanded(
                              flex: 3,
                              child: PieChart(
                                PieChartData(
                                  sections:
                                      _createIncomeExpenseComparisonSections(
                                        report.totalIncome,
                                        report.totalExpense,
                                      ),
                                  centerSpaceRadius: 40,
                                  sectionsSpace: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Legend and Details
                            Expanded(
                              flex: 2,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLegendItem(
                                      'Pemasukan',
                                      Colors.green.shade600,
                                      _formatCompactCurrency(
                                        report.totalIncome,
                                      ),
                                      _calculatePercentage(
                                        report.totalIncome,
                                        report.totalIncome +
                                            report.totalExpense,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildLegendItem(
                                      'Pengeluaran',
                                      Colors.red.shade600,
                                      _formatCompactCurrency(
                                        report.totalExpense,
                                      ),
                                      _calculatePercentage(
                                        report.totalExpense,
                                        report.totalIncome +
                                            report.totalExpense,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildProfitBox(report, formatter),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],

      // Detailed Category Breakdown
      if (report.incomeByCategory.isNotEmpty ||
          report.expenseByCategory.isNotEmpty) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rincian per Kategori',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (report.incomeByCategory.isNotEmpty) ...[
                  const Text(
                    'Pemasukan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildCategoryList(report.incomeByCategory, formatter),
                  if (report.expenseByCategory.isNotEmpty)
                    const SizedBox(height: 16),
                ],
                if (report.expenseByCategory.isNotEmpty) ...[
                  const Text(
                    'Pengeluaran',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildCategoryList(report.expenseByCategory, formatter),
                ],
              ],
            ),
          ),
        ),
      ],
    ];
  }

  Widget _buildYearlyReport() {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year Selector
          Card(
            child: InkWell(
              onTap: _selectYear,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tahun: $_selectedYear',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoadingYearly)
            const Center(child: CircularProgressIndicator())
          else if (_yearlyReport == null)
            _buildNoDataCard('Belum ada data untuk tahun ini')
          else
            ..._buildYearlyReportWidgets(_yearlyReport!, currencyFormatter),
        ],
      ),
    );
  }

  List<Widget> _buildYearlyReportWidgets(
    YearlyReportModel report,
    NumberFormat formatter,
  ) {
    return [
      // Summary Cards
      Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Pemasukan',
              report.totalIncome,
              Colors.green,
              Icons.trending_up,
              formatter,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Total Pengeluaran',
              report.totalExpense,
              Colors.red,
              Icons.trending_down,
              formatter,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _buildSummaryCard(
        report.isProfitable ? 'Keuntungan' : 'Kerugian',
        report.netProfit,
        report.isProfitable ? Colors.blue : Colors.orange,
        report.isProfitable ? Icons.trending_up : Icons.trending_down,
        formatter,
        isFullWidth: true,
      ),
      const SizedBox(height: 16),

      // Monthly Trend Chart
      if (report.monthlyReports.isNotEmpty) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tren Bulanan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: LineChart(_createLineChartData(report.monthlyReports)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],

      // Statistics
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statistik Tahunan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildStatItem(
                'Bulan dengan Data',
                '${report.monthlyReports.length}',
              ),
              _buildStatItem(
                'Margin Keuntungan',
                '${report.profitMargin.toStringAsFixed(1)}%',
              ),
              _buildClickableStatItem(
                'Rata-rata Pemasukan per Bulan',
                formatter.format(report.totalIncome / 12),
                'Rata-rata Pemasukan per Bulan',
                formatter.format(report.totalIncome / 12),
              ),
              _buildClickableStatItem(
                'Rata-rata Pengeluaran per Bulan',
                formatter.format(report.totalExpense / 12),
                'Rata-rata Pengeluaran per Bulan',
                formatter.format(report.totalExpense / 12),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
    NumberFormat formatter, {
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatter.format(amount),
            style: TextStyle(
              fontSize: isFullWidth ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableStatItem(
    String label,
    String value,
    String dialogTitle,
    String fullValue,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _showDetailDialog(dialogTitle, fullValue),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.visibility,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailDialog(String title, String value) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SelectableText(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoDataCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PieChartSectionData> _createIncomeExpenseComparisonSections(
    double totalIncome,
    double totalExpense,
  ) {
    final total = totalIncome + totalExpense;
    if (total == 0) return [];

    final incomePercentage = (totalIncome / total) * 100;
    final expensePercentage = (totalExpense / total) * 100;

    return [
      if (totalIncome > 0)
        PieChartSectionData(
          value: totalIncome,
          title: '${incomePercentage.toStringAsFixed(1)}%',
          color: Colors.green.shade600,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (totalExpense > 0)
        PieChartSectionData(
          value: totalExpense,
          title: '${expensePercentage.toStringAsFixed(1)}%',
          color: Colors.red.shade600,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
    ];
  }

  Widget _buildCompactLegend(ReportModel report, NumberFormat formatter) {
    return Row(
      children: [
        Expanded(
          child: _buildLegendItem(
            'Pemasukan',
            Colors.green.shade600,
            _formatCompactCurrency(report.totalIncome),
            _calculatePercentage(
              report.totalIncome,
              report.totalIncome + report.totalExpense,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLegendItem(
            'Pengeluaran',
            Colors.red.shade600,
            _formatCompactCurrency(report.totalExpense),
            _calculatePercentage(
              report.totalExpense,
              report.totalIncome + report.totalExpense,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfitBox(ReportModel report, NumberFormat formatter) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: report.isProfitable ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: report.isProfitable
              ? Colors.green.shade200
              : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.isProfitable ? 'Keuntungan' : 'Kerugian',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: report.isProfitable
                  ? Colors.green.shade800
                  : Colors.red.shade800,
            ),
          ),
          Text(
            _formatCompactCurrency(report.netProfit.abs()),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: report.isProfitable
                  ? Colors.green.shade800
                  : Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)}Jt';
    } else if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}rb';
    } else {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
      ).format(amount);
    }
  }

  Widget _buildLegendItem(
    String label,
    Color color,
    String value,
    String percentage,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                percentage,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _calculatePercentage(double value, double total) {
    if (total == 0) return '0.0%';
    final percentage = (value / total) * 100;
    return '${percentage.toStringAsFixed(1)}%';
  }

  List<Widget> _buildCategoryList(
    Map<String, double> data,
    NumberFormat formatter,
  ) {
    return data.entries.map((entry) {
      final percentage =
          (entry.value / data.values.fold(0.0, (sum, value) => sum + value)) *
          100;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatter.format(entry.value),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  LineChartData _createLineChartData(List<ReportModel> monthlyReports) {
    monthlyReports.sort((a, b) => a.month.compareTo(b.month));

    return LineChartData(
      gridData: const FlGridData(show: true),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              const months = [
                '',
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'Mei',
                'Jun',
                'Jul',
                'Agu',
                'Sep',
                'Okt',
                'Nov',
                'Des',
              ];
              if (value.toInt() >= 1 && value.toInt() <= 12) {
                return Text(
                  months[value.toInt()],
                  style: const TextStyle(fontSize: 10),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: true),
      lineBarsData: [
        // Income line
        LineChartBarData(
          spots: monthlyReports
              .map(
                (report) => FlSpot(report.month.toDouble(), report.totalIncome),
              )
              .toList(),
          color: Colors.green,
          barWidth: 3,
          isStrokeCapRound: true,
          belowBarData: BarAreaData(show: false),
        ),
        // Expense line
        LineChartBarData(
          spots: monthlyReports
              .map(
                (report) =>
                    FlSpot(report.month.toDouble(), report.totalExpense),
              )
              .toList(),
          color: Colors.red,
          barWidth: 3,
          isStrokeCapRound: true,
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }
}

// Helper functions for date pickers
Future<DateTime?> showMonthPicker(BuildContext context, DateTime initialDate) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => _MonthPickerDialog(initialDate: initialDate),
  );
}

Future<int?> showYearPicker(BuildContext context, int initialYear) {
  return showDialog<int>(
    context: context,
    builder: (context) => _YearPickerDialog(initialYear: initialYear),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initialDate;

  const _MonthPickerDialog({required this.initialDate});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int selectedYear;
  late int selectedMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = widget.initialDate.year;
    selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
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

    // Generate years from 2020 to 2030
    final years = <int>[];
    for (int year = 2030; year >= 2020; year--) {
      years.add(year);
    }

    return AlertDialog(
      title: const Text('Pilih Bulan'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: selectedYear,
              decoration: const InputDecoration(
                labelText: 'Tahun',
                border: OutlineInputBorder(),
              ),
              items: years.map((year) {
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedYear = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = month == selectedMonth;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedMonth = month;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue.shade600
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          months[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(DateTime(selectedYear, selectedMonth));
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _YearPickerDialog extends StatelessWidget {
  final int initialYear;

  const _YearPickerDialog({required this.initialYear});

  @override
  Widget build(BuildContext context) {
    // Generate years from 2020 to 2030
    final years = <int>[];
    for (int year = 2030; year >= 2020; year--) {
      years.add(year);
    }

    return AlertDialog(
      title: const Text('Pilih Tahun'),
      content: SizedBox(
        width: 200,
        height: 300,
        child: ListView.builder(
          itemCount: years.length,
          itemBuilder: (context, index) {
            final year = years[index];
            return ListTile(
              title: Text(year.toString()),
              onTap: () => Navigator.of(context).pop(year),
              selected: year == initialYear,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
