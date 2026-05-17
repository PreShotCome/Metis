import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/gmail_service.dart';
import '../services/parser.dart';
import '../services/settings_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/reminder_editor.dart';

class _Candidate {
  final EmailMessage email;
  final ParsedReminder reminder;
  _Candidate(this.email, this.reminder);
}

class EmailScreen extends StatefulWidget {
  const EmailScreen({super.key});

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  bool _connected = false;
  bool _busy = false;
  String? _error;
  final List<_Candidate> _candidates = [];
  int _scanned = 0;

  @override
  void initState() {
    super.initState();
    _trySilent();
  }

  Future<void> _trySilent() async {
    final ok = await GmailService.signInSilently();
    if (mounted) setState(() => _connected = ok);
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await GmailService.signIn();
    if (!mounted) return;
    setState(() {
      _connected = ok;
      _busy = false;
      if (!ok) _error = 'Gmail connection was cancelled or failed.';
    });
  }

  Future<void> _disconnect() async {
    await GmailService.signOut();
    if (mounted) {
      setState(() {
        _connected = false;
        _candidates.clear();
        _scanned = 0;
      });
    }
  }

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _error = null;
      _candidates.clear();
    });
    try {
      final messages = await GmailService.recentMessages();
      final found = <_Candidate>[];
      for (final m in messages) {
        final parsed = await ReminderParser.parseBlock(m.scanText);
        for (final p in parsed) {
          if (p.resolved) found.add(_Candidate(m, p));
        }
      }
      await settings.markGmailScanned();
      if (!mounted) return;
      setState(() {
        _candidates
          ..clear()
          ..addAll(found);
        _scanned = messages.length;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not scan inbox. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EMAIL')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (!_connected) _connectCard() else _accountCard(),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(color: MC.red, fontSize: 12)),
          ],
          if (_connected) ...[
            SectionLabel(
              'Detected items',
              trailing: _scanned > 0
                  ? Text('scanned $_scanned emails',
                      style:
                          const TextStyle(color: MC.muted, fontSize: 10))
                  : null,
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: CircularProgressIndicator(color: MC.cyan)),
              )
            else if (_candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: EmptyState(
                  icon: Icons.mark_email_read_outlined,
                  title: 'Nothing detected',
                  subtitle:
                      'Scan your inbox to surface deadlines and action items from recent emails.',
                ),
              )
            else
              for (final c in _candidates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _candidateCard(c),
                ),
          ],
        ],
      ),
    );
  }

  Widget _connectCard() {
    return MCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CONNECT GMAIL',
              style: TextStyle(
                  color: MC.cyan,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          const Text(
            'Metis scans recent emails (read-only) to spot deadlines, '
            'appointments, and action items you might otherwise miss.',
            style: TextStyle(color: MC.muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: MC.cyan,
                foregroundColor: MC.bg,
              ),
              onPressed: _busy ? null : _connect,
              icon: const Icon(Icons.link, size: 18),
              label: Text(_busy ? 'CONNECTING…' : 'CONNECT GMAIL',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard() {
    final email = GmailService.account?.email ?? 'Connected';
    return MCard(
      accent: MC.green,
      child: Row(
        children: [
          const Icon(Icons.mark_email_read, color: MC.green, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: MC.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const Text('Gmail connected · read-only',
                    style: TextStyle(color: MC.muted, fontSize: 10)),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _scan,
            child: Text(_busy ? '…' : 'SCAN',
                style: const TextStyle(
                    color: MC.cyan, fontWeight: FontWeight.bold)),
          ),
          GestureDetector(
            onTap: _disconnect,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.logout, color: MC.muted, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _candidateCard(_Candidate c) {
    final r = c.reminder;
    return MCard(
      accent: MC.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: MC.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              if (r.dueAt != null)
                Text(formatDue(r.dueAt!, hasTime: r.hasTime),
                    style: const TextStyle(color: MC.amber, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Text('from ${c.email.sender}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: MC.muted, fontSize: 11)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: MC.cyan),
              onPressed: () async {
                final saved = await showReminderEditor(
                  context,
                  draft: r,
                  source: ReminderSource.email,
                );
                if (saved != null && mounted) {
                  setState(() => _candidates.remove(c));
                }
              },
              icon: const Icon(Icons.add_alarm, size: 16),
              label: const Text('ADD REMINDER',
                  style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
