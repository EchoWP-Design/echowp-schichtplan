import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
    } on FirebaseAuthException catch (e) {
      setState(() => _error = 'Anmeldung fehlgeschlagen (${e.code}). ${e.message ?? ''}');
    } catch (e) {
      setState(() => _error = 'Anmeldung fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: echoBlack,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month, size: 72, color: echoYellow),
                const SizedBox(height: 16),
                const Text(
                  'EchoWP Schichtplan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: echoYellow, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Die Schichten der ganzen Familie in einem Kalender.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: echoYellow,
                    foregroundColor: echoBlack,
                    minimumSize: const Size(260, 52),
                  ),
                  onPressed: _busy ? null : _signIn,
                  icon: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.login),
                  label: const Text('Mit Google anmelden', style: TextStyle(fontSize: 16)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 24),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
