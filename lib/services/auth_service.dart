import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Use Singleton instance for 7.x
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Initialize for 7.x (Optional but recommended to call once)
  static Future<void> initialize() async {
    try {
      await _googleSignIn.initialize();
    } catch (e) {
      print('GoogleSignIn init error (likely already initialized): $e');
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Authenticate with Google (Uses new 7.x API)
      final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) return null;

      // 2. Obtain the auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 4. Once signed in, return the UserCredential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error in Google Sign-In: $e');
      return null;
    }
  }

  // Verify Phone Number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException e) onVerificationFailed,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: (String verId, int? resendToken) => onCodeSent(verId),
      codeAutoRetrievalTimeout: (String verId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  // Sign in with OTP Credential
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  // Helper to create phone credential
  PhoneAuthCredential createPhoneCredential(String verificationId, String smsCode) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  // Sign out
  Future<void> signOut() async {
    // Note: signOut in 7.x is still available but identity tracking is different
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Stream of auth changes
  Stream<User?> get userStateStream => _auth.authStateChanges();
}
