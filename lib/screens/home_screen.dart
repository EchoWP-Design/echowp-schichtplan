import 'package:flutter/material.dart';

import '../models.dart';
import '../repo.dart';
import 'calendar_screen.dart';
import 'family_screen.dart';
import 'shifts_screen.dart';
import 'update_card.dart';
import 'widget_feeder.dart';

/// Hauptbildschirm mit drei Reitern: Kalender, Meine Schichten, Familie.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repo, required this.familyId});

  final Repo repo;
  final String familyId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late Stream<List<Member>> _members = widget.repo.members(widget.familyId);
  late Stream<List<ShiftType>> _types = widget.repo.shiftTypes(widget.familyId);

  int _autoRetries = 0;
  bool _retryScheduled = false;

  void _resubscribe() {
    setState(() {
      _members = widget.repo.members(widget.familyId);
      _types = widget.repo.shiftTypes(widget.familyId);
    });
  }

  /// Nach einem Fehler (z. B. Netz weg oder Mitgliedschaft noch nicht beim Server)
  /// bis zu dreimal selbst neu verbinden, danach nur noch per Knopf.
  void _scheduleAutoRetry() {
    if (_retryScheduled || _autoRetries >= 3) return;
    _retryScheduled = true;
    _autoRetries++;
    Future<void>.delayed(Duration(seconds: 2 * _autoRetries), () {
      _retryScheduled = false;
      if (mounted) _resubscribe();
    });
  }

  bool _updateChecked = false;
  final _feeder = GlobalKey<WidgetFeederState>();

  @override
  void initState() {
    super.initState();
    // Einmal pro Start leise nach einer neuen Version sehen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _updateChecked) return;
      _updateChecked = true;
      checkForUpdateQuietly(context);
    });
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.familyId != widget.familyId || old.repo.uid != widget.repo.uid) {
      _autoRetries = 0;
      _members = widget.repo.members(widget.familyId);
      _types = widget.repo.shiftTypes(widget.familyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Member>>(
      stream: _members,
      builder: (context, memberSnap) {
        return StreamBuilder<List<ShiftType>>(
          stream: _types,
          builder: (context, typeSnap) {
            final error = memberSnap.error ?? typeSnap.error;
            if (error != null) {
              _scheduleAutoRetry();
              return Scaffold(
                appBar: AppBar(title: const Text('EchoWP Schichtplan')),
                body: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Die Daten konnten nicht geladen werden.\n\n$error'),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        _autoRetries = 0;
                        _resubscribe();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Erneut versuchen'),
                    ),
                  ],
                ),
              );
            }
            _autoRetries = 0;
            if (!memberSnap.hasData || !typeSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final members = memberSnap.data!;
            final types = typeSnap.data!;
            final pages = [
              CalendarScreen(repo: widget.repo, familyId: widget.familyId, members: members, types: types),
              ShiftsScreen(repo: widget.repo, familyId: widget.familyId, types: types),
              FamilyScreen(
                repo: widget.repo,
                familyId: widget.familyId,
                members: members,
                onExportSync: () => _feeder.currentState?.syncExportNow() ?? Future.value(),
              ),
            ];
            return WidgetFeeder(
              key: _feeder,
              repo: widget.repo,
              familyId: widget.familyId,
              members: members,
              types: types,
              child: Scaffold(
                body: IndexedStack(index: _tab, children: pages),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Kalender'),
                    NavigationDestination(icon: Icon(Icons.work_history), label: 'Meine Schichten'),
                    NavigationDestination(icon: Icon(Icons.family_restroom), label: 'Familie'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
