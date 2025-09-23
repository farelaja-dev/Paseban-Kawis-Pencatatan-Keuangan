# Aplikasi Pencatatan Keuangan UMKM Kalibaru Manis

## Deskripsi

Aplikasi pencatatan keuangan sederhana yang dirancang khusus untuk UMKM (Usaha Mikro Kecil Menengah) di Kalibaru Manis. Aplikasi ini memungkinkan UMKM untuk mendaftar, login, dan mencatat keuangan masuk dan keluar per hari, serta menghasilkan laporan keuangan bulanan dan tahunan yang terdokumentasi dengan jelas oleh sistem. Admin juga disediakan halaman untuk melihat laporan keuangan semua UMKM.

## Fitur Utama

### Untuk UMKM:

1. **Registrasi dan Login**

   - Pendaftaran dengan email dan password
   - Login dengan validasi akun aktif
   - Profil UMKM yang lengkap

2. **Pencatatan Transaksi**

   - Catat pemasukan dan pengeluaran harian
   - Kategori transaksi yang beragam
   - Keterangan detail untuk setiap transaksi

3. **Laporan Keuangan**
   - Laporan bulanan dengan grafik
   - Laporan tahunan dengan analisis tren
   - Ringkasan profit/loss otomatis
   - Visualisasi data dengan chart

### Untuk Admin:

1. **Dashboard Admin**

   - Overview seluruh UMKM
   - Ringkasan keuangan konsolidasi
   - Statistik performa UMKM

2. **Manajemen UMKM**

   - Daftar semua UMKM terdaftar
   - Aktivasi/deaktivasi akun UMKM
   - Detail informasi setiap UMKM

3. **Laporan Konsolidasi**
   - Laporan gabungan semua UMKM
   - Analisis performa per UMKM
   - Ranking UMKM terbaik

## Teknologi yang Digunakan

### Framework & Library:

- **Flutter**: Framework utama untuk pengembangan aplikasi
- **Firebase Core**: Integrasi dengan layanan Firebase
- **Firebase Auth**: Sistem autentikasi pengguna
- **Cloud Firestore**: Database NoSQL untuk penyimpanan data
- **Provider**: State management
- **fl_chart**: Visualisasi data dan grafik
- **intl**: Internasionalisasi dan format tanggal Indonesia

### Package Dependencies:

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.3
  provider: ^6.1.2
  fl_chart: ^0.70.0
  intl: ^0.19.0
  pdf: ^3.11.1
  printing: ^5.13.2
```

## Struktur Proyek

```
lib/
├── main.dart                 # Entry point aplikasi
├── models/                   # Data models
│   ├── user_model.dart      # Model pengguna
│   ├── transaction_model.dart # Model transaksi
│   └── report_model.dart    # Model laporan
├── services/                # Business logic
│   ├── auth_service.dart    # Service autentikasi
│   ├── transaction_service.dart # Service transaksi
│   └── report_service.dart  # Service laporan
└── screens/                 # UI screens
    ├── auth/               # Halaman autentikasi
    │   ├── login_screen.dart
    │   └── register_screen.dart
    ├── umkm/              # Halaman UMKM
    │   ├── umkm_dashboard.dart
    │   ├── add_transaction_screen.dart
    │   ├── transactions_screen.dart
    │   └── reports_screen.dart
    └── admin/             # Halaman admin
        ├── admin_dashboard.dart
        ├── admin_umkm_list.dart
        └── admin_reports.dart
```

## Setup dan Instalasi

### Prasyarat:

1. Flutter SDK terinstall
2. Firebase project sudah dibuat
3. Firebase configuration files sudah ditambahkan

### Langkah Instalasi:

1. **Clone repository**

   ```bash
   git clone <repository-url>
   cd pencatatan_keuangan
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Setup Firebase**

   - Buat project Firebase di console.firebase.google.com
   - Enable Authentication (Email/Password)
   - Enable Cloud Firestore
   - Download dan tempatkan file konfigurasi:
     - `google-services.json` di folder `android/app/`
     - `GoogleService-Info.plist` di folder `ios/Runner/`

