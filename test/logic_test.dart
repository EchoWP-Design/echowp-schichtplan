import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:schichtplan/logic.dart';
import 'package:schichtplan/models.dart';

void main() {
  group('Datum', () {
    test('dateKey ist sortierbar und zweistellig', () {
      expect(dateKey(DateTime(2026, 3, 7)), '2026-03-07');
      expect(dateKey(DateTime(2026, 12, 31)), '2026-12-31');
      expect(parseDateKey('2026-03-07'), DateTime(2026, 3, 7));
    });

    test('entryId besteht aus Person, Tag und Platz', () {
      expect(entryId('abc', DateTime(2026, 12, 9), 1), 'abc_20261209_1');
      expect(entryId('abc', DateTime(2026, 12, 9), 2), 'abc_20261209_2');
    });
  });

  group('Zeiten', () {
    test('formatMinutes', () {
      expect(formatMinutes(0), '00:00');
      expect(formatMinutes(6 * 60), '06:00');
      expect(formatMinutes(14 * 60 + 15), '14:15');
      expect(formatMinutes(24 * 60 + 30), '00:30');
    });

    test('Nachtschicht über Mitternacht', () {
      expect(crossesMidnight(21 * 60 + 45, 6 * 60 + 15), isTrue);
      expect(crossesMidnight(6 * 60, 14 * 60), isFalse);
      expect(durationMinutes(21 * 60 + 45, 6 * 60 + 15), 8 * 60 + 30);
      expect(durationMinutes(6 * 60, 14 * 60 + 15), 8 * 60 + 15);
    });
  });

  group('Monatsraster', () {
    void checkGrid(int year, int month, int expectedDays, DateTime expectedFirst) {
      final days = monthGridDays(year, month);
      expect(days.length, expectedDays);
      expect(days.first, expectedFirst);
      expect(days.first.weekday, DateTime.monday);
      expect(days.last.weekday, DateTime.sunday);
      for (var i = 1; i < days.length; i++) {
        // Lückenlos und ohne doppelte Tage, auch bei der Zeitumstellung
        expect(days[i].difference(days[i - 1]).inHours, inInclusiveRange(23, 25));
        expect(dateKey(days[i]) == dateKey(days[i - 1]), isFalse);
      }
      final inMonth = days.where((d) => d.month == month).length;
      expect(inMonth, DateTime(year, month + 1, 0).day);
    }

    test('Dezember 2026 beginnt am Dienstag', () => checkGrid(2026, 12, 35, DateTime(2026, 11, 30)));
    test('März 2026 mit Zeitumstellung, 6 Wochen', () => checkGrid(2026, 3, 42, DateTime(2026, 2, 23)));
    test('Februar 2027 genau 4 Wochen', () => checkGrid(2027, 2, 28, DateTime(2027, 2, 1)));
    test('Oktober 2026 mit Zeitumstellung', () => checkGrid(2026, 10, 35, DateTime(2026, 9, 28)));
  });

  group('Einladungscode', () {
    test('6 Zeichen aus dem sicheren Alphabet', () {
      final code = newInviteCode(Random(1));
      expect(code.length, 6);
      expect(code.split('').every(inviteAlphabet.contains), isTrue);
    });

    test('Eingabe wird bereinigt', () {
      expect(normalizeInviteCode(' ab-c2 3d '), 'ABC23D');
    });
  });

  group('Prüfungen', () {
    test('Name und Kürzel', () {
      expect(validateShiftName(''), isNotNull);
      expect(validateShiftName('Frühdienst'), isNull);
      expect(validateShiftCode(''), isNotNull);
      expect(validateShiftCode('FRÜH'), isNotNull);
      expect(validateShiftCode('F'), isNull);
    });
  });

  group('Modelle', () {
    const night = ShiftType(
      id: 'n',
      owner: 'u1',
      name: 'Nachtdienst',
      code: 'N',
      start: 21 * 60 + 45,
      end: 6 * 60 + 15,
      color: 0xFF7048E8,
    );

    test('ShiftType übersteht Speichern und Laden', () {
      final back = ShiftType.fromMap('n', night.toMap());
      expect(back.name, 'Nachtdienst');
      expect(back.code, 'N');
      expect(back.start, night.start);
      expect(back.end, night.end);
      expect(back.color, night.color);
      expect(back.owner, 'u1');
    });

    test('Zeitangabe', () {
      expect(night.timeLabel, '21:45–06:15, über Mitternacht');
      expect(night.copyWith(allDay: true).timeLabel, 'ganztägig');
      expect(night.copyWith(start: 6 * 60, end: 14 * 60 + 15).timeLabel, '06:00–14:15');
    });

    test('Einträge nach Tag und freier Platz', () {
      const a = Entry(id: 'u1_20261209_2', owner: 'u1', date: '2026-12-09', slot: 2, shiftTypeId: 'n');
      const b = Entry(id: 'u1_20261209_1', owner: 'u1', date: '2026-12-09', slot: 1, shiftTypeId: 'f');
      const c = Entry(id: 'u2_20261209_1', owner: 'u2', date: '2026-12-09', slot: 1, shiftTypeId: 's');
      final grouped = groupByDay([a, b, c]);
      expect(grouped['2026-12-09']!.first.slot, 1);
      expect(freeSlot([a, b, c], 'u1'), isNull);
      expect(freeSlot([c], 'u2'), 2);
      expect(freeSlot([a], 'u1'), 1);
      expect(freeSlot(const [], 'u3'), 1);
    });

    test('lesbare Schriftfarbe', () {
      expect(readableOn(shiftPalette[2]).computeLuminance() < 0.1, isTrue); // Gelb → Schwarz
      expect(readableOn(shiftPalette[9]).computeLuminance() > 0.9, isTrue); // Indigo → Weiß
    });
  });
}
