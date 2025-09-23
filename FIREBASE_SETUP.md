# Setup Firebase untuk Aplikasi UMKM Kalibaru Manis

## Langkah 1: Membuat Project Firebase

1. **Buka Firebase Console**

   - Kunjungi https://console.firebase.google.com/
   - Login dengan akun Google Anda

2. **Buat Project Baru**
   - Klik "Add project" atau "Tambah project"
   - Nama project: "umkm-kalibaru-manis"
   - Pilih negara: Indonesia
   - Setujui terms & conditions
   - Klik "Create project"

## Langkah 2: Setup Authentication

1. **Enable Authentication**

   - Di sidebar kiri, klik "Authentication"
   - Klik tab "Sign-in method"
   - Enable "Email/Password"
   - Klik "Save"

2. **Buat Admin User Pertama** (Setelah aplikasi selesai)
   - Jalankan aplikasi
   - Daftar sebagai user biasa dengan email admin
   - Di Firebase Console > Authentication > Users
   - Edit user dan catat UID-nya

## Langkah 3: Setup Cloud Firestore

1. **Create Database**

   - Di sidebar kiri, klik "Firestore Database"
   - Klik "Create database"
   - Pilih "Start in test mode" (sementara)
   - Pilih lokasi: asia-southeast1 (Singapore)
   - Klik "Done"

2. **Setup Collections Structure**

   Buat collection `users` dengan dokumen contoh:

   ```json
   {
     "uid": "admin-uid-dari-step-sebelumnya",
     "email": "admin@umkm.com",
     "name": "Admin UMKM",
     "role": "admin",
     "businessName": "",
     "businessAddress": "",
     "phoneNumber": "",
     "isActive": true,
     "registrationDate": "2024-12-XX"
   }
   ```

3. **Setup Security Rules**
   - Di tab "Rules", ganti dengan:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Allow users to read/write their own data
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
         // Allow admin to read all users
         allow read: if request.auth != null &&
           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
       }

       // Transactions - users can only access their own
       match /transactions/{transactionId} {
         allow read, write: if request.auth != null &&
           resource.data.userId == request.auth.uid;
         // Admin can read all transactions
         allow read: if request.auth != null &&
           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
       }

       // Reports - same as transactions
       match /reports/{reportId} {
         allow read, write: if request.auth != null &&
           resource.data.userId == request.auth.uid;
         // Admin can read all reports
         allow read: if request.auth != null &&
           get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
       }
     }
   }
   ```

## Langkah 4: Setup Flutter Integration

1. **Install Firebase CLI**

   ```bash
   npm install -g firebase-tools
   firebase login
   ```

2. **Install FlutterFire CLI**

   ```bash
   dart pub global activate flutterfire_cli
   ```

3. **Configure FlutterFire**
   ```bash
   cd pencatatan_keuangan
   flutterfire configure
   ```
   - Pilih project "umkm-kalibaru-manis"
   - Pilih platform: Android, iOS, Web
   - Ikuti instruksi untuk setiap platform

## Langkah 5: Android Setup

1. **Update android/app/build.gradle**

   ```gradle
   android {
       compileSdkVersion 34

       defaultConfig {
           minSdkVersion 21
           targetSdkVersion 34
           multiDexEnabled true
       }
   }

   dependencies {
       implementation 'com.android.support:multidex:1.0.3'
   }
   ```

2. **Update android/build.gradle**

   ```gradle
   buildscript {
       dependencies {
           classpath 'com.google.gms:google-services:4.4.0'
       }
   }
   ```

3. **Update android/app/build.gradle** (bagian bawah)
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

## Langkah 6: iOS Setup (Opsional)

1. **Update ios/Runner/Info.plist**

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLName</key>
           <string>REVERSED_CLIENT_ID dari GoogleService-Info.plist</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>REVERSED_CLIENT_ID dari GoogleService-Info.plist</string>
           </array>
       </dict>
   </array>
   ```

