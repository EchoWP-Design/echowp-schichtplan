import 'package:flutter/material.dart';

import '../updater.dart';

/// „Lizenzen und Hinweise“: Datenschutz in Kurzform und die Open-Source-Lizenzen.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'Wofür die App gedacht ist',
      'EchoWP Schichtplan ist eine private App für die Familie. Sie wird nicht verkauft '
          'und enthält keine Werbung und keine Auswertung des Nutzungsverhaltens.',
    ),
    (
      'Welche Daten gespeichert werden',
      'Dein Google-Konto zur Anmeldung, der Name und die Farbe, die du in der Familie angibst, '
          'deine Schichtarten und eingetragenen Schichten sowie der Einladungscode der Familie.',
    ),
    (
      'Wo die Daten liegen',
      'In Google Firebase (Authentication und Cloud Firestore), Rechenzentrum Frankfurt am Main. '
          'Lesen können sie nur angemeldete Mitglieder deiner Familie.',
    ),
    (
      'Google-Kalender-Export',
      'Der Export läuft nur auf diesem Handy: Die App schreibt die Schichten in den Kalender, '
          'den du auswählst. Andere Termine liest sie nicht aus und ändert sie nicht. '
          'Die Einstellung bleibt auf dem Handy.',
    ),
    (
      'Widgets und Update-Prüfung',
      'Die Widgets bekommen ihre Daten nur von der App auf diesem Handy. Für die Update-Prüfung '
          'fragt die App bei GitHub nach der neuesten Version; dabei wird nichts über dich übertragen.',
    ),
    (
      'Daten löschen',
      'Eigene Schichten kannst du in der App entfernen. Wer alle Daten löschen lassen möchte, '
          'wendet sich an die Person, die die Familie angelegt hat.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lizenzen und Hinweise')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (title, text) in _sections) ...[
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(text),
            const SizedBox(height: 16),
          ],
          const Divider(),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'EchoWP Schichtplan',
              applicationVersion: appVersionLabel,
              applicationLegalese: '© 2026 EchoWP-Design',
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open-Source-Lizenzen anzeigen'),
          ),
        ],
      ),
    );
  }
}
