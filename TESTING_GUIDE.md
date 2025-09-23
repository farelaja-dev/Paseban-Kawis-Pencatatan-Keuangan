# Testing Guide - Aplikasi UMKM Kalibaru Manis

## 🧪 Panduan Testing Lengkap

### Persiapan Testing

1. **Setup Environment Testing**

   ```bash
   flutter test
   flutter drive --target=test_driver/app.dart
   ```

2. **Firebase Test Project**
   - Buat Firebase project terpisah untuk testing
   - Gunakan Firestore emulator untuk testing lokal

## 🔍 Manual Testing Checklist

### Authentication Testing

#### ✅ Registration Flow

- [ ] Registrasi dengan email valid
- [ ] Registrasi dengan email yang sudah terdaftar (harus gagal)
- [ ] Registrasi dengan password < 6 karakter (harus gagal)
- [ ] Registrasi dengan email format salah (harus gagal)
- [ ] Form validation bekerja dengan benar
- [ ] Loading indicator muncul saat registrasi
- [ ] User baru tersimpan di Firestore dengan status `isActive: true`

#### ✅ Login Flow

- [ ] Login dengan email/password benar
- [ ] Login dengan email/password salah (harus gagal)
- [ ] Login dengan akun yang dinonaktifkan (harus gagal)
- [ ] Redirect ke dashboard yang benar sesuai role
- [ ] Remember login state setelah restart app
- [ ] Logout berhasil dan kembali ke login screen

### UMKM Features Testing

#### ✅ Dashboard UMKM

- [ ] Summary cards menampilkan data yang benar
- [ ] Ringkasan hari ini akurat
- [ ] Ringkasan bulan ini akurat
- [ ] Navigasi ke semua menu berfungsi
- [ ] Real-time update saat ada transaksi baru

#### ✅ Add Transaction

- [ ] Form validation semua field
- [ ] Dropdown kategori bekerja
- [ ] Date picker berfungsi
- [ ] Save transaksi berhasil
- [ ] Notifikasi sukses muncul
- [ ] Kembali ke halaman sebelumnya setelah save
- [ ] Data tersimpan di Firestore dengan benar

#### ✅ Transactions List

- [ ] Daftar transaksi tampil dengan benar
- [ ] Filter by month berfungsi
- [ ] Search transaksi bekerja
- [ ] Edit transaksi berhasil
- [ ] Delete transaksi berhasil dengan konfirmasi
- [ ] Infinite scrolling (jika data banyak)
- [ ] Empty state ketika tidak ada data

#### ✅ Reports

- [ ] Laporan bulanan tampil dengan benar
- [ ] Laporan tahunan tampil dengan benar
- [ ] Charts/grafik render dengan baik
- [ ] Data chart sesuai dengan data transaksi
- [ ] Navigation antar bulan/tahun
- [ ] Export PDF berfungsi (jika ada)
- [ ] Loading state saat generate report

### Admin Features Testing

#### ✅ Admin Dashboard

- [ ] Overview semua UMKM tampil
- [ ] Statistik konsolidasi benar
- [ ] Performance metrics akurat
- [ ] Navigation ke semua admin menu

#### ✅ UMKM Management

- [ ] Daftar semua UMKM tampil
- [ ] Search UMKM berfungsi
- [ ] Toggle active/inactive user berhasil
- [ ] View detail UMKM lengkap
- [ ] Status update tersinkron real-time

#### ✅ Admin Reports

- [ ] Laporan konsolidasi akurat
- [ ] Filter by UMKM berfungsi
- [ ] Filter by periode bekerja
- [ ] Charts menampilkan data yang benar
- [ ] Export consolidated reports

### Cross-Platform Testing

#### ✅ Android Testing

- [ ] Install dan launch berhasil
- [ ] Semua fitur berfungsi normal
- [ ] UI responsive di berbagai ukuran screen
- [ ] Performance baik (tidak lag)
- [ ] Back button behavior benar

#### ✅ iOS Testing (Opsional)

- [ ] Install dan launch berhasil
- [ ] Semua fitur berfungsi normal
- [ ] UI sesuai iOS design guidelines
- [ ] Performance optimal

## 🔧 Automated Testing

### Unit Tests

