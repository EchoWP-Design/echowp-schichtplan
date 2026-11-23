// Export der Schichten in einen Kalender auf dem Handy (z. B. das Google-Konto).
//
// Jeder exportierte Termin trägt in der Beschreibung die feste Kennung des Eintrags und des
// Handys, das ihn angelegt hat (`EchoWP-Schichtplan-ID: <entryId> Gerät <geraet>`).
// Jedes Handy ändert und löscht nur seine eigenen Termine. Schreiben mehrere Handys in denselben
// (geteilten) Kalender, legt für eine Schicht nur das Handy mit der kleinsten Gerätekennung
// einen Termin an, die anderen lassen sie aus. Termine ohne Kennung bleiben unangetastet.
import 'dart:async';
import 'dart:math';

import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic.dart';
import 'models.dart';

const exportMarker = 'EchoWP-Schichtplan-ID: ';
const deviceMarker = 'Gerät ';

/// Zeitraum des Abgleichs: zwei Wochen zurück, vier Monate voraus.
(DateTime, DateTime) exportRange(DateTime today) =>
    (DateTime(today.year, today.month, today.day - 14), DateTime(today.year, today.month, today.day + 120));

/// Ein Termin, wie er im Kalender stehen soll.
@immutable
class PlannedEvent {
  const PlannedEvent({
    required this.key,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.details,
  });

  final String key;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String details;

  String descriptionFor(String device) => '$details\n\n$exportMarker$key $deviceMarker$device';
}

/// Ein vorhandener, von der App angelegter Termin.
@immutable
class ExistingEvent {
  const ExistingEvent({
    required this.id,
    required this.key,
    this.device = '',
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
  });

  final String id;
  final String key;

  /// Gerätekennung des Handys, das den Termin angelegt hat ('' = Version vor 1.0.4).
  final String device;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;

  bool matches(PlannedEvent p) =>
      title == p.title && allDay == p.allDay && start.isAtSameMomentAs(p.start) && end.isAtSameMomentAs(p.end);
}

/// Kennung aus der Beschreibung lesen, oder null bei fremden Terminen.
String? markerOf(String? description) {
  if (description == null) return null;
  final i = description.lastIndexOf(exportMarker);
  if (i < 0) return null;
  // Nur die Kennung selbst (uid_JJJJMMTT_platz): Google kann die Beschreibung in HTML verpacken.
  final m = _keyRe.firstMatch(description.substring(i + exportMarker.length));
  return m?.group(0);
}

final _keyRe = RegExp(r'[A-Za-z0-9]+_\d{8}_\d');
final _deviceRe = RegExp(deviceMarker + r'([a-z0-9]{8})');

/// Gerätekennung aus der Beschreibung, '' bei Terminen älterer Versionen.
String deviceOf(String? description) {
  if (description == null) return '';
  final i = description.lastIndexOf(exportMarker);
  if (i < 0) return '';
  return _deviceRe.firstMatch(description.substring(i))?.group(1) ?? '';
}

/// Neue zufällige Gerätekennung (8 Zeichen a–z, 0–9).
String newDeviceId([Random? random]) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = random ?? Random.secure();
  return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Gewünschte Termine aus den Einträgen. [onlyOwner] = nur diese Person, sonst ganze Familie.
List<PlannedEvent> plannedEvents({
  required Iterable<Entry> entries,
  required Map<String, ShiftType> typesById,
  required Map<String, Member> membersByUid,
  String? onlyOwner,
}) {
  final result = <PlannedEvent>[];
  for (final e in entries) {
    if (onlyOwner != null && e.owner != onlyOwner) continue;
    final type = typesById[e.shiftTypeId];
    final DateTime day;
    try {
      day = parseDateKey(e.date);
    } catch (_) {
      continue;
    }
    if (type == null) continue;
    final who = membersByUid[e.owner]?.name ?? '';
    // Titel = Kürzel (Jans Wunsch), Langname steht in der Beschreibung
    final short = type.code.trim().isEmpty ? type.name : type.code.trim();
    final title = onlyOwner == null && who.isNotEmpty ? '$who: $short' : short;
    final DateTime start, end;
    if (type.allDay) {
      start = DateTime(day.year, day.month, day.day);
      end = DateTime(day.year, day.month, day.day + 1);
    } else {
      start = DateTime(day.year, day.month, day.day, 0, type.start);
      end = DateTime(day.year, day.month, day.day + (type.overnight ? 1 : 0), 0, type.end);
    }
    final details = [
      '${type.name} (${type.code}), ${type.timeLabel}',
      if (who.isNotEmpty) who,
      if (e.note.isNotEmpty) e.note,
    ].join('\n');
    result.add(PlannedEvent(key: e.id, title: title, start: start, end: end, allDay: type.allDay, details: details));
  }
  return result;
}

