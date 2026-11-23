import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

// Wird im GitHub-Build aus dem Secret GOOGLE_SERVICES_JSON erzeugt (tool/make_firebase_options.py).
import 'firebase_options.dart';
import 'repo.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  await initializeDateFormatting('de_DE');
  runApp(const SchichtplanApp());
}

class SchichtplanApp extends StatelessWidget {
  const SchichtplanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EchoWP Schichtplan',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}

/// Angemeldet? → Familie vorhanden? → Hauptbildschirm.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Loading();
        final user = snap.data;
        if (user == null) return const LoginScreen();
        final repo = Repo(FirebaseFirestore.instance, user.uid);
        return StreamBuilder<String?>(
          key: ValueKey(user.uid),
          stream: repo.familyId(),
          builder: (context, fam) {
            if (fam.hasError) {
              return Scaffold(body: Center(child: Text('Fehler beim Laden: ${fam.error}')));
            }
            if (!fam.hasData && fam.connectionState == ConnectionState.waiting) return const _Loading();
            final fid = fam.data;
            if (fid == null) return OnboardingScreen(repo: repo, suggestedName: _firstName(user.displayName));
            return HomeScreen(repo: repo, familyId: fid);
          },
        );
      },
    );
  }

  static String _firstName(String? displayName) {
    final n = (displayName ?? '').trim();
    return n.isEmpty ? '' : n.split(RegExp(r'\s+')).first;
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
