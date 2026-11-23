import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';
import '../repo.dart';
import 'shift_editor.dart';

/// Die eigene Schicht-Datenbank.
class ShiftsScreen extends StatelessWidget {
  const ShiftsScreen({super.key, required this.repo, required this.familyId, required this.types});

  final Repo repo;
  final String familyId;
  final List<ShiftType> types;

  Future<void> _edit(BuildContext context, ShiftType? existing, List<ShiftType> mine) async {
    final nextOrder = mine.isEmpty ? 1 : mine.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
    final result = await Navigator.of(context).push<ShiftType>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ShiftEditorScreen(
          initial: existing,
          owner: repo.uid,
          nextOrder: nextOrder,
          suggestedColor: shiftPalette[mine.length % shiftPalette.length],
        ),
      ),
    );
    if (result == null) return;
    try {
      await repo.saveShiftType(familyId, result);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = types.where((t) => t.owner == repo.uid).toList();
    final active = mine.where((t) => !t.archived).toList();
    final archived = mine.where((t) => t.archived).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Schichten')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null, mine),
        icon: const Icon(Icons.add),
        label: const Text('Neue Schicht'),
      ),
      body: mine.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Hier legst du deine Schichten an: Name, Kürzel, Zeiten und Farbe.\n\n'
                  'Tippe unten auf „Neue Schicht“.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                for (final t in active) _tile(context, t, mine),
                if (archived.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 16, 8, 8),
                    child: Text('Archiviert', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  for (final t in archived) _tile(context, t, mine),
                ],
              ],
            ),
    );
  }

  Widget _tile(BuildContext context, ShiftType t, List<ShiftType> mine) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.colorValue, borderRadius: BorderRadius.circular(8)),
          child: Text(t.code, style: TextStyle(color: readableOn(t.colorValue), fontWeight: FontWeight.w800)),
        ),
        title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(t.timeLabel),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _edit(context, t, mine),
      ),
    );
  }
}
