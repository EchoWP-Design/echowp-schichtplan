import 'dart:async';

import 'package:flutter/widgets.dart';

import '../calendar_export.dart';
import '../home_widgets.dart';
import '../logic.dart';
import '../models.dart';
import '../repo.dart';

/// Hält die Startbildschirm-Widgets und den Kalender-Export aktuell, solange die App läuft:
/// bei jeder Änderung der Schichten, Personen oder Schichtarten und beim Zurückkehren in die App.
class WidgetFeeder extends StatefulWidget {
  const WidgetFeeder({
    super.key,
    required this.repo,
    required this.familyId,
    required this.members,
    required this.types,
    required this.child,
  });

  final Repo repo;
  final String familyId;
  final List<Member> members;
  final List<ShiftType> types;
  final Widget child;

  @override
  State<WidgetFeeder> createState() => WidgetFeederState();
}

class WidgetFeederState extends State<WidgetFeeder> with WidgetsBindingObserver {
  StreamSubscription<List<Entry>>? _sub;
  List<Entry>? _entries;
  String _rangeStart = '';
  Timer? _debounce;

  // Kalender-Export: eigener, längerer Zeitraum, nur wenn eingeschaltet
  final _export = CalendarExport.instance;
  StreamSubscription<List<Entry>>? _exportSub;
  List<Entry>? _exportEntries;
  String _exportStart = '';
  Timer? _exportDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribe();
    _export.config.addListener(_exportConfigChanged);
    _export.load().then((_) => _exportConfigChanged());
  }

  void _exportConfigChanged() {
    if (!mounted) return;
    if (_export.config.value == null) {
      _exportSub?.cancel();
      _exportSub = null;
      _exportEntries = null;
      _exportStart = '';
    } else {
      _subscribeExport();
    }
  }

  void _subscribeExport() {
    final (from, to) = exportRange(DateTime.now());
    if (_exportSub != null && dateKey(from) == _exportStart) return;
    _exportStart = dateKey(from);
    _exportSub?.cancel();
    _exportSub = widget.repo.entriesConfirmed(widget.familyId, dateKey(from), dateKey(to)).listen((list) {
      _exportEntries = list;
      _scheduleExport();
    }, onError: (_) {});
  }

  void _scheduleExport() {
    _exportDebounce?.cancel();
    _exportDebounce = Timer(const Duration(seconds: 5), () {
      if (mounted) syncExportNow();
    });
  }

  /// Abgleich sofort (Knopf „Jetzt abgleichen“ oder nach dem Einrichten).
  Future<void> syncExportNow() async {
    if (_export.config.value == null) return;
    _subscribeExport();
    var entries = _exportEntries;
    if (entries == null) {
      final (from, to) = exportRange(DateTime.now());
      try {
        entries = await widget.repo
            .entriesConfirmed(widget.familyId, dateKey(from), dateKey(to))
            .first
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        _export.lastError.value = 'Keine Verbindung zum Schichtplan-Server. Abgleich später erneut versuchen.';
        return;
      }
    }
    await _export.sync(uid: widget.repo.uid, members: widget.members, types: widget.types, entries: entries);
  }

  void _subscribe() {
    final (from, to) = widgetRange(DateTime.now());
    if (_sub != null && dateKey(from) == _rangeStart) return;
    _rangeStart = dateKey(from);
    _sub?.cancel();
    _sub = widget.repo.entries(widget.familyId, dateKey(from), dateKey(to)).listen((list) {
      _entries = list;
      _schedule();
    }, onError: (_) {});
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      final entries = _entries;
      if (!mounted || entries == null) return;
      pushHomeWidgets(today: DateTime.now(), members: widget.members, types: widget.types, entries: entries);
    });
  }

  @override
  void didUpdateWidget(WidgetFeeder old) {
    super.didUpdateWidget(old);
    if (old.familyId != widget.familyId || old.repo.uid != widget.repo.uid) {
      _sub?.cancel();
      _sub = null;
      _entries = null;
      _subscribe();
      _exportSub?.cancel();
      _exportSub = null;
      _exportEntries = null;
      _exportConfigChanged();
    } else if (!identical(old.members, widget.members) || !identical(old.types, widget.types)) {
      _schedule();
      if (_exportEntries != null) _scheduleExport();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _subscribe(); // neuer Monat seit dem letzten Öffnen?
      _schedule(); // neuer Tag: „heute“ im Monatsbild verschieben
      if (_export.config.value != null) _subscribeExport();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _export.config.removeListener(_exportConfigChanged);
    _debounce?.cancel();
    _sub?.cancel();
    _exportDebounce?.cancel();
    _exportSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
