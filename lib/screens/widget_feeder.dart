import 'dart:async';

import 'package:flutter/widgets.dart';

import '../home_widgets.dart';
import '../logic.dart';
import '../models.dart';
import '../repo.dart';

/// Hält die Startbildschirm-Widgets aktuell, solange die App läuft:
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
  State<WidgetFeeder> createState() => _WidgetFeederState();
}

class _WidgetFeederState extends State<WidgetFeeder> with WidgetsBindingObserver {
  StreamSubscription<List<Entry>>? _sub;
  List<Entry>? _entries;
  String _rangeStart = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribe();
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
    } else if (!identical(old.members, widget.members) || !identical(old.types, widget.types)) {
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _subscribe(); // neuer Monat seit dem letzten Öffnen?
      _schedule(); // neuer Tag: „heute“ im Monatsbild verschieben
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
