import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart';
import '../services/auth_service.dart';

// Provider for auth service
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Provider for current authenticated user state
final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    return _getCurrentUser();
  }

  Future<UserModel?> _getCurrentUser() async {
    final authService = ref.read(authServiceProvider);
    return authService.getCurrentUser();
  }

  // Sign in method
  Future<Either<String, UserModel>> signIn() async {
    final authService = ref.read(authServiceProvider);

    // Set state to loading
    state = const AsyncValue.loading();

    final result = await authService.signIn();

    // Update state based on result
    result.fold(
      (error) => state = AsyncValue.error(error, StackTrace.current),
      (user) => state = AsyncValue.data(user),
    );

    return result;
  }

  // Sign out method
  Future<void> signOut() async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
    state = const AsyncValue.data(null);
  }

  // Get authenticated client
  Future<http.Client?> getAuthenticatedClient() {
    final authService = ref.read(authServiceProvider);
    return authService.getAuthenticatedClient();
  }
}

// Provider for authenticated HTTP client
final authenticatedClientProvider = FutureProvider<http.Client?>((ref) async {
  final authNotifier = ref.watch(authStateProvider.notifier);
  return authNotifier.getAuthenticatedClient();
});
