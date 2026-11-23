import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic.dart';
import '../models.dart';
import '../repo.dart';
import 'export_card.dart';
import 'update_card.dart';

/// Familie: Einladungscode, Mitglieder, eigener Name und Farbe.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({
    super.key,
    required this.repo,
    required this.familyId,
    required this.members,
    required this.onExportSync,
  });

  final Repo repo;
  final String familyId;
  final List<Member> members;

  /// Kalender-Export sofort abgleichen.
  final Future<void> Function() onExportSync;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  late final Stream<Family?> _family = widget.repo.family(widget.familyId);

  Future<void> _editMe(Member? me) async {
    final controller = TextEditingController(text: me?.name ?? '');
    var color = me?.color ?? memberPalette.first.toARGB32();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Mein Name und meine Farbe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in memberPalette)
                    GestureDetector(
                      onTap: () => setLocal(() => color = c.toARGB32()),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: c,
                        child: color == c.toARGB32() ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Speichern')),
          ],
        ),
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (saved != true || name.isEmpty) return;
    await widget.repo.updateMe(widget.familyId, name: name, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.repo.uid;
    final me = widget.members.where((m) => m.uid == uid).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Familie')),
      body: StreamBuilder<Family?>(
        stream: _family,
        builder: (context, snap) {
          final family = snap.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (family != null) ...[
                Text(family.name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Einladungscode', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                family.inviteCode,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Kopieren',
                              icon: const Icon(Icons.copy),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: family.inviteCode));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(const SnackBar(content: Text('Code kopiert')));
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Die anderen installieren die App, melden sich mit ihrem Google-Konto an, '
                          'wählen „Beitreten“ und geben diesen Code ein.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Mitglieder', style: Theme.of(context).textTheme.titleMedium),
              for (final m in widget.members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: m.colorValue,
                    child: Text(
                      m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase(),
                      style: TextStyle(color: readableOn(m.colorValue)),
                    ),
                  ),
                  title: Text(m.uid == uid ? '${m.name} (ich)' : m.name),
                  trailing: m.uid == uid
                      ? IconButton(
                          tooltip: 'Name und Farbe ändern',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editMe(me),
                        )
                      : null,
                ),
              const SizedBox(height: 16),
              ExportCard(onSyncNow: widget.onExportSync),
              const SizedBox(height: 8),
              const UpdateCard(),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Abmelden'),
              ),
              const SizedBox(height: 8),
              Text(
                'Angemeldet als ${FirebaseAuth.instance.currentUser?.email ?? ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
