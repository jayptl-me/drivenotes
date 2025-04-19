import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/notes/presentation/screens/notes_list_screen.dart';
import '../../features/notes/presentation/screens/note_detail_screen.dart';
import '../auth/providers/auth_provider.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authStateListenable = ValueNotifier<bool>(false);

  // Listen to auth state changes and update the notifier
  ref.listen<AsyncValue<bool>>(
    authStateProvider, // Corrected provider name
    (_, state) => state.whenData(
      (isAuthenticated) => authStateListenable.value = isAuthenticated,
    ),
  );

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authStateListenable,
    redirect: (context, state) {
      final isAuthenticated = authStateListenable.value;
      final isLoggingIn = state.location == '/login';

      // If not logged in, redirect to login
      if (!isAuthenticated && !isLoggingIn) {
        return '/login';
      }

      // If logged in and on login page, redirect to home
      if (isAuthenticated && isLoggingIn) {
        return '/';
      }

      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const NotesListScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: '/note/new',
        builder: (BuildContext context, GoRouterState state) =>
            const NoteDetailScreen(),
      ),
      GoRoute(
        path: '/note/:id',
        builder: (BuildContext context, GoRouterState state) {
          final noteId = state.params['id']!;
          return NoteDetailScreen(noteId: noteId);
        },
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.location}'),
      ),
    ),
  );
});
