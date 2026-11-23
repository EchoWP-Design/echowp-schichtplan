// Export der Schichten in einen Kalender auf dem Handy (z. B. das Google-Konto).
//
// Duplikate sind ausgeschlossen: Jeder exportierte Termin trägt in der Beschreibung die feste
// Kennung des Eintrags (`EchoWP-Schichtplan-ID: <entryId>`). Beim Abgleich gilt nur der
// Schichtplan: fehlende Termine werden angelegt, geänderte neu geschrieben, überzählige
// (auch doppelte) gelöscht. Termine ohne Kennung bleiben unangetastet.
import 'dart:async';

import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logic.dart';
import 'models.dart';

const exportMarker = 'EchoWP-Schichtplan-ID: ';

/// Zeitraum des Abgleichs: zwei Wochen zurück, vier Monate voraus.
(DateTime, DateTime) exportRange(DateTime today) => (
      DateTime(today.year, today.month, today.day - 14),
      DateTime(today.year, today.month, today.day + 120),
    );

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

  String get description => '$details\n\n$exportMarker$key';
}

/// Ein vorhandener, von der App angelegter Termin.
@immutable
class ExistingEvent {
  const ExistingEvent({
    required this.id,
    required this.key,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
  });

  final String id;
  final String key;
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
  final key = description.substring(i + exportMarker.length).trim().split(RegExp(r'\s')).first;
  return key.isEmpty ? null : key;
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
    final title = onlyOwner == null && who.isNotEmpty ? '$who: ${type.name}' : type.name;
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

SyncPlan planSync(List<PlannedEvent> planned, List<ExistingEvent> existing) {
  final byKey = <String, List<ExistingEvent>>{};
  for (final e in existing) {
    byKey.putIfAbsent(e.key, () => []).add(e);
  }
  final create = <PlannedEvent>[];
  final delete = <String>[];
  var unchanged = 0;
  final plannedKeys = <String>{};
  for (final p in planned) {
    if (!plannedKeys.add(p.key)) continue;
    final found = byKey[p.key] ?? const <ExistingEvent>[];
    final keep = found.where((e) => e.matches(p)).firstOrNull;
    if (keep != null) {
      unchanged++;
    } else {
      create.add(p);
    }
    delete.addAll(found.where((e) => !identical(e, keep)).map((e) => e.id));
  }
  for (final e in existing) {
    if (!plannedKeys.contains(e.key)) delete.add(e.id);
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
  const ExportResult({required this.created, required this.deleted, required this.unchanged, required this.at});

  final int created, deleted, unchanged;
  final DateTime at;

  String get label {
    final t = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    if (created == 0 && deleted == 0) return 'Abgeglichen um $t: alles aktuell ($unchanged Termine).';
    return 'Abgeglichen um $t: $created neu oder geändert, $deleted entfernt, $unchanged unverändert.';
  }
}

class CalendarExport {
  CalendarExport._();

  static final instance = CalendarExport._();

  static const _kId = 'export_calendar_id', _kName = 'export_calendar_name', _kFamily = 'export_family';

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
            title: e.title,
            start: e.startDate,
            end: e.endDate,
            allDay: e.isAllDay,
          ),
    ];
  }

  /// Gleicht den gewählten Kalender mit den Einträgen ab. Läuft nie doppelt gleichzeitig.
  Future<void> sync({
    required String uid,
    required List<Member> members,
    required List<ShiftType> types,
    required List<Entry> entries,
    DateTime? now,
  }) async {
    while (_running != null) {
      await _running;
    }
    final c = config.value;
    if (c == null) return;
    final done = Completer<void>();
    _running = done.future;
    try {
      final (from, to) = exportRange(now ?? DateTime.now());
      final fromKey = dateKey(from), toKey = dateKey(to);
      final planned = plannedEvents(
        entries: entries.where((e) => e.date.compareTo(fromKey) >= 0 && e.date.compareTo(toKey) <= 0),
        typesById: {for (final t in types) t.id: t},
        membersByUid: {for (final m in members) m.uid: m},
        onlyOwner: c.wholeFamily ? null : uid,
      );
      // Ein Tag Puffer, damit Nachtschichten am Rand mitgezählt werden
      final existing = await _existing(c.calendarId, from, to.add(const Duration(days: 2)));
      final plan = planSync(planned, existing);
      for (final id in plan.delete) {
        await _cal.deleteEvent(instanceId: id);
      }
      for (final p in plan.create) {
        await _cal.createEvent(
          calendarId: c.calendarId,
          title: p.title,
          startDate: p.start,
          endDate: p.end,
          isAllDay: p.allDay,
          description: p.description,
        );
      }
      lastResult.value = ExportResult(
        created: plan.create.length,
        deleted: plan.delete.length,
        unchanged: plan.unchanged,
        at: DateTime.now(),
      );
      lastError.value = null;
    } catch (e) {
      lastError.value = e is DeviceCalendarException && e.errorCode == DeviceCalendarError.permissionDenied
          ? 'Keine Berechtigung für den Kalender. Bitte unter Einstellungen → Apps → Schichtplan erlauben.'
          : 'Kalender-Abgleich fehlgeschlagen: $e';
    } finally {
      _running = null;
      done.complete();
    }
  }

  /// Entfernt alle von der App angelegten Termine im Zeitraum (beim Ausschalten).
  Future<int> removeAll(String calendarId, {DateTime? now}) async {
    final (from, to) = exportRange(now ?? DateTime.now());
    final existing = await _existing(calendarId, from, to.add(const Duration(days: 2)));
    for (final e in existing) {
      await _cal.deleteEvent(instanceId: e.id);
    }
    return existing.length;
  }
}
