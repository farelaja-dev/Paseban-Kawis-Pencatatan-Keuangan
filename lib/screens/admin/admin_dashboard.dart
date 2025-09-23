import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../models/user_model.dart';

import '../auth/login_screen.dart';
import 'admin_umkm_list.dart';
import 'admin_reports.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ReportService _reportService = ReportService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _consolidatedSummary;
  List<UserModel> _umkmList = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load consolidated summary
      final summary = await _reportService.getConsolidatedSummary(
        _selectedMonth.month,
        _selectedMonth.year,
      );

      // Load UMKM list - First try to get all users to debug
      final allUsersSnapshot = await _firestore.collection('users').get();

      print('All users in database: ${allUsersSnapshot.docs.length}');

      // Try different queries to find UMKM users
      final umkmSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'umkm')
          .get();

      print('Users with role = "umkm": ${umkmSnapshot.docs.length}');

      // Also try case variations
      final umkmUpperSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'UMKM')
          .get();

      print('Users with role = "UMKM": ${umkmUpperSnapshot.docs.length}');

      // Combine all UMKM documents
      List<QueryDocumentSnapshot> allUmkmDocs = [
        ...umkmSnapshot.docs,
        ...umkmUpperSnapshot.docs,
      ];

      // Filter active ones (be more tolerant with isActive field)
      final activeUmkmDocs = allUmkmDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Consider missing isActive field as true for backward compatibility
        final isActive = data['isActive'];
        return isActive == null || isActive == true;
      }).toList();

      print('Active UMKM documents: ${activeUmkmDocs.length}');

      final umkmList = <UserModel>[];

      // Parse documents with error handling
      for (var doc in activeUmkmDocs) {
        try {
          final userModel = UserModel.fromFirestore(doc);
          umkmList.add(userModel);
        } catch (e) {
          print('Error parsing UMKM document ${doc.id}: $e');
          // Skip this document but continue with others
        }
      }

      print('UMKM Query Results:');
      print('Total UMKM documents found: ${umkmSnapshot.docs.length}');
      for (var doc in umkmSnapshot.docs) {
        final data = doc.data();
        print(
          'UMKM: ${data['name']} - Role: ${data['role']} - Active: ${data['isActive']}',
        );
      }
      print('Parsed UMKM list length: ${umkmList.length}');

      setState(() {
        _consolidatedSummary = summary;
        _umkmList = umkmList;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showMonthPicker(context, _selectedMonth);
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
      });
      await _loadDashboardData();
    }
  }

  Future<void> _signOut() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
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
      ),
    );

    if (shouldLogout == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  void _navigateToUmkmList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminUmkmList()),
    );
  }

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminReports()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
    );
    final monthFormatter = DateFormat('MMMM yyyy', 'id_ID');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 16,
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard Admin', style: TextStyle(fontSize: 18)),
            Text(
              'UMKM Kalibaru Manis',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            icon: Icon(Icons.more_vert, color: Colors.purple.shade100),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Keluar'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period Selector
                    Card(
                      elevation: 2,
                      child: InkWell(
                        onTap: _selectMonth,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Periode Laporan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    monthFormatter.format(_selectedMonth),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.calendar_month,
                                color: Colors.purple,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Overview Cards
                    const Text(
                      'Ringkasan UMKM',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildOverviewCard(
                            'Total UMKM',
                            '${_umkmList.length}',
                            Icons.business,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildOverviewCard(
                            'UMKM Aktif',
                            '${_consolidatedSummary?['activeUMKMs'] ?? 0}',
                            Icons.trending_up,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildOverviewCard(
                            'UMKM Untung',
                            '${_consolidatedSummary?['profitableUMKMs'] ?? 0}',
                            Icons.monetization_on,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildOverviewCard(
                            'Ratio Untung',
                            '${_calculateProfitRatio()}%',
                            Icons.analytics,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Financial Summary
                    const Text(
                      'Ringkasan Keuangan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFinancialCard(
                      'Total Pemasukan',
                      _consolidatedSummary?['totalIncome'] ?? 0,
                      Colors.green,
                      Icons.arrow_upward,
                      currencyFormatter,
                    ),
                    const SizedBox(height: 8),
                    _buildFinancialCard(
                      'Total Pengeluaran',
                      _consolidatedSummary?['totalExpense'] ?? 0,
                      Colors.red,
                      Icons.arrow_downward,
                      currencyFormatter,
                    ),
                    const SizedBox(height: 8),
                    _buildFinancialCard(
                      'Keuntungan Bersih',
                      _consolidatedSummary?['netProfit'] ?? 0,
                      (_consolidatedSummary?['netProfit'] ?? 0) >= 0
                          ? Colors.blue
                          : Colors.orange,
                      Icons.account_balance,
                      currencyFormatter,
                    ),
                    const SizedBox(height: 20),

                    // Average Performance
                    const Text(
                      'Rata-rata Kinerja',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildAverageItem(
                              'Rata-rata Pemasukan per UMKM',
                              _consolidatedSummary?['averageIncome'] ?? 0,
                              currencyFormatter,
                              Icons.trending_up,
                              Colors.green,
                            ),
                            const Divider(),
                            _buildAverageItem(
                              'Rata-rata Pengeluaran per UMKM',
                              _consolidatedSummary?['averageExpense'] ?? 0,
                              currencyFormatter,
                              Icons.trending_down,
                              Colors.red,
                            ),
                            const Divider(),
                            _buildAverageItem(
                              'Rata-rata Keuntungan per UMKM',
                              (_consolidatedSummary?['averageIncome'] ?? 0) -
                                  (_consolidatedSummary?['averageExpense'] ??
                                      0),
                              currencyFormatter,
                              Icons.account_balance_wallet,
                              Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Actions
                    const Text(
                      'Menu Admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            'Daftar UMKM',
                            'Kelola data UMKM',
                            Icons.business,
                            Colors.blue,
                            _navigateToUmkmList,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            'Laporan Lengkap',
                            'Lihat analisis detail',
                            Icons.analytics,
                            Colors.purple,
                            _navigateToReports,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(
    String title,
    double amount,
    Color color,
    IconData icon,
    NumberFormat formatter,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageItem(
    String label,
    double amount,
    NumberFormat formatter,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Flexible(
          child: Text(
            _formatCompactCurrency(amount),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
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

  String _calculateProfitRatio() {
    final activeUMKMs = _consolidatedSummary?['activeUMKMs'] ?? 0;
    final profitableUMKMs = _consolidatedSummary?['profitableUMKMs'] ?? 0;

    print('DEBUG Ratio: Active=$activeUMKMs, Profitable=$profitableUMKMs');

    if (activeUMKMs == 0) return '0';

    final ratio = (profitableUMKMs / activeUMKMs) * 100;
    print('DEBUG Ratio Result: ${ratio.toStringAsFixed(1)}%');
    return ratio.toStringAsFixed(1);
  }
}

// Helper function for month picker
Future<DateTime?> showMonthPicker(BuildContext context, DateTime initialDate) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => _MonthPickerDialog(initialDate: initialDate),
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

    final currentYear = DateTime.now().year;
    final years = List.generate(5, (index) => currentYear - index);

    return AlertDialog(
      title: const Text('Pilih Periode'),
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
                            ? Colors.purple.shade600
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
