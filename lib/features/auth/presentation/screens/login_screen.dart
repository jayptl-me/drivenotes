import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo and title
                const Icon(
                  Icons.note_alt_outlined,
                  size: 80,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  'DriveNotes',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your notes, synced to Google Drive',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 48),

                // Sign in button
                authState.maybeWhen(
                  loading: () => const CircularProgressIndicator(),
                  error: (error, _) => Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                  orElse: () => ElevatedButton.icon(
                    onPressed: () async {
                      setState(() {
                        _isLoading = true;
                      });

                      final success =
                          await ref.read(authStateProvider.notifier).signIn();

                      if (!success) {
                        // Show error
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Login failed. Please try again.')),
                          );
                        }
                      }

                      setState(() {
                        _isLoading = false;
                      });
                    },
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      height: 24,
                    ),
                    label: const Text('Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
