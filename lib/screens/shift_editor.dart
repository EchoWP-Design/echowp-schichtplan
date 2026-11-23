import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';

/// Schichtart anlegen oder bearbeiten. Gibt die fertige [ShiftType] per `Navigator.pop` zurück.
class ShiftEditorScreen extends StatefulWidget {
  const ShiftEditorScreen({
    super.key,
    this.initial,
    required this.owner,
    this.nextOrder = 1,
    this.suggestedColor,
  });

  final ShiftType? initial;
  final String owner;
  final int nextOrder;
  final Color? suggestedColor;

  @override
  State<ShiftEditorScreen> createState() => _ShiftEditorScreenState();
}

class _ShiftEditorScreenState extends State<ShiftEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _code = TextEditingController(text: widget.initial?.code ?? '');
  late int _start = widget.initial?.start ?? 6 * 60;
  late int _end = widget.initial?.end ?? 14 * 60;
  late bool _allDay = widget.initial?.allDay ?? false;
  late bool _archived = widget.initial?.archived ?? false;
  late int _color =
      widget.initial?.color ?? (widget.suggestedColor ?? shiftPalette.first).toARGB32();

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: timeOfMinutes(start ? _start : _end),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = minutesOf(picked);
      } else {
        _end = minutesOf(picked);
      }
    });
  }

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final base = widget.initial;
    final result = ShiftType(
      id: base?.id ?? '',
      owner: base?.owner ?? widget.owner,
      name: _name.text.trim(),
      code: _code.text.trim(),
      start: _start,
      end: _end,
      color: _color,
      allDay: _allDay,
      order: base?.order ?? widget.nextOrder,
      archived: _archived,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final overnight = !_allDay && crossesMidnight(_start, _end);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Neue Schicht' : 'Schicht bearbeiten'),
        actions: [TextButton(onPressed: _save, child: const Text('Speichern', style: TextStyle(color: Colors.white)))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              key: const ValueKey('field-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name, z. B. Frühdienst', border: OutlineInputBorder()),
              validator: validateShiftName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('field-code'),
              controller: _code,
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Kürzel im Kalender, z. B. F', border: OutlineInputBorder()),
              validator: validateShiftCode,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ganztägig'),
              subtitle: const Text('Für Urlaub, frei, krank …'),
              value: _allDay,
              onChanged: (v) => setState(() => _allDay = v),
            ),
            if (!_allDay) ...[
              ListTile(
                key: const ValueKey('pick-start'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow),
                title: const Text('Beginn'),
                trailing: Text(formatMinutes(_start), style: const TextStyle(fontSize: 18)),
                onTap: () => _pickTime(true),
              ),
              ListTile(
                key: const ValueKey('pick-end'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stop),
                title: const Text('Ende'),
                trailing: Text(formatMinutes(_end), style: const TextStyle(fontSize: 18)),
                onTap: () => _pickTime(false),
              ),
              if (overnight)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Ende liegt vor Beginn: Die Schicht geht über Mitternacht.'),
                ),
            ],
            const SizedBox(height: 8),
            const Text('Farbe', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < shiftPalette.length; i++)
                  GestureDetector(
                    key: ValueKey('color-$i'),
                    onTap: () => setState(() => _color = shiftPalette[i].toARGB32()),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: shiftPalette[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == shiftPalette[i].toARGB32()
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: _color == shiftPalette[i].toARGB32()
                          ? Icon(Icons.check, color: readableOn(shiftPalette[i]))
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Vorschau', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _Preview(code: _code, name: _name, color: Color(_color)),
            if (widget.initial != null) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Archiviert'),
                subtitle: const Text('Nicht mehr zur Auswahl anbieten. Alte Einträge bleiben sichtbar.'),
                value: _archived,
                onChanged: (v) => setState(() => _archived = v),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(key: const ValueKey('save'), onPressed: _save, child: const Text('Speichern')),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.code, required this.name, required this.color});

  final TextEditingController code;
  final TextEditingController name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([code, name]),
      builder: (context, _) => Row(
        children: [
          Container(
            width: 48,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(code.text, style: TextStyle(color: readableOn(color), fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name.text.isEmpty ? '(Name)' : name.text)),
        ],
      ),
    );
  }
}
