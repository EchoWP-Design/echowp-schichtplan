import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schichtplan/logic.dart';
import 'package:schichtplan/models.dart';
import 'package:schichtplan/screens/shift_editor.dart';
import 'package:schichtplan/widgets/month_grid.dart';

const _early = ShiftType(id: 'f', owner: 'jan', name: 'Frühdienst', code: 'F', start: 360, end: 855, color: 0xFFE8590C);
const _late = ShiftType(id: 's', owner: 'p2', name: 'Spätdienst', code: 'S', start: 825, end: 1320, color: 0xFF2F9E44);
const _members = [
  Member(uid: 'jan', name: 'Jan', color: 0xFF1C7ED6),
  Member(uid: 'p2', name: 'Person 2', color: 0xFFE64980),
];

Widget _grid({required Size size, ValueChanged<DateTime>? onTap, List<Member> members = _members}) {
  final entries = [
    Entry(id: entryId('jan', DateTime(2026, 12, 9), 1), owner: 'jan', date: '2026-12-09', slot: 1, shiftTypeId: 'f'),
    Entry(id: entryId('p2', DateTime(2026, 12, 9), 1), owner: 'p2', date: '2026-12-09', slot: 1, shiftTypeId: 's'),
    Entry(id: entryId('jan', DateTime(2026, 12, 10), 1), owner: 'jan', date: '2026-12-10', slot: 1, shiftTypeId: 'f'),
    Entry(id: entryId('jan', DateTime(2026, 12, 10), 2), owner: 'jan', date: '2026-12-10', slot: 2, shiftTypeId: 'f'),
  ];
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox.fromSize(
          size: size,
          child: MonthGrid(
            year: 2026,
            month: 12,
            members: members,
            entriesByDay: groupByDay(entries),
            typesById: const {'f': _early, 's': _late},
            today: DateTime(2026, 12, 9),
            onTapDay: onTap ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Monatsraster', () {
    testWidgets('zeigt Kürzel pro Person und meldet Tipps auf einen Tag', (tester) async {
      DateTime? tapped;
      await tester.pumpWidget(_grid(size: const Size(400, 600), onTap: (d) => tapped = d));
      expect(find.text('Mo'), findsOneWidget);
      expect(find.text('So'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      // 9.12. einmal F, 10.12. zwei Dienste als „F/F“
      expect(find.text('F'), findsOneWidget);
      expect(find.text('F/F'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('day-2026-12-09')));
      expect(tapped, DateTime(2026, 12, 9));
    });

    testWidgets('kein Überlauf auf sehr kleinem Bildschirm mit vielen Personen', (tester) async {
      final many = [
        for (var i = 0; i < 6; i++) Member(uid: 'u$i', name: 'P$i', color: memberPalette[i].toARGB32()),
      ];
      await tester.pumpWidget(_grid(size: const Size(240, 220), members: many));
      expect(tester.takeException(), isNull);
    });
  });

  group('Schicht-Editor', () {
    Future<ShiftType?> openEditor(WidgetTester tester, {ShiftType? initial}) async {
      ShiftType? result;
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<ShiftType>(
                    MaterialPageRoute(builder: (_) => ShiftEditorScreen(initial: initial, owner: 'jan', nextOrder: 3)),
                  );
                },
                child: const Text('öffnen'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('prüft Pflichtfelder und liefert die neue Schicht', (tester) async {
      ShiftType? result;
      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<ShiftType>(
                    MaterialPageRoute(builder: (_) => const ShiftEditorScreen(owner: 'jan', nextOrder: 3)),
                  );
                },
                child: const Text('öffnen'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('öffnen'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('save')));
      await tester.pumpAndSettle();
      expect(find.text('Bitte einen Namen eingeben'), findsOneWidget);
      expect(find.text('Bitte ein Kürzel eingeben'), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(find.byKey(const ValueKey('field-name')), 'Frühdienst');
      await tester.enterText(find.byKey(const ValueKey('field-code')), 'F');
      await tester.tap(find.byKey(const ValueKey('color-8')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.name, 'Frühdienst');
      expect(result!.code, 'F');
      expect(result!.owner, 'jan');
      expect(result!.order, 3);
      expect(result!.start, 6 * 60);
      expect(result!.end, 14 * 60);
      expect(result!.color, shiftPalette[8].toARGB32());
      expect(result!.id, '');
    });

    testWidgets('zeigt den Hinweis für Nachtschichten', (tester) async {
      const night = ShiftType(
        id: 'n',
        owner: 'jan',
        name: 'Nachtdienst',
        code: 'N',
        start: 21 * 60 + 45,
        end: 6 * 60 + 15,
        color: 0xFF7048E8,
      );
      await openEditor(tester, initial: night);
      expect(find.text('Schicht bearbeiten'), findsOneWidget);
      expect(find.text('21:45'), findsOneWidget);
      expect(find.text('06:15'), findsOneWidget);
      expect(find.textContaining('über Mitternacht'), findsOneWidget);
      expect(find.text('Archiviert'), findsOneWidget);
    });
  });
}
