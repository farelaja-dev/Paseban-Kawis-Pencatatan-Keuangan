# 💰 Aplikasi Pencatatan Keuangan UMKM Kalibaru Manis

Aplikasi mobile untuk membantu UMKM (Usaha Mikro Kecil Menengah) di Kalibaru Manis dalam mengelola keuangan bisnis mereka dengan mudah dan efisien.

## 🌟 Fitur Utama

### 👤 Untuk UMKM

- ✅ **Registrasi & Login** - Daftar dan masuk dengan mudah
- 💵 **Catat Transaksi** - Rekam pemasukan dan pengeluaran harian
- 📊 **Laporan Otomatis** - Laporan bulanan dan tahunan dengan grafik
- 📈 **Analisis Keuangan** - Lihat tren dan performa bisnis

### 👑 Untuk Admin

- 🏢 **Kelola UMKM** - Daftar dan status semua UMKM
- 📋 **Laporan Konsolidasi** - Ringkasan keuangan semua UMKM
- 📊 **Dashboard Analytics** - Statistik dan performa keseluruhan

## 🚀 Quick Start

### Prasyarat

- Flutter SDK (versi terbaru)
- Firebase Project
- Android Studio / VS Code

### Instalasi

1. **Clone repository**

   ```bash
   git clone https://github.com/your-repo/pencatatan-keuangan-umkm
   cd pencatatan_keuangan
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Setup Firebase**

   - Ikuti panduan lengkap di [FIREBASE_SETUP.md](FIREBASE_SETUP.md)
   - Atau jalankan: `flutterfire configure`

4. **Jalankan aplikasi**
   ```bash
   flutter run
   ```

## 📱 Screenshots

_Coming soon - screenshots aplikasi_

## 🛠️ Teknologi

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Auth + Firestore)
- **Charts**: fl_chart
- **State Management**: Provider
- **Localization**: Indonesian (intl)

## 📖 Dokumentasi

- 📚 [Dokumentasi Lengkap](DOKUMENTASI.md)
- 🔥 [Setup Firebase](FIREBASE_SETUP.md)
- 🏗️ [Struktur Project](#struktur-project)

## 🏗️ Struktur Project

```
lib/
├── 🚀 main.dart              # Entry point
├── 📊 models/               # Data models
├── ⚙️ services/            # Business logic
└── 🖼️ screens/             # UI screens
    ├── 🔐 auth/            # Login & Register
    ├── 🏪 umkm/            # UMKM features
    └── 👑 admin/           # Admin panel
```

## 🎯 Roadmap

- [x] ✅ Setup project & Firebase
- [x] ✅ Authentication system
- [x] ✅ UMKM dashboard & transactions
- [x] ✅ Reports with charts
- [x] ✅ Admin dashboard
- [ ] 🔄 Testing & bug fixes
- [ ] 📱 APK release
- [ ] 🚀 Production deployment

## 🤝 Kontribusi

Silakan buka issue atau submit pull request untuk perbaikan atau fitur baru.

## 📞 Support

Butuh bantuan? Hubungi:

- 📧 Email: support@umkmkalibarumanis.com
- 💬 WhatsApp: +62-xxx-xxxx-xxxx

## 📄 License

MIT License - silakan gunakan sesuai kebutuhan.

---

**Dibuat dengan ❤️ untuk UMKM Kalibaru Manis**
