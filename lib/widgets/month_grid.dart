import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';

const List<String> weekdayShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// Monatsraster: pro Tag eine farbige Leiste je Person (in der Reihenfolge von [members]).
/// Rein darstellend, ohne Firebase – dadurch testbar.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.year,
    required this.month,
    required this.members,
    required this.entriesByDay,
    required this.typesById,
    required this.today,
    this.selected,
    required this.onTapDay,
  });

  final int year;
  final int month;
  final List<Member> members;
  final Map<String, List<Entry>> entriesByDay;
  final Map<String, ShiftType> typesById;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final days = monthGridDays(year, month);
    final weeks = days.length ~/ 7;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              for (final w in weekdayShort)
                Expanded(
                  child: Center(
                    child: Text(w, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              for (var w = 0; w < weeks; w++)
                Expanded(
                  child: Row(
                    children: [
                      for (var d = 0; d < 7; d++) Expanded(child: _cell(context, days[w * 7 + d])),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, DateTime day) {
    final scheme = Theme.of(context).colorScheme;
    final inMonth = day.month == month;
    final isToday = sameDay(day, today);
    final isSelected = selected != null && sameDay(day, selected!);
    final dayEntries = entriesByDay[dateKey(day)] ?? const <Entry>[];
    return GestureDetector(
      key: ValueKey('day-${dateKey(day)}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onTapDay(day),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? scheme.primary : (isToday ? scheme.secondary : scheme.outlineVariant),
            width: isSelected || isToday ? 2 : 1,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            const top = 17.0;
            final n = members.isEmpty ? 1 : members.length;
            final barHeight = ((box.maxHeight - top - 2) / n - 2).clamp(3.0, 16.0);
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 4,
                  top: 1,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      color: inMonth ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                for (var i = 0; i < members.length; i++)
                  Positioned(
                    left: 2,
                    right: 2,
                    top: top + i * (barHeight + 2),
                    height: barHeight,
                    child: _bar(dayEntries.where((e) => e.owner == members[i].uid).toList(), barHeight, inMonth),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bar(List<Entry> mine, double height, bool inMonth) {
    if (mine.isEmpty) return const SizedBox.shrink();
    final types = mine.map((e) => typesById[e.shiftTypeId]).whereType<ShiftType>().toList();
    if (types.isEmpty) return const SizedBox.shrink();
    final color = types.first.colorValue;
    final label = types.map((t) => t.code).join('/');
    return Opacity(
      opacity: inMonth ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        alignment: Alignment.center,
        child: height >= 10
            ? Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(fontSize: height >= 14 ? 10 : 8, height: 1, fontWeight: FontWeight.w700, color: readableOn(color)),
              )
            : null,
      ),
    );
  }
}