4. **Buat admin user pertama**

   - Daftarkan admin melalui aplikasi
   - Update role di Firestore menjadi 'admin'

5. **Run aplikasi**
   ```bash
   flutter run
   ```

## Konfigurasi Firebase

### Firestore Collections:

1. **users** - Data pengguna

   ```
   {
     "uid": "string",
     "email": "string",
     "name": "string",
     "role": "admin" | "umkm",
     "businessName": "string",
     "businessAddress": "string",
     "phoneNumber": "string",
     "isActive": boolean,
     "registrationDate": timestamp
   }
   ```

2. **transactions** - Data transaksi

   ```
   {
     "id": "string",
     "userId": "string",
     "type": "income" | "expense",
     "amount": number,
     "category": "string",
     "description": "string",
     "date": timestamp,
     "createdAt": timestamp
   }
   ```

3. **reports** - Laporan bulanan
   ```
   {
     "id": "string",
     "userId": "string",
     "month": number,
     "year": number,
     "totalIncome": number,
     "totalExpense": number,
     "profit": number,
     "incomeByCategory": map,
     "expenseByCategory": map,
     "createdAt": timestamp
   }
   ```

### Security Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow read: if request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Transactions access control
    match /transactions/{transactionId} {
      allow read, write: if request.auth != null &&
        resource.data.userId == request.auth.uid;
      allow read: if request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Reports access control
    match /reports/{reportId} {
      allow read, write: if request.auth != null &&
        resource.data.userId == request.auth.uid;
      allow read: if request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

## Panduan Penggunaan

### Untuk UMKM:

1. **Registrasi**

   - Buka aplikasi
   - Tap "Daftar Sebagai UMKM"
   - Isi form pendaftaran lengkap
   - Tunggu aktivasi dari admin

2. **Login**

   - Masukkan email dan password
   - Tap "Masuk"

3. **Mencatat Transaksi**

   - Dari dashboard, tap "Tambah Transaksi"
   - Pilih jenis (Pemasukan/Pengeluaran)
   - Pilih kategori dan isi detail
   - Tap "Simpan"

4. **Melihat Laporan**
   - Tap "Laporan" di dashboard
   - Pilih periode (bulanan/tahunan)
   - Lihat grafik dan analisis

### Untuk Admin:

1. **Login Admin**

   - Login dengan akun admin
   - Otomatis diarahkan ke dashboard admin

2. **Manajemen UMKM**

   - Tap "Kelola UMKM"
   - Lihat daftar semua UMKM
   - Aktivasi/deaktivasi akun

3. **Laporan Konsolidasi**
   - Tap "Laporan" di dashboard admin
   - Pilih periode dan UMKM
   - Lihat analisis performa

## Troubleshooting

### Masalah Umum:

1. **Firebase tidak terkoneksi**

   - Pastikan file konfigurasi Firebase sudah benar
   - Cek koneksi internet
   - Restart aplikasi

2. **Login gagal**

   - Cek email dan password
   - Pastikan akun sudah diaktivasi admin
   - Cek status koneksi Firebase

3. **Data tidak tersinkronisasi**
   - Cek koneksi internet
   - Restart aplikasi
   - Cek permission Firestore

### Error Codes:

- **AUTH001**: Email sudah terdaftar
- **AUTH002**: Email/password salah
- **AUTH003**: Akun tidak aktif
- **DB001**: Gagal menyimpan data
- **DB002**: Gagal mengambil data

## Maintenance & Updates

### Regular Maintenance:

1. Monitor penggunaan Firebase quota
2. Backup data secara berkala
3. Update dependencies secara rutin
4. Monitor error logs

### Security Checklist:

- [ ] Firebase security rules diterapkan
- [ ] User authentication berfungsi
- [ ] Data validation di client & server
- [ ] Regular security audit

## Support & Contact

Untuk bantuan teknis atau pertanyaan, silakan hubungi:

- Email: support@umkmkalibarumanis.com
- WhatsApp: +62-xxx-xxxx-xxxx

---

**Versi**: 1.0.0  
**Tanggal Update**: Desember 2024  
**Dikembangkan untuk**: UMKM Kalibaru Manis
