import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Add this import
import '../services/auth_service.dart';
// Add this import

// Provider for the authentication service
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Provider to get SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize this in main.dart');
});

// Key to store auth state in SharedPreferences
const String _authKey = 'is_authenticated';

// Provider for persistent authentication state
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<bool>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthStateNotifier(authService, prefs);
});

class AuthStateNotifier extends StateNotifier<AsyncValue<bool>> {
  final AuthService _authService;
  final SharedPreferences _prefs;

  AuthStateNotifier(this._authService, this._prefs)
      : super(const AsyncValue.loading()) {
    _initAuth();
  }

  // Load authentication state when app starts
  Future<void> _initAuth() async {
    final isLoggedIn = _prefs.getBool(_authKey) ?? false;
    state = AsyncValue.data(isLoggedIn);
  }

  // Sign in method that persists authentication
  Future<bool> signIn() async {
    state = const AsyncValue.loading();
    try {
      final result = await _authService.signIn();
      return result.fold(
        (error) {
          state = const AsyncValue.data(false);
          return false;
        },
        (user) async {
          await _prefs.setBool(_authKey, true);
          state = const AsyncValue.data(true);
          return true;
        },
      );
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  // Sign out method that clears persistent authentication
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signOut();
      await _prefs.setBool(_authKey, false);
      state = const AsyncValue.data(false);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