/// Was zu tun ist, damit der Kalender genau [planned] enthält.
class SyncPlan {
  const SyncPlan({required this.create, required this.delete, required this.unchanged});

  final List<PlannedEvent> create;
  final List<String> delete;
  final int unchanged;

  bool get isEmpty => create.isEmpty && delete.isEmpty;
}

/// Plan für dieses Handy ([device]). Fremde Termine (andere Gerätekennung) werden nie gelöscht.
/// Termine älterer Versionen ohne Gerätekennung räumt jedes Handy weg: Sie stammen aus der
/// fehlerhaften Zeit, in der sich Handys gegenseitig Termine gelöscht haben.
SyncPlan planSync(List<PlannedEvent> planned, List<ExistingEvent> existing, {required String device}) {
  final mine = <String, List<ExistingEvent>>{};
  final othersByKey = <String, List<String>>{};
  final delete = <String>[];
  for (final e in existing) {
    if (e.device == device) {
      mine.putIfAbsent(e.key, () => []).add(e);
    } else if (e.device.isEmpty) {
      delete.add(e.id);
    } else {
      othersByKey.putIfAbsent(e.key, () => []).add(e.device);
    }
  }
  final create = <PlannedEvent>[];
  var unchanged = 0;
  final plannedKeys = <String>{};
  for (final p in planned) {
    if (!plannedKeys.add(p.key)) continue;
    final found = mine[p.key] ?? const <ExistingEvent>[];
    // Ein anderes Handy mit kleinerer Kennung hat diese Schicht schon im selben Kalender
    final covered = (othersByKey[p.key] ?? const <String>[]).any((d) => d.compareTo(device) < 0);
    final keep = covered ? null : found.where((e) => e.matches(p)).firstOrNull;
    if (covered || keep != null) {
      unchanged++;
    } else {
      create.add(p);
    }
    delete.addAll(found.where((e) => !identical(e, keep)).map((e) => e.id));
  }
  for (final entry in mine.entries) {
    if (!plannedKeys.contains(entry.key)) delete.addAll(entry.value.map((e) => e.id));
  }
  return SyncPlan(create: create, delete: delete, unchanged: unchanged);
}

/// Einstellungen des Exports (auf dem Handy gespeichert, nicht in der Cloud).
@immutable
class ExportConfig {
  const ExportConfig({required this.calendarId, required this.calendarName, required this.wholeFamily});

  final String calendarId;
  final String calendarName;
  final bool wholeFamily;
}

/// Ergebnis eines Abgleichs für die Anzeige.
@immutable
class ExportResult {
  const ExportResult({
    required this.created,
    required this.deleted,
    required this.unchanged,
    required this.at,
    this.perPerson = const {},
    this.skipped = 0,
  });

  final int created, deleted, unchanged;
  final DateTime at;

  /// Übertragene Schichten je Person (Name → Anzahl).
  final Map<String, int> perPerson;

  /// Einträge ohne bekannte Schichtart (nicht übertragbar).
  final int skipped;

  String get label {
    final t = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final total = perPerson.values.fold(0, (a, b) => a + b);
    final people = perPerson.entries.map((e) => '${e.key} ${e.value}').join(', ');
    final changes = created == 0 && deleted == 0 ? 'keine Änderung nötig' : '$created neu, $deleted entfernt';
    final skip = skipped > 0 ? ' $skipped Einträge ohne Schichtart übersprungen.' : '';
    return 'Abgeglichen um $t: $total Schichten im Kalender${people.isEmpty ? '' : ' ($people)'}, $changes.$skip';
  }
}

/// Anzahl je Person, in der Reihenfolge der Mitglieder.
Map<String, int> countPerPerson(List<PlannedEvent> planned, Iterable<Entry> entries, List<Member> members) {
  final ownerByKey = {for (final e in entries) e.id: e.owner};
  final counts = <String, int>{};
  for (final p in planned) {
    final owner = ownerByKey[p.key];
    if (owner != null) counts[owner] = (counts[owner] ?? 0) + 1;
  }
  return {
    for (final m in members)
      if (counts.containsKey(m.uid)) m.name: counts[m.uid]!,
  };
}

