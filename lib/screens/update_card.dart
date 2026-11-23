import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../updater.dart';

/// Öffnet die neue APK im Browser; Android fragt danach selbst nach der Installation.
Future<void> openDownload(BuildContext context, ReleaseInfo info) async {
  final url = Uri.parse(info.apkUrl ?? info.pageUrl);
  final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Browser ließ sich nicht öffnen: $url')));
  }
}

/// Einmal beim Start still prüfen und bei einer neuen Version einen Hinweis zeigen.
Future<void> checkForUpdateQuietly(BuildContext context, {Updater? updater}) async {
  try {
    final r = await (updater ?? Updater()).latest();
    if (r == null || !Updater.isNewer(r) || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Neue Version ${r.label} verfügbar'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(label: 'Laden', onPressed: () => openDownload(context, r)),
      ),
    );
  } catch (_) {
    // Ohne Netz kein Hinweis; der Knopf unter „Familie“ meldet den Fehler.
  }
}

/// Karte „App-Version“ mit dem Knopf „Nach Updates suchen“.
class UpdateCard extends StatefulWidget {
  const UpdateCard({super.key, this.updater});

  /// Für Tests austauschbar.
  final Updater? updater;

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> {
  bool _busy = false;
  String? _message;
  ReleaseInfo? _update;

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _message = null;
      _update = null;
    });
    String message;
    ReleaseInfo? update;
    try {
      final r = await (widget.updater ?? Updater()).latest();
      if (r != null && Updater.isNewer(r)) {
        update = r;
        message = 'Neue Version ${r.label} verfügbar.';
      } else {
        message = 'Du hast die neueste Version.';
      }
    } on UpdateException catch (e) {
      message = e.message;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
      _update = update;
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('App-Version', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('EchoWP Schichtplan $appVersionLabel'),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, key: const ValueKey('update-message')),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _check,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.system_update),
                  label: const Text('Nach Updates suchen'),
                ),
                if (update != null)
                  FilledButton.icon(
                    onPressed: () => openDownload(context, update),
                    icon: const Icon(Icons.download),
                    label: const Text('Herunterladen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
