import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User?> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously()
          .timeout(const Duration(seconds: 15));
      return result.user;
    } on TimeoutException {
      await _auth.signOut();
      print('Anonymous sign-in timed out');
      return null;
    } on FirebaseAuthException catch (e) {
      print('Anonymous sign-in error: ${e.message}');
      return null;
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn()
          .timeout(const Duration(seconds: 15));

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication.timeout(const Duration(seconds: 10));

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result =
          await _auth.signInWithCredential(credential);
      return result.user;
    } on TimeoutException {
      print('Google sign-in timed out');
      return null;
    } on FirebaseAuthException catch (e) {
      print('Google sign-in error: ${e.message}');
      return null;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  bool get isAnonymous => currentUser?.isAnonymous ?? false;
}