Buat file `test/unit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pencatatan_keuangan/models/transaction_model.dart';
import 'package:pencatatan_keuangan/models/report_model.dart';

void main() {
  group('Transaction Model Tests', () {
    test('Transaction calculation should be correct', () {
      final transaction = TransactionModel(
        id: 'test',
        userId: 'user1',
        type: TransactionType.income,
        amount: 100000,
        category: 'Penjualan',
        description: 'Test',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(transaction.amount, 100000);
      expect(transaction.type, TransactionType.income);
    });
  });

  group('Report Model Tests', () {
    test('Profit calculation should be correct', () {
      final report = ReportModel(
        id: 'test',
        userId: 'user1',
        month: 12,
        year: 2024,
        totalIncome: 500000,
        totalExpense: 300000,
        incomeByCategory: {},
        expenseByCategory: {},
        createdAt: DateTime.now(),
      );

      expect(report.profit, 200000);
    });
  });
}
```

### Widget Tests

Buat file `test/widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pencatatan_keuangan/screens/auth/login_screen.dart';

void main() {
  testWidgets('Login screen has email and password fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen()),
    );

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsWidgets);
  });
}
```

### Integration Tests

Buat file `test_driver/app.dart`:

```dart
import 'package:flutter_driver/driver_extension.dart';
import 'package:pencatatan_keuangan/main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  app.main();
}
```

Buat file `test_driver/app_test.dart`:

```dart
import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('UMKM App Integration Tests', () {
    FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      if (driver != null) {
        driver.close();
      }
    });

    test('Complete user flow', () async {
      // Test login
      await driver.tap(find.byValueKey('email_field'));
      await driver.enterText('test@umkm.com');

      await driver.tap(find.byValueKey('password_field'));
      await driver.enterText('password123');

      await driver.tap(find.byValueKey('login_button'));

      // Verify dashboard appears
      await driver.waitFor(find.byValueKey('umkm_dashboard'));

      // Test add transaction
      await driver.tap(find.byValueKey('add_transaction_button'));
      await driver.waitFor(find.byValueKey('add_transaction_screen'));
    });
  });
}
```

## 🚨 Error Scenarios Testing

### Network Error Testing

- [ ] Test tanpa koneksi internet
- [ ] Test dengan koneksi lambat
- [ ] Test saat Firebase down
- [ ] Proper error handling dan retry mechanism

### Data Validation Testing

- [ ] Input data kosong
- [ ] Input data dengan format salah
- [ ] Input dengan karakter khusus
- [ ] Input dengan panjang maksimum

### Performance Testing

- [ ] Startup time < 3 detik
- [ ] Navigation smooth tanpa lag
- [ ] Memory usage stabil
- [ ] Battery usage optimal

## 📊 Testing Metrics

### Coverage Target

- Unit Tests: > 80%
- Widget Tests: > 60%
- Integration Tests: > 50%

### Performance Benchmarks

- App startup: < 3s
- Screen transition: < 500ms
- Data loading: < 2s
- Report generation: < 5s

## 🐛 Bug Tracking Template

Gunakan template ini untuk melaporkan bug:

```markdown
### 🐛 Bug Report

**Describe the bug:**
A clear description of what the bug is.

**Steps to reproduce:**

1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior:**
What you expected to happen.

**Actual behavior:**
What actually happened.

**Screenshots:**
If applicable, add screenshots.

**Device info:**

- OS: [e.g. Android 12]
- Device: [e.g. Samsung Galaxy S21]
- App version: [e.g. 1.0.0]

**Additional context:**
Any other context about the problem.
```

## ✅ Testing Completion Checklist

### Functional Testing

- [ ] Authentication flow complete
- [ ] UMKM features tested
- [ ] Admin features tested
- [ ] All user interactions work
- [ ] Data persistence verified

### Non-Functional Testing

- [ ] Performance benchmarks met
- [ ] Security testing passed
- [ ] Usability testing done
- [ ] Compatibility testing complete

### Documentation

- [ ] Bug reports documented
- [ ] Test results logged
- [ ] Performance metrics recorded
- [ ] User feedback collected

---

**Testing Target**: 100% critical path coverage  
**Timeline**: Complete testing sebelum production release
