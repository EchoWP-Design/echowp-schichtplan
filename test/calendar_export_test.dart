import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schichtplan/calendar_export.dart';
import 'package:schichtplan/logic.dart';
import 'package:schichtplan/models.dart';
import 'package:schichtplan/screens/export_card.dart';

const _early = ShiftType(id: 'f', owner: 'jan', name: 'Frühdienst', code: 'F', start: 360, end: 855, color: 0xFFE8590C);
const _night = ShiftType(id: 'n', owner: 'p2', name: 'Nacht', code: 'N', start: 1290, end: 405, color: 0xFF5F3DC4);
const _vac = ShiftType(id: 'u', owner: 'jan', name: 'Urlaub', code: 'U', start: 0, end: 0, color: 0xFF2F9E44, allDay: true);
const _types = {'f': _early, 'n': _night, 'u': _vac};
const _members = {
  'jan': Member(uid: 'jan', name: 'Jan', color: 0xFF1C7ED6),
  'p2': Member(uid: 'p2', name: 'Person 2', color: 0xFFE64980),
};

Entry _e(String owner, DateTime day, String type, [int slot = 1]) => Entry(
      id: entryId(owner, day, slot),
      owner: owner,
      date: dateKey(day),
      slot: slot,
      shiftTypeId: type,
    );

ExistingEvent _existing(String id, PlannedEvent p, {String? title, DateTime? start}) => ExistingEvent(
      id: id,
      key: p.key,
      title: title ?? p.title,
      start: start ?? p.start,
      end: p.end,
      allDay: p.allDay,
    );

void main() {
  final day = DateTime(2026, 12, 9);
  final entries = [
    _e('jan', day, 'f'),
    _e('jan', DateTime(2026, 12, 10), 'u'),
    _e('p2', day, 'n'),
  ];

  group('Termine aus Einträgen', () {
    test('nur eigene Schichten, Zeiten und Nachtschicht über Mitternacht', () {
      final mine = plannedEvents(entries: entries, typesById: _types, membersByUid: _members, onlyOwner: 'jan');
      expect(mine.length, 2);
      expect(mine[0].title, 'Frühdienst');
      expect(mine[0].start, DateTime(2026, 12, 9, 6));
      expect(mine[0].end, DateTime(2026, 12, 9, 14, 15));
      expect(mine[0].allDay, isFalse);
      expect(mine[1].allDay, isTrue);
      expect(mine[1].start, DateTime(2026, 12, 10));
      expect(mine[1].end, DateTime(2026, 12, 11));

      final night = plannedEvents(entries: entries, typesById: _types, membersByUid: _members, onlyOwner: 'p2').single;
      expect(night.start, DateTime(2026, 12, 9, 21, 30));
      expect(night.end, DateTime(2026, 12, 10, 6, 45));
    });

    test('ganze Familie: Name im Titel', () {
      final all = plannedEvents(entries: entries, typesById: _types, membersByUid: _members);
      expect(all.map((p) => p.title), ['Jan: Frühdienst', 'Jan: Urlaub', 'Person 2: Nacht']);
    });

    test('Kennung steht in der Beschreibung und wird wieder erkannt', () {
      final p = plannedEvents(entries: entries, typesById: _types, membersByUid: _members).first;
      expect(p.description, contains('Frühdienst (F), 06:00–14:15'));
      expect(markerOf(p.description), entryId('jan', day, 1));
      expect(markerOf('Zahnarzt'), isNull);
      expect(markerOf(null), isNull);
    });

    test('unbekannte Schichtart wird übersprungen', () {
      final list = plannedEvents(entries: [_e('jan', day, 'weg')], typesById: _types, membersByUid: _members);
      expect(list, isEmpty);
    });
  });

  group('Abgleich', () {
    final planned = plannedEvents(entries: entries, typesById: _types, membersByUid: _members);

    test('leerer Kalender: alles anlegen', () {
      final plan = planSync(planned, const []);
      expect(plan.create.length, 3);
      expect(plan.delete, isEmpty);
    });

    test('alles aktuell: nichts tun', () {
      final plan = planSync(planned, [for (var i = 0; i < planned.length; i++) _existing('e$i', planned[i])]);
      expect(plan.isEmpty, isTrue);
      expect(plan.unchanged, 3);
    });

    test('Doppelte werden entfernt, geänderte neu geschrieben, gelöschte Schichten entfernt', () {
      final existing = [
        _existing('a1', planned[0]),
        _existing('a2', planned[0]), // doppelt
        _existing('b1', planned[1], title: 'Alter Name'), // geändert
        ExistingEvent(
          id: 'z1',
          key: 'jan_20261201_1', // Schicht gibt es nicht mehr
          title: 'Frühdienst',
          start: DateTime(2026, 12, 1, 6),
          end: DateTime(2026, 12, 1, 14, 15),
          allDay: false,
        ),
      ];
      final plan = planSync(planned, existing);
      expect(plan.unchanged, 1);
      expect(plan.create.map((p) => p.key), [planned[1].key, planned[2].key]);
      expect(plan.delete, unorderedEquals(['a2', 'b1', 'z1']));
    });

    test('zweimaliger Abgleich erzeugt keine Doppelungen', () {
      final first = planSync(planned, const []);
      final created = [for (var i = 0; i < first.create.length; i++) _existing('n$i', first.create[i])];
      expect(planSync(planned, created).isEmpty, isTrue);
    });
  });

  test('Zeitraum: zwei Wochen zurück, vier Monate voraus', () {
    final (from, to) = exportRange(DateTime(2026, 11, 23, 19, 30));
    expect(from, DateTime(2026, 11, 9));
    expect(to, DateTime(2027, 3, 23));
  });

  testWidgets('Karte zeigt „Einrichten“, solange der Export aus ist', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ExportCard(onSyncNow: () async {})),
    ));
    expect(find.text('Google Kalender'), findsOneWidget);
    expect(find.text('Einrichten'), findsOneWidget);
    expect(find.text('Jetzt abgleichen'), findsNothing);
  });
}
