import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic.dart';
import '../models.dart';
import '../repo.dart';

Future<void> showDaySheet(
  BuildContext context, {
  required Repo repo,
  required String familyId,
  required DateTime day,
  required List<Member> members,
  required List<ShiftType> types,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DaySheet(repo: repo, familyId: familyId, day: day, members: members, types: types),
  );
}

/// Tag bearbeiten: eigene Schichten eintragen oder entfernen, die der anderen sehen.
class DaySheet extends StatefulWidget {
  const DaySheet({
    super.key,
    required this.repo,
    required this.familyId,
    required this.day,
    required this.members,
    required this.types,
  });

  final Repo repo;
  final String familyId;
  final DateTime day;
  final List<Member> members;
  final List<ShiftType> types;

  @override
  State<DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<DaySheet> {
  late final Stream<List<Entry>> _entries =
      widget.repo.entries(widget.familyId, dateKey(widget.day), dateKey(widget.day));
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = 'Speichern fehlgeschlagen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.repo.uid;
    final typesById = {for (final t in widget.types) t.id: t};
    final myTypes = widget.types.where((t) => t.owner == uid && !t.archived).toList();
    final heading = DateFormat('EEEE, d. MMMM yyyy', 'de_DE').format(widget.day);
    return SafeArea(
      child: StreamBuilder<List<Entry>>(
        stream: _entries,
        builder: (context, snap) {
          final entries = snap.data ?? const <Entry>[];
          final mine = entries.where((e) => e.owner == uid).toList()..sort((a, b) => a.slot.compareTo(b.slot));
          final slot = freeSlot(entries, uid);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final m in widget.members.where((m) => m.uid != uid))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 6, backgroundColor: m.colorValue),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${m.name}: ${_describe(entries, m.uid, typesById)}')),
                      ],
                    ),
                  ),
                const Divider(height: 24),
                Text('Meine Schichten', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (mine.isEmpty) const Text('Noch nichts eingetragen – frei.'),
                for (final e in mine)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _CodeBadge(type: typesById[e.shiftTypeId]),
                    title: Text(typesById[e.shiftTypeId]?.name ?? 'Gelöschte Schicht'),
                    subtitle: Text(typesById[e.shiftTypeId]?.timeLabel ?? ''),
                    trailing: IconButton(
                      tooltip: 'Entfernen',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _run(() => widget.repo.deleteEntry(widget.familyId, e.id)),
                    ),
                  ),
                const SizedBox(height: 12),
                if (myTypes.isEmpty)
                  const Text('Lege zuerst unter „Meine Schichten“ deine Schichtarten an.')
                else if (slot == null)
                  const Text('Zwei Schichten sind das Maximum pro Tag. Entferne eine, um sie zu ersetzen.')
                else ...[
                  Text(mine.isEmpty ? 'Schicht eintragen:' : 'Zweite Schicht eintragen:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in myTypes)
                        ActionChip(
                          avatar: CircleAvatar(backgroundColor: t.colorValue),
                          label: Text('${t.code} · ${t.name}'),
                          onPressed: () => _run(() => widget.repo.setEntry(widget.familyId, widget.day, slot, t.id)),
                        ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static String _describe(List<Entry> entries, String uid, Map<String, ShiftType> typesById) {
    final list = entries.where((e) => e.owner == uid).map((e) => typesById[e.shiftTypeId]).whereType<ShiftType>();
    if (list.isEmpty) return 'frei';
    return list.map((t) => '${t.name} ${t.timeLabel}').join(' und ');
  }
}

class _CodeBadge extends StatelessWidget {
  const _CodeBadge({required this.type});

  final ShiftType? type;

  @override
  Widget build(BuildContext context) {
    final color = type?.colorValue ?? Colors.grey;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(type?.code ?? '?', style: TextStyle(color: readableOn(color), fontWeight: FontWeight.w800)),
    );
  }
}
