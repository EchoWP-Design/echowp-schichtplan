// Reine Hilfsfunktionen ohne Firebase – vollständig durch Tests abgedeckt.
import 'dart:math';

import 'package:flutter/material.dart';

/// 16 Vorschlagsfarben für Schichtarten.
const List<Color> shiftPalette = [
  Color(0xFFE8590C), // Orange
  Color(0xFFF59F00), // Bernstein
  Color(0xFFFFD400), // EchoWP-Gelb
  Color(0xFF94D82D), // Hellgrün
  Color(0xFF2F9E44), // Grün
  Color(0xFF0CA678), // Türkisgrün
  Color(0xFF1098AD), // Petrol
  Color(0xFF4DABF7), // Hellblau
  Color(0xFF1C7ED6), // Blau
  Color(0xFF364FC7), // Indigo
  Color(0xFF7048E8), // Violett
  Color(0xFFAE3EC9), // Lila
  Color(0xFFE64980), // Pink
  Color(0xFFC92A2A), // Rot
  Color(0xFF868E96), // Grau
  Color(0xFF5C3D2E), // Braun
];

/// Farben, mit denen Personen in der Familienansicht markiert werden.
const List<Color> memberPalette = [
  Color(0xFF1C7ED6),
  Color(0xFFE64980),
  Color(0xFF2F9E44),
  Color(0xFFF59F00),
  Color(0xFF7048E8),
  Color(0xFF1098AD),
  Color(0xFFC92A2A),
  Color(0xFF5C3D2E),
];

String _two(int n) => n.toString().padLeft(2, '0');

/// Datum als sortierbarer Schlüssel `JJJJ-MM-TT` (so steht es in Firestore).
String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDateKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Feste Kennung eines Eintrags: Person, Tag und Platz (1 oder 2).
/// Wird derselbe Eintrag zweimal gespeichert, überschreibt er sich selbst –
/// Duplikate sind damit ausgeschlossen.
String entryId(String uid, DateTime day, int slot) => '${uid}_${dateKey(day).replaceAll('-', '')}_$slot';

/// Minuten seit Mitternacht als `HH:MM`.
String formatMinutes(int minutes) {
  final m = minutes % (24 * 60);
  return '${_two(m ~/ 60)}:${_two(m % 60)}';
}

int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

TimeOfDay timeOfMinutes(int minutes) {
  final m = minutes % (24 * 60);
  return TimeOfDay(hour: m ~/ 60, minute: m % 60);
}

/// Ende vor (oder gleich) Beginn bedeutet: die Schicht geht über Mitternacht.
bool crossesMidnight(int start, int end) => end <= start;

int durationMinutes(int start, int end) => crossesMidnight(start, end) ? end + 24 * 60 - start : end - start;

/// Alle Tage, die die Monatsansicht zeigt: volle Wochen von Montag bis Sonntag.
List<DateTime> monthGridDays(int year, int month) {
  final first = DateTime(year, month, 1);
  final offset = first.weekday - DateTime.monday;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final weeks = ((offset + daysInMonth) / 7).ceil();
  return List.generate(weeks * 7, (i) => DateTime(year, month, 1 - offset + i));
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

const String inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Einladungscode, 6 Zeichen, ohne leicht verwechselbare Zeichen (0/O, 1/I).
String newInviteCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(6, (_) => inviteAlphabet[r.nextInt(inviteAlphabet.length)]).join();
}

String normalizeInviteCode(String input) => input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

String? validateShiftName(String? v) => (v == null || v.trim().isEmpty) ? 'Bitte einen Namen eingeben' : null;

String? validateShiftCode(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Bitte ein Kürzel eingeben';
  if (t.length > 3) return 'Höchstens 3 Zeichen';
  return null;
}

/// Schwarz oder Weiß – je nachdem, was auf der Hintergrundfarbe besser lesbar ist.
Color readableOn(Color background) => background.computeLuminance() > 0.4 ? const Color(0xFF0A0A0A) : Colors.white;
