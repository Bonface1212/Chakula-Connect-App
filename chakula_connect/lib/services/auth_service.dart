import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> registerUser({
    required String email,
    required String password,
    required String role,
    required String username,
    required String fullName,
    required String nationalId,
    required String phoneNumber,
    required String profileImageUrl,
    required GeoPoint location,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user == null) throw Exception('User creation failed.');

      // Save additional user details in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'username': username,
        'fullName': fullName,
        'nationalId': nationalId,
        'phoneNumber': phoneNumber,
        'profileImage': profileImageUrl,
        'location': location,
        'role': role.toLowerCase(),
        'createdAt': Timestamp.now(),
      });

      return user;
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  Future<User?> loginUser(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['role'];
    } catch (e) {
      throw Exception('Failed to fetch user role: $e');
    }
  }
}
