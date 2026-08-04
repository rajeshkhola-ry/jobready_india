import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_user_model.dart';

class AdminAuthException implements Exception {
  const AdminAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminAuthService {
  AdminAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<AdminUserModel> signInAdmin({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = userCredential.user;
      if (user == null) {
        throw const AdminAuthException('Admin sign-in failed. Try again.');
      }

      final adminSnap = await _firestore.collection('admins').doc(user.uid).get();
      final adminData = adminSnap.data();
      if (adminData == null) {
        throw const AdminAuthException('Admin profile was not found.');
      }

      return AdminUserModel.fromFirestoreMap(
        uid: user.uid,
        email: user.email ?? email.trim(),
        data: adminData,
      );
    } on FirebaseAuthException catch (error) {
      throw AdminAuthException(error.message ?? 'Admin login failed.');
    } on FirebaseException catch (error) {
      throw AdminAuthException(error.message ?? 'Admin profile fetch failed.');
    }
  }

  Future<Map<String, dynamic>> generate2FASecret() async {
    try {
      final callable = _functions.httpsCallable('generate2FASecret');
      final response = await callable.call();
      final data = Map<String, dynamic>.from(response.data as Map);
      final recoveryCodes = (data['recoveryCodes'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false);
      return <String, dynamic>{
        'otpauthUri': data['otpauthUri']?.toString() ?? '',
        'secret': data['secret']?.toString() ?? '',
        'recoveryCodes': recoveryCodes,
      };
    } on FirebaseFunctionsException catch (error) {
      throw AdminAuthException(error.message ?? 'Unable to generate 2FA secret.');
    }
  }

  Future<bool> verifyAndEnable2FA({required String code}) async {
    try {
      final callable = _functions.httpsCallable('verifyAndEnable2FA');
      final response = await callable.call(<String, dynamic>{
        'otpCode': code.trim(),
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      return data['success'] == true;
    } on FirebaseFunctionsException catch (error) {
      throw AdminAuthException(error.message ?? '2FA setup verification failed.');
    }
  }

  Future<Map<String, dynamic>> verifyAdmin2FACode({
    required String adminUid,
    required String otpCode,
    String? recoveryCode,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyAdmin2FACode');
      final response = await callable.call(<String, dynamic>{
        'adminUid': adminUid,
        'otpCode': otpCode.trim(),
        if (recoveryCode != null && recoveryCode.trim().isNotEmpty)
          'recoveryCode': recoveryCode.trim(),
      });
      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (error) {
      throw AdminAuthException(error.message ?? '2FA code verification failed.');
    }
  }

  Future<void> signOut() => _auth.signOut();
}
