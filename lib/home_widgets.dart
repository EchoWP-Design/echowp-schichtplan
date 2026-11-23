// Startbildschirm-Widgets „Schichten heute“ und „Monatsübersicht“.
//
// Die App schreibt die Daten, Android zeigt sie an (Kotlin-Teil in tool/android/):
//   tage   JSON {"JJJJ-MM-TT": [{"n": Name, "t": "Früh 06:00–14:15" | "frei", "c": Farbe}]}
//   monat  Pfad zu einem PNG der aktuellen Monatsübersicht
// So zeigt „Heute“ auch nach Mitternacht den richtigen Tag, solange die Daten reichen.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'logic.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets/month_grid.dart';

/// Wie viele Tage ab heute das Widget „Heute“ vorrätig hat.
const widgetDays = 14;

const _heuteWidget = 'de.echowp.schichtplan.HeuteWidget';
const _monatWidget = 'de.echowp.schichtplan.MonatWidget';

/// Tagesdaten für das Widget „Heute“: pro Tag jede Person mit Schicht oder „frei“.
Map<String, List<Map<String, Object>>> buildWidgetDays({
  required DateTime today,
  required List<Member> members,
  required Map<String, ShiftType> typesById,
  required Iterable<Entry> entries,
  int days = widgetDays,
}) {
  final byDay = groupByDay(entries);
  final result = <String, List<Map<String, Object>>>{};
  for (var i = 0; i < days; i++) {
    final day = DateTime(today.year, today.month, today.day + i);
    final key = dateKey(day);
    final dayEntries = byDay[key] ?? const <Entry>[];
    result[key] = [for (final m in members) _personLine(m, dayEntries, typesById)];
  }
  return result;
}

Map<String, Object> _personLine(Member m, List<Entry> dayEntries, Map<String, ShiftType> typesById) {
  final types = dayEntries
      .where((e) => e.owner == m.uid)
      .map((e) => typesById[e.shiftTypeId])
      .whereType<ShiftType>()
      .toList();
  return {
    'n': m.name,
    't': types.isEmpty ? 'frei' : types.map((t) => '${t.name} ${t.timeLabel}').join(' + '),
    'c': types.isEmpty ? m.color : types.first.color,
  };
}

/// Bild für das Widget „Monatsübersicht“: dunkler Hintergrund, gelbe Überschrift, Monatsraster.
class MonthWidgetImage extends StatelessWidget {
  const MonthWidgetImage({
    super.key,
    required this.today,
    required this.members,
    required this.typesById,
    required this.entries,
    this.size = const Size(360, 330),
  });

  final DateTime today;
  final List<Member> members;
  final Map<String, ShiftType> typesById;
  final Iterable<Entry> entries;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final title = DateFormat('MMMM yyyy', 'de_DE').format(today);
    return Theme(
      data: buildDarkTheme(),
      child: Builder(
        builder: (context) => Material(
          color: echoBlack,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: SizedBox.fromSize(
            size: size,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(color: echoYellow, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                        for (final m in members.take(4))
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(radius: 4, backgroundColor: m.colorValue),
                                const SizedBox(width: 3),
                                Text(
                                  m.name.length > 8 ? '${m.name.substring(0, 8)}…' : m.name,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: MonthGrid(
                      year: today.year,
                      month: today.month,
                      members: members,
                      entriesByDay: groupByDay(entries),
                      typesById: typesById,
                      today: today,
                      onTapDay: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Erster und letzter Tag, den die Widgets brauchen (Monatsraster plus [widgetDays] ab heute).
(DateTime, DateTime) widgetRange(DateTime today) {
  final grid = monthGridDays(today.year, today.month);
  final lastNeeded = DateTime(today.year, today.month, today.day + widgetDays - 1);
  final to = lastNeeded.isAfter(grid.last) ? lastNeeded : grid.last;
  return (grid.first, to);
}

/// Schreibt die Widget-Daten und lässt Android beide Widgets neu zeichnen.
/// Fehler (z. B. ohne Widget-Unterstützung) werden still ignoriert: Die App läuft weiter.
Future<void> pushHomeWidgets({
  required DateTime today,
  required List<Member> members,
  required List<ShiftType> types,
  required List<Entry> entries,
}) async {
  final typesById = {for (final t in types) t.id: t};
  try {
    final days = buildWidgetDays(today: today, members: members, typesById: typesById, entries: entries);
    await HomeWidget.saveWidgetData<String>('tage', jsonEncode(days));
    await HomeWidget.renderFlutterWidget(
      MonthWidgetImage(today: today, members: members, typesById: typesById, entries: entries),
      key: 'monat',
      logicalSize: const Size(360, 330),
      pixelRatio: 2.5,
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: _heuteWidget);
    await HomeWidget.updateWidget(qualifiedAndroidName: _monatWidget);
  } catch (e) {
    debugPrint('Widgets nicht aktualisiert: $e');
  }
}