2. **Update ios/Podfile**
   ```ruby
   platform :ios, '12.0'
   ```

## Langkah 7: Testing Setup

1. **Test Firebase Connection**

   ```bash
   flutter run
   ```

2. **Verifikasi di Firebase Console**
   - Cek apakah aplikasi muncul di Project Overview
   - Test registrasi user baru
   - Cek apakah data masuk ke Firestore

## Langkah 8: Production Setup

1. **Update Firestore Rules untuk Production**

   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Production rules dengan validasi ketat
       match /users/{userId} {
         allow read, write: if request.auth != null &&
           request.auth.uid == userId &&
           validateUserData(request.resource.data);
         allow read: if request.auth != null &&
           isAdmin();
       }

       match /transactions/{transactionId} {
         allow create: if request.auth != null &&
           request.auth.uid == request.resource.data.userId &&
           validateTransactionData(request.resource.data);
         allow read, update, delete: if request.auth != null &&
           (resource.data.userId == request.auth.uid || isAdmin());
       }

       match /reports/{reportId} {
         allow read, write: if request.auth != null &&
           (resource.data.userId == request.auth.uid || isAdmin());
       }

       function isAdmin() {
         return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
       }

       function validateUserData(data) {
         return data.keys().hasAll(['name', 'email', 'role', 'isActive']) &&
           data.role in ['admin', 'umkm'] &&
           data.isActive is bool;
       }

       function validateTransactionData(data) {
         return data.keys().hasAll(['type', 'amount', 'category', 'date']) &&
           data.type in ['income', 'expense'] &&
           data.amount is number &&
           data.amount > 0;
       }
     }
   }
   ```

2. **Enable App Check** (Keamanan tambahan)

   - Di Firebase Console, buka "App Check"
   - Enable untuk semua aplikasi
   - Setup ReCAPTCHA untuk web

3. **Setup Monitoring**
   - Enable "Crashlytics" untuk error tracking
   - Enable "Performance Monitoring"
   - Setup "Firebase Analytics"

## Langkah 9: Backup & Recovery

1. **Setup Backup Otomatis**

   ```bash
   # Install gcloud CLI
   # Setup backup schedule di Firebase Console
   ```

2. **Export Data Script**
   ```bash
   # Script untuk export data Firestore
   gcloud firestore export gs://backup-bucket-name/$(date +%Y-%m-%d)
   ```

## Troubleshooting Common Issues

### 1. Build Failures

```bash
# Clean dan rebuild
flutter clean
flutter pub get
flutter run
```

### 2. Firebase tidak terdeteksi

- Pastikan `google-services.json` di `android/app/`
- Pastikan `GoogleService-Info.plist` di `ios/Runner/`
- Restart IDE

### 3. Authentication Issues

- Cek apakah Email/Password enabled di Firebase Console
- Verify domain di Authentication settings

### 4. Firestore Permission Denied

- Cek security rules
- Pastikan user sudah authenticated
- Cek struktur data sesuai rules

## Checklist Setup Lengkap

- [ ] Firebase project dibuat
- [ ] Authentication enabled (Email/Password)
- [ ] Firestore database dibuat
- [ ] Security rules diterapkan
- [ ] Admin user pertama dibuat
- [ ] FlutterFire configured
- [ ] Android setup selesai
- [ ] iOS setup selesai (jika diperlukan)
- [ ] Test connection berhasil
- [ ] Production rules applied
- [ ] App Check enabled
- [ ] Monitoring enabled
- [ ] Backup setup

## Kontak Support Firebase

Jika mengalami masalah:

1. Cek Firebase Documentation: https://firebase.google.com/docs
2. Stack Overflow dengan tag `firebase` dan `flutter`
3. Firebase Community: https://firebase.community/

---

**Note**: Simpan semua credential dan konfigurasi dengan aman. Jangan commit file konfigurasi ke repository publik.
