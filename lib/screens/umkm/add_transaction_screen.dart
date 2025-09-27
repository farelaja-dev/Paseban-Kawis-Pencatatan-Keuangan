import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction_model.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  TransactionType _selectedType = TransactionType.income;
  String _selectedCategory = '';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final TransactionService _transactionService = TransactionService();

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _populateFields();
    } else {
      _selectedCategory = TransactionModel.incomeCategories.first;
    }
  }

  void _populateFields() {
    final transaction = widget.transaction!;
    _descriptionController.text = transaction.description;
    _amountController.text = transaction.amount.toString();
    _notesController.text = transaction.notes ?? '';
    _selectedType = transaction.type;
    _selectedCategory = transaction.category;
    _selectedDate = transaction.date;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTypeChanged(TransactionType? type) {
    if (type != null) {
      setState(() {
        _selectedType = type;
        // Reset category when type changes
        _selectedCategory = type == TransactionType.income
            ? TransactionModel.incomeCategories.first
            : TransactionModel.expenseCategories.first;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        2030,
      ), // Memungkinkan pemilihan tanggal hingga tahun 2030
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = await authService.getCurrentUserData();

    if (currentUser == null) {
      setState(() => _isLoading = false);
      _showErrorDialog('User not found');
      return;
    }

    final transaction = TransactionModel(
      id: widget.transaction?.id ?? '',
      userId: currentUser.id,
      description: _descriptionController.text.trim(),
      amount: double.parse(_amountController.text),
      type: _selectedType,
      category: _selectedCategory,
      date: _selectedDate,
      createdAt: widget.transaction?.createdAt ?? DateTime.now(),
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    String? error;
    if (widget.transaction != null) {
      // Update existing transaction
      error = await _transactionService.updateTransaction(transaction);
    } else {
      // Add new transaction
      error = await _transactionService.addTransaction(transaction);
    }

    setState(() => _isLoading = false);

    if (error != null) {
      _showErrorDialog(error);
    } else {
      Navigator.pop(context, true);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transaction != null;
    final categories = _selectedType == TransactionType.income
        ? TransactionModel.incomeCategories
        : TransactionModel.expenseCategories;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        title: Text(isEditing ? 'Edit Transaksi' : 'Tambah Transaksi'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteDialog,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction Type
              Container(
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
                    const Text(
                      'Tipe Transaksi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<TransactionType>(
                            title: const Text('Pemasukan'),
                            subtitle: const Text('Uang masuk'),
                            value: TransactionType.income,
                            groupValue: _selectedType,
                            onChanged: _onTypeChanged,
                            activeColor: Colors.green,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<TransactionType>(
                            title: const Text('Pengeluaran'),
                            subtitle: const Text('Uang keluar'),
                            value: TransactionType.expense,
                            groupValue: _selectedType,
                            onChanged: _onTypeChanged,
                            activeColor: Colors.red,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Transaction Details
              Container(
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
                    const Text(
                      'Detail Transaksi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi Transaksi',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Deskripsi tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Jumlah (Rp)',
                        prefixIcon: Icon(
                          _selectedType == TransactionType.income
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: _selectedType == TransactionType.income
                              ? Colors.green
                              : Colors.red,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Jumlah tidak boleh kosong';
                        }
                        if (double.tryParse(value) == null ||
                            double.parse(value) <= 0) {
                          return 'Jumlah harus berupa angka positif';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category
                    DropdownButtonFormField<String>(
                      value: categories.contains(_selectedCategory)
                          ? _selectedCategory
                          : categories.first,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Pilih kategori';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          DateFormat(
                            'dd MMMM yyyy',
                            'id_ID',
                          ).format(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick date selection buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedDate = DateTime.now();
                            });
                          },
                          icon: Icon(Icons.today, size: 16),
                          label: Text(
                            'Hari Ini',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue.shade600,
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedDate = DateTime.now().add(
                                Duration(days: 1),
                              );
                            });
                          },
                          icon: Icon(Icons.skip_next, size: 16),
                          label: Text('Besok', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue.shade600,
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            final firstDayNextMonth = DateTime(
                              DateTime.now().month == 12
                                  ? DateTime.now().year + 1
                                  : DateTime.now().year,
                              DateTime.now().month == 12
                                  ? 1
                                  : DateTime.now().month + 1,
                              1,
                            );
                            setState(() {
                              _selectedDate = firstDayNextMonth;
                            });
                          },
                          icon: Icon(Icons.calendar_month, size: 16),
                          label: Text(
                            'Bulan Depan',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue.shade600,
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        prefixIcon: Icon(Icons.note),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedType == TransactionType.income
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEditing ? 'Update Transaksi' : 'Simpan Transaksi',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Apakah Anda yakin ingin menghapus transaksi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: _deleteTransaction,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction() async {
    Navigator.of(context).pop(); // Close dialog

    setState(() => _isLoading = true);

    final error = await _transactionService.deleteTransaction(
      widget.transaction!.id,
    );

    setState(() => _isLoading = false);

    if (error != null) {
      _showErrorDialog(error);
    } else {
      Navigator.pop(context, true);
    }
  }
}
