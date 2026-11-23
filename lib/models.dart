import 'package:flutter/material.dart';

import 'logic.dart';

/// Eine Schichtart aus der Schicht-Datenbank einer Person.
class ShiftType {
  const ShiftType({
    required this.id,
    required this.owner,
    required this.name,
    required this.code,
    required this.start,
    required this.end,
    required this.color,
    this.allDay = false,
    this.order = 0,
    this.archived = false,
  });

  final String id;
  final String owner;
  final String name;
  final String code;

  /// Beginn und Ende in Minuten seit Mitternacht.
  final int start;
  final int end;

  /// Farbe als ARGB-Wert.
  final int color;
  final bool allDay;
  final int order;
  final bool archived;

  Color get colorValue => Color(color);

  bool get overnight => !allDay && crossesMidnight(start, end);

  String get timeLabel {
    if (allDay) return 'ganztägig';
    final base = '${formatMinutes(start)}–${formatMinutes(end)}';
    return overnight ? '$base, über Mitternacht' : base;
  }

  Map<String, dynamic> toMap() => {
        'owner': owner,
        'name': name,
        'code': code,
        'start': start,
        'end': end,
        'color': color,
        'allDay': allDay,
        'order': order,
        'archived': archived,
      };

  factory ShiftType.fromMap(String id, Map<String, dynamic> m) => ShiftType(
        id: id,
        owner: m['owner'] as String? ?? '',
        name: m['name'] as String? ?? '',
        code: m['code'] as String? ?? '',
        start: (m['start'] as num?)?.toInt() ?? 0,
        end: (m['end'] as num?)?.toInt() ?? 0,
        color: (m['color'] as num?)?.toInt() ?? shiftPalette.first.toARGB32(),
        allDay: m['allDay'] as bool? ?? false,
        order: (m['order'] as num?)?.toInt() ?? 0,
        archived: m['archived'] as bool? ?? false,
      );

  ShiftType copyWith({
    String? id,
    String? name,
    String? code,
    int? start,
    int? end,
    int? color,
    bool? allDay,
    int? order,
    bool? archived,
  }) =>
      ShiftType(
        id: id ?? this.id,
        owner: owner,
        name: name ?? this.name,
        code: code ?? this.code,
        start: start ?? this.start,
        end: end ?? this.end,
        color: color ?? this.color,
        allDay: allDay ?? this.allDay,
        order: order ?? this.order,
        archived: archived ?? this.archived,
      );
}

/// Eine eingetragene Schicht an einem Tag.
class Entry {
  const Entry({
    required this.id,
    required this.owner,
    required this.date,
    required this.slot,
    required this.shiftTypeId,
    this.note = '',
  });

  final String id;
  final String owner;

  /// Datum als `JJJJ-MM-TT`.
  final String date;

  /// 1 oder 2 (zwei Dienste an einem Tag).
  final int slot;
  final String shiftTypeId;
  final String note;

  Map<String, dynamic> toMap() => {
        'owner': owner,
        'date': date,
        'slot': slot,
        'shiftTypeId': shiftTypeId,
        'note': note,
      };

  factory Entry.fromMap(String id, Map<String, dynamic> m) => Entry(
        id: id,
        owner: m['owner'] as String? ?? '',
        date: m['date'] as String? ?? '',
        slot: (m['slot'] as num?)?.toInt() ?? 1,
        shiftTypeId: m['shiftTypeId'] as String? ?? '',
        note: m['note'] as String? ?? '',
      );
}

/// Ein Familienmitglied.
class Member {
  const Member({required this.uid, required this.name, required this.color});

  final String uid;
  final String name;
  final int color;

  Color get colorValue => Color(color);

  factory Member.fromMap(String uid, Map<String, dynamic> m) => Member(
        uid: uid,
        name: m['name'] as String? ?? 'Unbekannt',
        color: (m['color'] as num?)?.toInt() ?? memberPalette.first.toARGB32(),
      );
}

class Family {
  const Family({required this.id, required this.name, required this.inviteCode, required this.createdBy});

  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;

  factory Family.fromMap(String id, Map<String, dynamic> m) => Family(
        id: id,
        name: m['name'] as String? ?? 'Familie',
        inviteCode: m['inviteCode'] as String? ?? '',
        createdBy: m['createdBy'] as String? ?? '',
      );
}

/// Einträge nach Tag gruppiert, innerhalb eines Tages nach Platz sortiert.
Map<String, List<Entry>> groupByDay(Iterable<Entry> entries) {
  final map = <String, List<Entry>>{};
  for (final e in entries) {
    map.putIfAbsent(e.date, () => []).add(e);
  }
  for (final list in map.values) {
    list.sort((a, b) => a.slot.compareTo(b.slot));
  }
  return map;
}

/// Erster freier Platz (1 oder 2) einer Person an einem Tag, sonst null.
int? freeSlot(Iterable<Entry> dayEntries, String uid) {
  final used = dayEntries.where((e) => e.owner == uid).map((e) => e.slot).toSet();
  for (final s in [1, 2]) {
    if (!used.contains(s)) return s;
  }
  return null;
}
