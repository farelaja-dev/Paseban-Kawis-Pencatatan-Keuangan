import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class AdminUmkmList extends StatefulWidget {
  const AdminUmkmList({super.key});

  @override
  State<AdminUmkmList> createState() => _AdminUmkmListState();
}

class _AdminUmkmListState extends State<AdminUmkmList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<UserModel> _umkmList = [];
  List<UserModel> _filteredUmkmList = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUmkmList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUmkmList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'umkm')
          .get();

      final umkmList = <UserModel>[];

      // Parse documents with error handling
      for (var doc in snapshot.docs) {
        try {
          final userModel = UserModel.fromFirestore(doc);
          umkmList.add(userModel);
        } catch (e) {
          print('Error parsing UMKM document ${doc.id}: $e');
          // Skip this document but continue with others
        }
      }

      // Sort in memory instead of in query to avoid composite index requirement
      umkmList.sort((a, b) {
        try {
          return b.createdAt.compareTo(
            a.createdAt,
          ); // Descending order (newest first)
        } catch (e) {
          print('Error sorting UMKM list: $e');
          return 0; // Keep original order if comparison fails
        }
      });

      print('UMKM List Page - Query Results:');
      print('Total UMKM documents found: ${snapshot.docs.length}');
      for (var doc in snapshot.docs) {
        final data = doc.data();
        print(
          'UMKM: ${data['name']} - Role: ${data['role']} - Active: ${data['isActive']}',
        );
      }

      setState(() {
        _umkmList = umkmList;
        _filteredUmkmList = umkmList;
      });
    } catch (e) {
      print('Error loading UMKM list: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _filterUmkmList(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredUmkmList = _umkmList;
        print('Search cleared - showing all ${_umkmList.length} UMKM');
      } else {
        _filteredUmkmList = _umkmList.where((umkm) {
          final matchName = umkm.name.toLowerCase().contains(
            query.toLowerCase(),
          );
          final matchBusiness = umkm.businessName.toLowerCase().contains(
            query.toLowerCase(),
          );
          final matchEmail = umkm.email.toLowerCase().contains(
            query.toLowerCase(),
          );

          return matchName || matchBusiness || matchEmail;
        }).toList();

        print(
          'Search query: "$query" - Found ${_filteredUmkmList.length} results from ${_umkmList.length} total',
        );
        if (_filteredUmkmList.isNotEmpty) {
          print(
            'First result: ${_filteredUmkmList.first.name} (${_filteredUmkmList.first.businessName})',
          );
        }
      }
    });
  }

  void _showUmkmDetails(UserModel umkm) {
    showDialog(
      context: context,
      builder: (context) => _UmkmDetailDialog(umkm: umkm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
        title: const Text('Daftar UMKM'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUmkmList),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari berdasarkan nama, bisnis, atau email...',
                prefixIcon: Icon(
                  Icons.search,
                  color: _searchQuery.isNotEmpty ? Colors.purple : Colors.grey,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterUmkmList('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _searchQuery.isNotEmpty
                        ? Colors.purple
                        : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.purple, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: _filterUmkmList,
            ),
          ),

          // Statistics
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total UMKM',
                    _umkmList.length.toString(),
                    Colors.blue,
                    Icons.business,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    _searchQuery.isEmpty ? 'Aktif' : 'Hasil',
                    _searchQuery.isEmpty
                        ? _umkmList.where((u) => u.isActive).length.toString()
                        : _filteredUmkmList.length.toString(),
                    _searchQuery.isEmpty ? Colors.green : Colors.orange,
                    _searchQuery.isEmpty ? Icons.check_circle : Icons.search,
                  ),
                ),
              ],
            ),
          ),

          // UMKM List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUmkmList.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadUmkmList,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredUmkmList.length,
                      itemBuilder: (context, index) {
                        final umkm = _filteredUmkmList[index];
                        return _buildUmkmCard(umkm);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildUmkmCard(UserModel umkm) {
    final dateFormatter = DateFormat('dd MMM yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showUmkmDetails(umkm),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: umkm.isActive ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Business name
                  Expanded(
                    child: Text(
                      umkm.businessName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Action button
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'details') {
                        _showUmkmDetails(umkm);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            const Icon(Icons.info),
                            const SizedBox(width: 8),
                            Text('Detail'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Owner name
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      umkm.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Email
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      umkm.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Phone
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      umkm.phone,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Registration date and status
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Terdaftar: ${dateFormatter.format(umkm.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: umkm.isActive ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        umkm.isActive ? 'Aktif' : 'Nonaktif',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.business,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Tidak ada UMKM ditemukan'
                : 'Belum ada UMKM terdaftar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Coba kata kunci lain',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

class _UmkmDetailDialog extends StatelessWidget {
  final UserModel umkm;

  const _UmkmDetailDialog({required this.umkm});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd MMMM yyyy, HH:mm');

    return AlertDialog(
      title: Text(umkm.businessName),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Nama Pemilik', umkm.name),
            _buildDetailRow('Email', umkm.email),
            _buildDetailRow('Telepon', umkm.phone),
            _buildDetailRow('Alamat', umkm.address),
            _buildDetailRow(
              'Tanggal Daftar',
              dateFormatter.format(umkm.createdAt),
            ),
            _buildDetailRow(
              'Status',
              umkm.isActive ? 'Aktif' : 'Nonaktif',
              textColor: umkm.isActive ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: textColor ?? Colors.black87,
                fontWeight: textColor != null
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
