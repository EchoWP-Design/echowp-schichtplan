import 'package:flutter/material.dart';

import '../calendar_export.dart';

/// Karte „Google Kalender“: Export einrichten, Stand anzeigen, ausschalten.
class ExportCard extends StatefulWidget {
  const ExportCard({super.key, required this.onSyncNow});

  /// Startet einen Abgleich mit den aktuellen Daten (kommt vom Hauptbildschirm).
  final Future<void> Function() onSyncNow;

  @override
  State<ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends State<ExportCard> {
  final _export = CalendarExport.instance;
  bool _busy = false;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack('Fehler: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setup() => _run(() async {
        if (!await _export.ensurePermission()) {
          _snack('Ohne Kalender-Berechtigung geht der Export nicht.');
          return;
        }
        final calendars = await _export.writableCalendars();
        if (!mounted) return;
        if (calendars.isEmpty) {
          _snack('Kein beschreibbarer Kalender gefunden. Ist ein Google-Konto auf dem Handy eingerichtet?');
          return;
        }
        final current = _export.config.value;
        var wholeFamily = current?.wholeFamily ?? false;
        final chosen = await showDialog<String>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setLocal) => AlertDialog(
              title: const Text('In welchen Kalender?'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Schichten der ganzen Familie'),
                      subtitle: Text(wholeFamily ? 'Mit Namen im Titel' : 'Aus: nur meine eigenen Schichten'),
                      value: wholeFamily,
                      onChanged: (v) => setLocal(() => wholeFamily = v),
                    ),
                    const Divider(),
                    for (final c in calendars)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.circle,
                          color: _hexColor(c.colorHex) ?? Theme.of(context).colorScheme.outline,
                        ),
                        title: Text(c.name),
                        subtitle: Text(c.accountName ?? ''),
                        selected: c.id == current?.calendarId,
                        onTap: () => Navigator.pop(context, c.id),
                      ),
                  ],
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen'))],
            ),
          ),
        );
        if (chosen == null) return;
        final cal = calendars.firstWhere((c) => c.id == chosen);
        // Wechsel des Kalenders: alte Termine im bisherigen Kalender entfernen
        if (current != null && current.calendarId != chosen) {
          await _export.removeAll(current.calendarId);
        }
        await _export.save(ExportConfig(
          calendarId: cal.id,
          calendarName: [cal.name, if ((cal.accountName ?? '').isNotEmpty && cal.accountName != cal.name) cal.accountName]
              .join(' · '),
          wholeFamily: wholeFamily,
        ));
        await widget.onSyncNow();
      });

  Future<void> _disable() async {
    final c = _export.config.value;
    if (c == null) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export ausschalten?'),
        content: const Text('Sollen die von der App eingetragenen Termine aus dem Kalender entfernt werden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Termine behalten')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Entfernen')),
        ],
      ),
    );
    if (remove == null) return;
    await _run(() async {
      if (remove) {
        final n = await _export.removeAll(c.calendarId);
        _snack('$n Termine entfernt.');
      }
      await _export.save(null);
    });
  }

  static Color? _hexColor(String? hex) {
    if (hex == null) return null;
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (v == null) return null;
    return Color(hex.replaceFirst('#', '').length <= 6 ? 0xFF000000 | v : v);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<ExportConfig?>(
          valueListenable: _export.config,
          builder: (context, config, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Google Kalender', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                config == null
                    ? 'Aus. Die Schichten können zusätzlich in einen Kalender auf diesem Handy '
                        '(z. B. dein Google-Kalender) übertragen werden, ohne Doppelungen.'
                    : '${config.wholeFamily ? 'Schichten der Familie' : 'Meine Schichten'} → ${config.calendarName}',
              ),
              if (config != null) ...[
                ValueListenableBuilder<String?>(
                  valueListenable: _export.lastError,
                  builder: (context, error, _) => error == null
                      ? ValueListenableBuilder<ExportResult?>(
                          valueListenable: _export.lastResult,
                          builder: (context, r, _) => r == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(r.label, style: Theme.of(context).textTheme.bodySmall),
                                ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _setup,
                    icon: const Icon(Icons.event),
                    label: Text(config == null ? 'Einrichten' : 'Ändern'),
                  ),
                  if (config != null) ...[
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _run(widget.onSyncNow),
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync),
                      label: const Text('Jetzt abgleichen'),
                    ),
                    TextButton(onPressed: _busy ? null : _disable, child: const Text('Ausschalten')),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
