import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user data from Firestore
  Future<UserModel?> getCurrentUserData() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Register new user (UMKM)
  Future<String?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String businessName,
    required String address,
    required String phone,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user document in Firestore
        final userModel = UserModel(
          id: credential.user!.uid,
          email: email,
          name: name,
          businessName: businessName,
          address: address,
          phone: phone,
          role: UserRole.umkm,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(userModel.toFirestore());

        return null; // Success
      }
      return 'Gagal membuat akun';
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'Password terlalu lemah';
        case 'email-already-in-use':
          return 'Email sudah terdaftar';
        case 'invalid-email':
          return 'Format email tidak valid';
        default:
          return 'Error: ${e.message}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Sign in with email and password
  Future<String?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Check if user document exists
        final userDoc = await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .get();

        if (!userDoc.exists) {
          await signOut();
          return 'Login Gagal!\nData pengguna tidak ditemukan dalam sistem. Silakan hubungi administrator.';
        }

        final userData = UserModel.fromFirestore(userDoc);
        if (!userData.isActive) {
          await signOut();
          return 'Login Gagal!\nAkun Anda telah dinonaktifkan oleh administrator. Silakan hubungi admin untuk mengaktifkan kembali akun Anda.';
        }

        return null; // Success
      }
      return 'Login Gagal!\nTerjadi kesalahan saat proses login. Silakan coba lagi.';
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Login Gagal!\nEmail tidak terdaftar dalam sistem. Silakan daftar terlebih dahulu.';
        case 'wrong-password':
          return 'Login Gagal!\nPassword yang Anda masukkan salah. Periksa kembali password Anda.';
        case 'invalid-email':
          return 'Login Gagal!\nFormat email tidak valid. Pastikan format email benar (contoh: user@example.com).';
        case 'user-disabled':
          return 'Login Gagal!\nAkun Anda telah dinonaktifkan oleh administrator.';
        case 'invalid-credential':
          return 'Login Gagal!\nEmail atau password yang Anda masukkan salah. Periksa kembali data login Anda.';
        case 'too-many-requests':
          return 'Login Gagal!\nTerlalu banyak percobaan login. Tunggu beberapa saat sebelum mencoba lagi.';
        case 'network-request-failed':
          return 'Login Gagal!\nTidak ada koneksi internet. Periksa koneksi internet Anda dan coba lagi.';
        default:
          return 'Login Gagal!\nTerjadi kesalahan: ${e.message ?? 'Kesalahan tidak diketahui'}';
      }
    } catch (e) {
      return 'Login Gagal!\nTerjadi kesalahan sistem: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Email tidak terdaftar';
        case 'invalid-email':
          return 'Format email tidak valid';
        default:
          return 'Error: ${e.message}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Update user profile
  Future<String?> updateUserProfile(UserModel updatedUser) async {
    try {
      await _firestore
          .collection('users')
          .doc(updatedUser.id)
          .update(updatedUser.toFirestore());
      return null; // Success
    } catch (e) {
      return 'Error updating profile: $e';
    }
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    final userData = await getCurrentUserData();
    return userData?.role == UserRole.admin;
  }
}
