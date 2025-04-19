import 'package:dartz/dartz.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../../storage/secure_storage.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope, 'email'],
  );

  final SecureStorageService _secureStorage = SecureStorageService();

  // Sign in with Google
  Future<Either<String, UserModel>> signIn() async {
    try {
      // Start the Google sign-in flow
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return left('Sign in canceled by user');
      }

      // Get authentication details
      final googleAuth = await account.authentication;

      // Store credentials
      final credentials = AccessCredentials(
        AccessToken(
          'Bearer',
          googleAuth.accessToken!,
          DateTime.now().add(const Duration(hours: 1)),
        ),
        googleAuth.idToken,
        [drive.DriveApi.driveFileScope, 'email'],
        idToken: googleAuth.idToken,
      );

      await _secureStorage.saveCredentials(credentials);

      // Create user model
      final user = UserModel(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? 'User',
        photoUrl: account.photoUrl,
      );

      return right(user);
    } catch (e) {
      return left('Authentication failed: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _secureStorage.clearCredentials();
  }

  // Check if user is signed in
  Future<UserModel?> getCurrentUser() async {
    try {
      // Check if we have stored credentials
      final hasCredentials = await _secureStorage.hasCredentials();
      if (!hasCredentials) {
        return null;
      }

      // Check if the GoogleSignIn account is available
      final account = _googleSignIn.currentUser;
      if (account != null) {
        return UserModel(
          id: account.id,
          email: account.email,
          displayName: account.displayName ?? 'User',
          photoUrl: account.photoUrl,
        );
      }

      // Try silent sign-in as a fallback
      final silentAccount = await _googleSignIn.signInSilently();
      if (silentAccount != null) {
        return UserModel(
          id: silentAccount.id,
          email: silentAccount.email,
          displayName: silentAccount.displayName ?? 'User',
          photoUrl: silentAccount.photoUrl,
        );
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Get authenticated HTTP client for APIs
  Future<http.Client?> getAuthenticatedClient() async {
    try {
      final credentials = await _secureStorage.loadCredentials();
      if (credentials == null) return null;

      // Check if token is expired and needs refresh
      if (credentials.accessToken.hasExpired) {
        // We don't have automatic refresh token functionality here
        // User would need to re-authenticate
        return null;
      }

      return authenticatedClient(http.Client(), credentials);
    } catch (e) {
      return null;
    }
  }
}
