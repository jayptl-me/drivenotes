import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis_auth/googleapis_auth.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Key constants
  static const String _accessTokenKey = 'google_access_token';
  static const String _refreshTokenKey = 'google_refresh_token';
  static const String _expiryDateKey = 'google_expiry_date';
  static const String _idTokenKey = 'google_id_token';
  static const String _scopesKey = 'google_scopes';

  // Save access credentials
  Future<void> saveCredentials(AccessCredentials credentials) async {
    await _storage.write(
      key: _accessTokenKey,
      value: credentials.accessToken.data,
    );

    if (credentials.refreshToken != null) {
      await _storage.write(
        key: _refreshTokenKey,
        value: credentials.refreshToken,
      );
    }

    await _storage.write(
      key: _expiryDateKey,
      value: credentials.accessToken.expiry.toIso8601String(),
    );

    if (credentials.idToken != null) {
      await _storage.write(key: _idTokenKey, value: credentials.idToken);
    }

    // Store scopes as JSON string
    final scopesJson = jsonEncode(credentials.scopes);
    await _storage.write(key: _scopesKey, value: scopesJson);
  }

  // Load access credentials
  Future<AccessCredentials?> loadCredentials() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final expiryDateStr = await _storage.read(key: _expiryDateKey);
    final idToken = await _storage.read(key: _idTokenKey);
    final scopesJson = await _storage.read(key: _scopesKey);

    if (accessToken == null || expiryDateStr == null || scopesJson == null) {
      return null;
    }

    final expiryDate = DateTime.parse(expiryDateStr);
    final scopes = List<String>.from(jsonDecode(scopesJson));

    return AccessCredentials(
      AccessToken('Bearer', accessToken, expiryDate),
      refreshToken,
      scopes,
      idToken: idToken,
    );
  }

  // Clear all stored credentials
  Future<void> clearCredentials() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiryDateKey);
    await _storage.delete(key: _idTokenKey);
    await _storage.delete(key: _scopesKey);
  }

  // Check if credentials are stored
  Future<bool> hasCredentials() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    return accessToken != null;
  }
}
