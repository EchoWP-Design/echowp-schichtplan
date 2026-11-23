import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repo.dart';

/// Erster Start: neue Familie anlegen oder mit Einladungscode beitreten.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.repo, required this.suggestedName});

  final Repo repo;
  final String suggestedName;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.suggestedName);
  final _familyName = TextEditingController();
  final _code = TextEditingController();
  bool _join = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _familyName.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Bitte deinen Namen eingeben.');
      return;
    }
    if (_join && _code.text.trim().isEmpty) {
      setState(() => _error = 'Bitte den Einladungscode eingeben.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_join) {
        await widget.repo.joinFamily(code: _code.text, memberName: name);
      } else {
        final fam = _familyName.text.trim().isEmpty ? 'Familie' : _familyName.text.trim();
        await widget.repo.createFamily(familyName: fam, memberName: name);
      }
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Das hat nicht geklappt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Willkommen'),
        actions: [
          IconButton(
            tooltip: 'Abmelden',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Neue Familie'), icon: Icon(Icons.group_add)),
              ButtonSegment(value: true, label: Text('Beitreten'), icon: Icon(Icons.key)),
            ],
            selected: {_join},
            onSelectionChanged: (s) => setState(() {
              _join = s.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 24),
          Text(
            _join
                ? 'Gib den Code ein, den du von deiner Familie bekommen hast. Du findest ihn in der App unter „Familie“.'
                : 'Leg eure Familie an. Danach bekommst du einen Code, mit dem die anderen beitreten.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Dein Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          if (_join)
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Einladungscode', border: OutlineInputBorder()),
            )
          else
            TextField(
              controller: _familyName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name der Familie (z. B. Familie Muster)',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Bitte warten …' : (_join ? 'Beitreten' : 'Familie anlegen')),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