class CalendarExport {
  CalendarExport._();

  static final instance = CalendarExport._();

  static const _kId = 'export_calendar_id', _kName = 'export_calendar_name', _kFamily = 'export_family';
  static const _kDevice = 'export_device_id';

  /// Kennung dieses Handys für die exportierten Termine (bleibt bis zur Neuinstallation gleich).
  String _device = '';

  final config = ValueNotifier<ExportConfig?>(null);
  final lastResult = ValueNotifier<ExportResult?>(null);
  final lastError = ValueNotifier<String?>(null);

  DeviceCalendar get _cal => DeviceCalendar.instance;
  bool _loaded = false;
  Future<void>? _running;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      _device = p.getString(_kDevice) ?? '';
      if (_device.isEmpty) {
        _device = newDeviceId();
        await p.setString(_kDevice, _device);
      }
      final id = p.getString(_kId);
      if (id != null && id.isNotEmpty) {
        config.value = ExportConfig(
          calendarId: id,
          calendarName: p.getString(_kName) ?? '',
          wholeFamily: p.getBool(_kFamily) ?? false,
        );
      }
    } catch (e) {
      debugPrint('Export-Einstellungen nicht lesbar: $e');
    }
  }

  Future<void> save(ExportConfig? c) async {
    final p = await SharedPreferences.getInstance();
    if (c == null) {
      await p.remove(_kId);
      await p.remove(_kName);
      await p.remove(_kFamily);
    } else {
      await p.setString(_kId, c.calendarId);
      await p.setString(_kName, c.calendarName);
      await p.setBool(_kFamily, c.wholeFamily);
    }
    config.value = c;
    lastResult.value = null;
    lastError.value = null;
  }

  /// Fragt nach der Kalender-Berechtigung. true = erteilt.
  Future<bool> ensurePermission() async {
    var status = await _cal.hasPermissions();
    if (status != CalendarPermissionStatus.granted) status = await _cal.requestPermissions();
    return status == CalendarPermissionStatus.granted;
  }

  /// Beschreibbare, sichtbare Kalender, Google-Konten zuerst.
  Future<List<Calendar>> writableCalendars() async {
    final list = (await _cal.listCalendars()).where((c) => !c.readOnly && !c.hidden).toList();
    int rank(Calendar c) => (c.accountType ?? '').contains('google') ? 0 : 1;
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : '${a.accountName}${a.name}'.compareTo('${b.accountName}${b.name}');
    });
    return list;
  }

  Future<List<ExistingEvent>> _existing(String calendarId, DateTime from, DateTime to) async {
    final events = await _cal.listEvents(from, to, calendarIds: [calendarId]);
    return [
      for (final e in events)
        if (e.calendarId == calendarId && !e.isRecurring && markerOf(e.description) != null)
          ExistingEvent(
            id: e.eventId,
            key: markerOf(e.description)!,
            device: deviceOf(e.description),
            title: e.title,
            start: e.startDate,
            end: e.endDate,
            allDay: e.isAllDay,
          ),
    ];
  }

  /// Gleicht den gewählten Kalender mit den Einträgen ab. Läuft nie doppelt gleichzeitig.
  /// Jeder Termin wird einzeln geschrieben: Scheitert einer, laufen die übrigen trotzdem weiter.
  Future<void> sync({
    required String uid,
    required List<Member> members,
    required List<ShiftType> types,
    required List<Entry> entries,
    DateTime? now,
  }) async {
    while (_running != null) {
      try {
        await _running!.timeout(const Duration(minutes: 2));
      } on TimeoutException {
        _running = null; // hängender Lauf darf spätere nicht blockieren
      }
    }
    await load();
    final c = config.value;
    if (c == null || _device.isEmpty) return;
    final done = Completer<void>();
    _running = done.future;
    final errors = <String>[];
    try {
      final (from, to) = exportRange(now ?? DateTime.now());
      final fromKey = dateKey(from), toKey = dateKey(to);
      final typesById = {for (final t in types) t.id: t};
      final inRange = entries
          .where((e) => e.date.compareTo(fromKey) >= 0 && e.date.compareTo(toKey) <= 0)
          .where((e) => c.wholeFamily || e.owner == uid)
          .toList();
      final planned = plannedEvents(
        entries: inRange,
        typesById: typesById,
        membersByUid: {for (final m in members) m.uid: m},
        onlyOwner: c.wholeFamily ? null : uid,
      );
      final skipped = inRange.where((e) => !typesById.containsKey(e.shiftTypeId)).length;
      // Ein Tag Puffer, damit Nachtschichten am Rand mitgezählt werden
      final listTo = to.add(const Duration(days: 2));
      var plan = planSync(planned, await _existing(c.calendarId, from, listTo), device: _device);
      final unchanged = plan.unchanged;
      // Erst anlegen, dann löschen: So fehlt nie eine Schicht, falls das Löschen scheitert.
      var created = 0, deleted = 0;
      for (var round = 0; round < 2; round++) {
        for (final p in plan.create) {
          if (await _create(c.calendarId, p, errors)) created++;
        }
        for (final id in plan.delete) {
          if (await _delete(id, errors)) deleted++;
        }
        // Kontrolle: Kalender neu lesen und prüfen, ob jetzt alles da ist
        plan = planSync(planned, await _existing(c.calendarId, from, listTo), device: _device);
        if (plan.create.isEmpty) break;
      }
      if (plan.create.isNotEmpty) {
        final sample = plan.create.take(3).map((p) => '${p.title} am ${dateKey(p.start)}').join(', ');
        errors.insert(0, '${plan.create.length} Schichten fehlen nach dem Abgleich im Kalender, z. B. $sample');
      }
      lastResult.value = ExportResult(
        created: created,
        deleted: deleted,
        unchanged: unchanged,
        at: DateTime.now(),
        perPerson: countPerPerson(planned, inRange, members),
        skipped: skipped,
      );
      lastError.value = errors.isEmpty ? null : '${errors.length} Probleme. ${errors.first}';
    } catch (e) {
      lastError.value = 'Kalender-Abgleich fehlgeschlagen: ${_describe(e)}';
    } finally {
      _running = null;
      done.complete();
    }
  }

  Future<bool> _create(String calendarId, PlannedEvent p, List<String> errors) async {
    try {
      await _cal
          .createEvent(
            calendarId: calendarId,
            title: p.title,
            startDate: p.start,
            endDate: p.end,
            isAllDay: p.allDay,
            description: p.descriptionFor(_device),
          )
          .timeout(const Duration(seconds: 20));
      return true;
    } catch (e) {
      errors.add('Anlegen „${p.title}“ am ${dateKey(p.start)}: ${_describe(e)}');
      return false;
    }
  }

  /// Löscht einen Termin. „Nicht gefunden“ zählt als erledigt (schon gelöscht).
  Future<bool> _delete(String id, List<String> errors) async {
    try {
      await _cal.deleteEvent(instanceId: id).timeout(const Duration(seconds: 20));
      return true;
    } on DeviceCalendarException catch (e) {
      if (e.errorCode == DeviceCalendarError.notFound) return true;
      errors.add('Löschen von Termin $id: ${_describe(e)}');
    } catch (e) {
      errors.add('Löschen von Termin $id: ${_describe(e)}');
    }
    return false;
  }

  static String _describe(Object e) {
    if (e is DeviceCalendarException) {
      if (e.errorCode == DeviceCalendarError.permissionDenied) {
        return 'keine Berechtigung für den Kalender (Einstellungen → Apps → Schichtplan → Berechtigungen)';
      }
      return '${e.errorCode.name}: ${e.message}';
    }
    if (e is TimeoutException) return 'keine Antwort vom Kalender (Zeitüberschreitung)';
    return '$e';
  }

  /// Entfernt die von diesem Handy (oder einer alten Version) angelegten Termine im Zeitraum
  /// (beim Ausschalten). Termine anderer Handys bleiben stehen.
  Future<int> removeAll(String calendarId, {DateTime? now}) async {
    await load();
    final (from, to) = exportRange(now ?? DateTime.now());
    final existing = (await _existing(
      calendarId,
      from,
      to.add(const Duration(days: 2)),
    )).where((e) => e.device.isEmpty || e.device == _device);
    final errors = <String>[];
    var n = 0;
    for (final e in existing) {
      if (await _delete(e.id, errors)) n++;
    }
    if (errors.isNotEmpty) throw StateError('${errors.length} Termine ließen sich nicht löschen. ${errors.first}');
    return n;
  }
}
