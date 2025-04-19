import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this import
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../../storage/secure_storage.dart';

class AuthService {
  // Google Sign-In configuration
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file', // Scope for Drive file access
    ],
    // Use environment variables for client IDs
    clientId: kIsWeb ? dotenv.env['GOOGLE_WEB_CLIENT_ID'] : null,
    serverClientId: kIsWeb
        ? null
        : dotenv.env[
            'GOOGLE_ANDROID_CLIENT_ID'], // Use appropriate ID for non-web platforms
    // If you need offline access (refresh token) via backend, you might need this on Android:
    // forceCodeForRefreshToken: true,
  );

  final SecureStorageService _secureStorage = SecureStorageService();

  // Sign in with Google
  Future<Either<String, UserModel>> signIn() async {
    try {
      // Start the Google sign-in flow
      // If you need a serverAuthCode for backend exchange, ensure serverClientId is set correctly.
      // For Android, you might also need forceCodeForRefreshToken: true in GoogleSignIn constructor
      // if you intend to get a refresh token via your backend.
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return left('Sign in canceled by user');
      }

      // Get authentication details
      final googleAuth = await account.authentication;

      // The serverAuthCode might be needed if you exchange it on a backend for tokens.
      // final serverAuthCode = account.serverAuthCode;
      // if (serverAuthCode != null) {
      //   // Send serverAuthCode to your backend here
      // }

      // Store credentials (AccessToken and ID Token for client-side use)
      final credentials = AccessCredentials(
        AccessToken(
          'Bearer',
          googleAuth.accessToken!,
          // Note: Access tokens are typically short-lived (1 hour).
          // Refreshing them usually requires a refresh token (obtained via serverAuthCode flow)
          // or re-authentication. The current setup doesn't handle automatic refresh.
          // Ensure expiry is in UTC
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        // Use the refreshToken obtained from your backend if using serverAuthCode flow.
        // For client-side only, refreshToken is typically null here.
        null, // refreshToken - typically null unless using server-side exchange
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
      // Consider more specific error handling (e.g., PlatformException codes)
      // Log the error for debugging
      print('Authentication failed: ${e.toString()}');
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
      if (credentials == null) {
        // No credentials, user needs to sign in.
        return null;
      }

      // Check if token is expired
      if (credentials.accessToken.hasExpired) {
        // Access token expired.
        // Option 1: Try silent sign-in to refresh (might get new tokens if session is valid)
        final silentAccount = await _googleSignIn.signInSilently();
        if (silentAccount != null) {
          final googleAuth = await silentAccount.authentication;
          final newCredentials = AccessCredentials(
            AccessToken(
              'Bearer',
              googleAuth.accessToken!,
              // Use UTC time and add a buffer (e.g., 55 mins for a 1-hour token)
              DateTime.now().toUtc().add(const Duration(minutes: 55)),
            ),
            credentials
                .refreshToken, // Preserve existing refresh token (if any)
            credentials.scopes, // Preserve existing scopes
            idToken: googleAuth.idToken,
          );
          await _secureStorage.saveCredentials(newCredentials);
          // Return client with new credentials
          return authenticatedClient(http.Client(), newCredentials);
        } else {
          // Silent sign-in failed, likely need full re-authentication.
          await signOut(); // Clear potentially invalid credentials
          return null;
        }

        // Option 2: If using server-side flow with refresh tokens:
        // Use the stored refresh token (if available) to get a new access token
        // from your backend or Google's token endpoint. This is more robust but complex.
        // Since no refresh token is stored in the current setup, this isn't implemented.

        // Option 3: Simple approach - require re-login (return null)
        // await signOut(); // Optionally clear credentials on expiry
        // return null;
      }

      // Token is still valid
      return authenticatedClient(http.Client(), credentials);
    } catch (e) {
      // Handle errors during credential loading or client creation
      // Consider logging the error: print('Error getting authenticated client: $e');
      return null;
    }
  }
}
