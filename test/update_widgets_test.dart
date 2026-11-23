import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:schichtplan/home_widgets.dart';
import 'package:schichtplan/logic.dart';
import 'package:schichtplan/models.dart';
import 'package:schichtplan/screens/legal_screen.dart';
import 'package:schichtplan/screens/update_card.dart';
import 'package:schichtplan/updater.dart';

const _early = ShiftType(id: 'f', owner: 'jan', name: 'Frühdienst', code: 'F', start: 360, end: 855, color: 0xFFE8590C);
const _night = ShiftType(id: 'n', owner: 'p2', name: 'Nacht', code: 'N', start: 1290, end: 405, color: 0xFF5F3DC4);
const _members = [
  Member(uid: 'jan', name: 'Jan', color: 0xFF1C7ED6),
  Member(uid: 'p2', name: 'Person 2', color: 0xFFE64980),
];
const _types = {'f': _early, 'n': _night};

Entry _e(String owner, DateTime day, String type, [int slot = 1]) => Entry(
      id: entryId(owner, day, slot),
      owner: owner,
      date: dateKey(day),
      slot: slot,
      shiftTypeId: type,
    );

Map<String, dynamic> _release(String tag, {List<String> assets = const ['EchoWP-Schichtplan.apk']}) => {
      'tag_name': tag,
      'html_url': 'https://github.com/EchoWP-Design/echowp-schichtplan/releases/tag/$tag',
      'draft': false,
      'prerelease': false,
      'assets': [
        for (final a in assets) {'name': a, 'browser_download_url': 'https://example.invalid/$tag/$a'},
      ],
    };

Updater _fake(List<Map<String, dynamic>> releases, {int status = 200}) => Updater(
      client: MockClient((_) async => http.Response(jsonEncode(releases), status)),
    );

void main() {
  setUpAll(() => initializeDateFormatting('de_DE'));

  group('Update', () {
    test('appVersion passt zur pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final v = RegExp(r'^version:\s*([0-9.]+)\+', multiLine: true).firstMatch(pubspec)!;
      expect(appVersion, v.group(1));
    });

    test('Tags werden gelesen, fremde ignoriert', () {
      final r = Updater.parse(_release('v0.3.1-build-12'))!;
      expect(r.version, '0.3.1');
      expect(r.build, 12);
      expect(r.apkUrl, endsWith('EchoWP-Schichtplan.apk'));
      expect(Updater.parse(_release('app-v1.0.0-build-3')), isNull);
      expect(Updater.parse({..._release('v1.0.0-build-3'), 'draft': true}), isNull);
    });

    test('Versionsvergleich', () {
      final r = Updater.parse(_release('v0.2.0-build-9'))!;
      expect(Updater.isNewer(r, current: '0.1.2', build: 6), isTrue);
      expect(Updater.isNewer(r, current: '0.2.0', build: 8), isTrue);
      expect(Updater.isNewer(r, current: '0.2.0', build: 9), isFalse);
      expect(Updater.isNewer(r, current: '0.10.0', build: 1), isFalse);
      // Lokaler Build ohne Nummer: gleiche Version ist nicht neuer
      expect(Updater.isNewer(r, current: '0.2.0', build: 0), isFalse);
    });

    test('neueste Version mit APK gewinnt', () async {
      final r = await _fake([
        _release('v0.2.0-build-8'),
        _release('v0.3.0-build-9', assets: const ['andere.apk']),
        _release('v0.2.1-build-10'),
      ]).latest();
      expect(r!.tag, 'v0.2.1-build-10');
    });

    test('Fehler von GitHub werden verständlich gemeldet', () async {
      expect(_fake(const [], status: 403).latest(), throwsA(isA<UpdateException>()));
      expect(_fake(const [], status: 500).latest(), throwsA(isA<UpdateException>()));
    });

    testWidgets('Knopf zeigt neue Version und Download an', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: UpdateCard(updater: _fake([_release('v9.0.0-build-99')]))),
      ));
      expect(find.text('Herunterladen'), findsNothing);
      await tester.tap(find.text('Nach Updates suchen'));
      await tester.pumpAndSettle();
      expect(find.text('Neue Version 9.0.0 (Build 99) verfügbar.'), findsOneWidget);
      expect(find.text('Herunterladen'), findsOneWidget);
    });

    testWidgets('Knopf meldet aktuelle Version', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: UpdateCard(updater: _fake([_release('v0.0.1-build-1')]))),
      ));
      await tester.tap(find.text('Nach Updates suchen'));
      await tester.pumpAndSettle();
      expect(find.text('Du hast die neueste Version.'), findsOneWidget);
      expect(find.text('Herunterladen'), findsNothing);
    });
  });

  group('Startbildschirm-Widgets', () {
    final today = DateTime(2026, 11, 30);

    test('Heute: jede Person mit Schicht oder frei, 14 Tage ab heute', () {
      final days = buildWidgetDays(
        today: today,
        members: _members,
        typesById: _types,
        entries: [
          _e('jan', today, 'f'),
          _e('jan', today, 'n', 2),
          _e('p2', DateTime(2026, 12, 1), 'n'),
          _e('p2', DateTime(2026, 11, 29), 'n'), // gestern: nicht dabei
        ],
      );
      expect(days.length, widgetDays);
      expect(days.keys.first, '2026-11-30');
      expect(days.keys.last, '2026-12-13');
      final heute = days['2026-11-30']!;
      expect(heute[0]['n'], 'Jan');
      expect(heute[0]['t'], 'Frühdienst 06:00–14:15 + Nacht 21:30–06:45, über Mitternacht');
      expect(heute[0]['c'], _early.color);
      expect(heute[1]['t'], 'frei');
      expect(heute[1]['c'], _members[1].color);
      expect(days['2026-12-01']![1]['t'], startsWith('Nacht'));
      // muss als JSON für Android taugen
      expect(jsonDecode(jsonEncode(days)), isA<Map>());
    });

    test('Zeitraum deckt Monatsraster und 14 Tage ab', () {
      final (from, to) = widgetRange(today);
      expect(dateKey(from), '2026-10-26'); // Montag vor dem 1. November
      expect(dateKey(to), '2026-12-13'); // 14 Tage ab 30.11. reichen über das Raster hinaus
      final (from2, to2) = widgetRange(DateTime(2026, 11, 3));
      expect(dateKey(from2), '2026-10-26');
      expect(dateKey(to2), '2026-12-06'); // Rasterende
    });

    testWidgets('Monatsbild zeichnet ohne Überlauf', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: MonthWidgetImage(
            today: today,
            members: const [
              ..._members,
              Member(uid: 'p3', name: 'Maximiliane', color: 0xFF2F9E44),
              Member(uid: 'p4', name: 'Kind', color: 0xFFF08C00),
            ],
            typesById: _types,
            entries: [_e('jan', today, 'f'), _e('p2', today, 'n')],
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Maximili…'), findsOneWidget);
    });
  });

  testWidgets('Hinweise zeigen Datenschutz und öffnen die Lizenzliste', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LegalScreen()));
    expect(find.text('Wo die Daten liegen'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Open-Source-Lizenzen anzeigen'), 200);
    await tester.tap(find.text('Open-Source-Lizenzen anzeigen'));
    await tester.pumpAndSettle();
    expect(find.text('EchoWP Schichtplan'), findsWidgets);
  });
}
