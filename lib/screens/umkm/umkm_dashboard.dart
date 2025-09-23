import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import 'transactions_screen.dart';
import 'reports_screen.dart';

class UmkmDashboard extends StatefulWidget {
  const UmkmDashboard({super.key});

  @override
  State<UmkmDashboard> createState() => _UmkmDashboardState();
}

class _UmkmDashboardState extends State<UmkmDashboard> {
  final TransactionService _transactionService = TransactionService();
  UserModel? _currentUser;
  Map<String, double>? _todaysSummary;
  Map<String, double>? _monthlySummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    print('Loading user data...');
    final authService = Provider.of<AuthService>(context, listen: false);
    final userData = await authService.getCurrentUserData();

    if (userData != null) {
      print('User data loaded: ${userData.id}, ${userData.name}');
      setState(() {
        _currentUser = userData;
      });
      await _loadSummaryData();
    } else {
      print('No user data found');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadSummaryData() async {
    if (_currentUser == null) {
      print('Current user is null, cannot load summary data');
      return;
    }

    print('Loading summary data for user: ${_currentUser!.id}');

    try {
      final todaysSummary = await _transactionService.getTodaysSummary(
        _currentUser!.id,
      );
      print('Today\'s summary: $todaysSummary');

      final now = DateTime.now();
      final monthlySummary = await _transactionService.getMonthlySummary(
        _currentUser!.id,
        now.month,
        now.year,
      );
      print('Monthly summary: $monthlySummary');

      setState(() {
        _todaysSummary = todaysSummary;
        _monthlySummary = monthlySummary;
      });
    } catch (e) {
      print('Error loading summary data: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  void _navigateToTransactions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TransactionsScreen()),
    );
  }

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReportsScreen()),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin untuk keluar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _signOut();
    }
  }

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard UMKM', style: TextStyle(fontSize: 18)),
            if (_currentUser != null)
              Text(
                _currentUser!.businessName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (String value) {
              if (value == 'logout') {
                _showLogoutConfirmation();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSummaryData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat datang, ${_currentUser?.name ?? ""}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat(
                              'EEEE, dd MMMM yyyy',
                              'id_ID',
                            ).format(DateTime.now()),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Today's Summary
                    const Text(
                      'Ringkasan Hari Ini',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildSummaryCard(
                            'Pemasukan',
                            _todaysSummary?['income'] ?? 0,
                            Colors.green,
                            Icons.arrow_upward,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: _buildSummaryCard(
                            'Pengeluaran',
                            _todaysSummary?['expense'] ?? 0,
                            Colors.red,
                            Icons.arrow_downward,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildSummaryCard(
                      'Saldo Hari Ini',
                      _todaysSummary?['balance'] ?? 0,
                      (_todaysSummary?['balance'] ?? 0) >= 0
                          ? Colors.blue
                          : Colors.orange,
                      Icons.account_balance_wallet,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 20),

                    // Monthly Summary
                    const Text(
                      'Ringkasan Bulan Ini',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildSummaryCard(
                            'Total Pemasukan',
                            _monthlySummary?['income'] ?? 0,
                            Colors.green.shade600,
                            Icons.trending_up,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: _buildSummaryCard(
                            'Total Pengeluaran',
                            _monthlySummary?['expense'] ?? 0,
                            Colors.red.shade600,
                            Icons.trending_down,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildSummaryCard(
                      'Keuntungan Bulan Ini',
                      _monthlySummary?['balance'] ?? 0,
                      (_monthlySummary?['balance'] ?? 0) >= 0
                          ? Colors.blue.shade600
                          : Colors.orange.shade600,
                      Icons.analytics,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 30),

                    // Action Buttons
                    const Text(
                      'Menu Utama',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildActionButton(
                      'Lihat Transaksi',
                      Icons.list_alt,
                      Colors.blue.shade600,
                      _navigateToTransactions,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 10),
                    _buildActionButton(
                      'Laporan Keuangan',
                      Icons.bar_chart,
                      Colors.purple.shade600,
                      _navigateToReports,
                      isFullWidth: true,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    IconData icon, {
    bool isFullWidth = false,
  }) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
    );

    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
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
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormatter.format(amount),
            style: TextStyle(
              fontSize: isFullWidth ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isFullWidth = false,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
