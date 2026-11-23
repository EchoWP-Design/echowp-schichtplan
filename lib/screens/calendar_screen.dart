import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic.dart';
import '../models.dart';
import '../repo.dart';
import '../widgets/month_grid.dart';
import 'day_sheet.dart';

/// Gemeinsamer Monatskalender der Familie.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.repo,
    required this.familyId,
    required this.members,
    required this.types,
  });

  final Repo repo;
  final String familyId;
  final List<Member> members;
  final List<ShiftType> types;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  DateTime? _selected;
  late Stream<List<Entry>> _entries;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selected = DateTime(now.year, now.month, now.day);
    _subscribe();
  }

  void _subscribe() {
    final days = monthGridDays(_month.year, _month.month);
    _entries = widget.repo.entries(widget.familyId, dateKey(days.first), dateKey(days.last));
  }

  void _shift(int months) {
    setState(() {
      _month = DateTime(_month.year, _month.month + months);
      _subscribe();
    });
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selected = DateTime(now.year, now.month, now.day);
      _subscribe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final typesById = {for (final t in widget.types) t.id: t};
    final title = DateFormat('MMMM yyyy', 'de_DE').format(_month);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(tooltip: 'Voriger Monat', icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
          IconButton(tooltip: 'Heute', icon: const Icon(Icons.today), onPressed: _goToday),
          IconButton(tooltip: 'Nächster Monat', icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
        ],
      ),
      body: StreamBuilder<List<Entry>>(
        stream: _entries,
        builder: (context, snap) {
          final byDay = groupByDay(snap.data ?? const []);
          return Column(
            children: [
              _Legend(members: widget.members),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v < -200) _shift(1);
                      if (v > 200) _shift(-1);
                    },
                    child: MonthGrid(
                      year: _month.year,
                      month: _month.month,
                      members: widget.members,
                      entriesByDay: byDay,
                      typesById: typesById,
                      today: DateTime.now(),
                      selected: _selected,
                      onTapDay: (day) {
                        setState(() => _selected = day);
                        showDaySheet(
                          context,
                          repo: widget.repo,
                          familyId: widget.familyId,
                          day: day,
                          members: widget.members,
                          types: widget.types,
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (_selected != null)
                _DaySummary(
                  day: _selected!,
                  entries: byDay[dateKey(_selected!)] ?? const [],
                  members: widget.members,
                  typesById: typesById,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.members});

  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        'Leisten von oben: ${members.map((m) => m.name).join(', ')}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

/// Kurzübersicht unter dem Kalender: wer arbeitet am gewählten Tag.
class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.day, required this.entries, required this.members, required this.typesById});

  final DateTime day;
  final List<Entry> entries;
  final List<Member> members;
  final Map<String, ShiftType> typesById;

  @override
  Widget build(BuildContext context) {
    final heading = DateFormat('EEEE, d. MMMM', 'de_DE').format(day);
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(heading, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final m in members) Text('${m.name}: ${describeDay(entries, m.uid, typesById)}'),
          ],
        ),
      ),
    );
  }
}

/// „Frühdienst 06:00–14:15“ bzw. „frei“ für eine Person an einem Tag.
String describeDay(List<Entry> dayEntries, String uid, Map<String, ShiftType> typesById) {
  final mine = dayEntries.where((e) => e.owner == uid).map((e) => typesById[e.shiftTypeId]).whereType<ShiftType>();
  if (mine.isEmpty) return 'frei';
  return mine.map((t) => '${t.name} ${t.timeLabel}').join(' und ');
}
