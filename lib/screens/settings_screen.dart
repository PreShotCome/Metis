import 'package:flutter/material.dart';
import '../services/foreground_service.dart';
import '../services/gmail_service.dart';
import '../services/settings_store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _modelCtrl;
  bool _foreground = settings.foregroundEnabled;
  bool _claudeEnabled = settings.claudeEnabled;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: settings.claudeApiKey);
    _modelCtrl = TextEditingController(text: settings.claudeModel);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleForeground(bool v) async {
    setState(() => _foreground = v);
    await settings.setForegroundEnabled(v);
    if (v) {
      await ForegroundService.start();
    } else {
      await ForegroundService.stop();
    }
  }

  Future<void> _saveClaude() async {
    await settings.setClaudeApiKey(_keyCtrl.text);
    await settings.setClaudeModel(_modelCtrl.text);
    await settings.setClaudeEnabled(_claudeEnabled);
    if (mounted) {
      _modelCtrl.text = settings.claudeModel;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI parsing settings saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SectionLabel('Capture'),
          MCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: MC.cyan,
              value: _foreground,
              onChanged: _toggleForeground,
              title: const Text('Always-on capture',
                  style: TextStyle(color: MC.text, fontSize: 14)),
              subtitle: const Text(
                'Keep a persistent service running so Metis is always '
                'ready, and auto-start it on boot.',
                style: TextStyle(color: MC.muted, fontSize: 11),
              ),
            ),
          ),

          SectionLabel('AI parsing — optional'),
          MCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Metis parses your captures on-device by default — no '
                  'account or network needed. You can optionally let Claude '
                  'handle the occasional phrase the built-in parser cannot '
                  'resolve. It is only ever called as a rare fallback.',
                  style: TextStyle(color: MC.muted, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: MC.cyan,
                  value: _claudeEnabled,
                  onChanged: (v) => setState(() => _claudeEnabled = v),
                  title: const Text('Use Claude as a fallback',
                      style: TextStyle(color: MC.text, fontSize: 14)),
                ),
                if (_claudeEnabled) ...[
                  const SizedBox(height: 6),
                  _label('ANTHROPIC API KEY'),
                  TextField(
                    controller: _keyCtrl,
                    obscureText: _obscureKey,
                    style: const TextStyle(color: MC.text, fontSize: 13),
                    decoration: _input('sk-ant-...').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureKey
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: MC.muted,
                            size: 18),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _label('MODEL'),
                  TextField(
                    controller: _modelCtrl,
                    style: const TextStyle(color: MC.text, fontSize: 13),
                    decoration: _input('claude-opus-4-7'),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MC.cyan,
                      side: const BorderSide(color: MC.cyanDim),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _saveClaude,
                    child: const Text('SAVE AI SETTINGS',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          SectionLabel('Email'),
          MCard(
            child: Row(
              children: [
                Icon(
                    GmailService.isSignedIn
                        ? Icons.mark_email_read
                        : Icons.mail_outline,
                    color: GmailService.isSignedIn ? MC.green : MC.muted,
                    size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    GmailService.isSignedIn
                        ? 'Gmail connected — scan from the Email tab.'
                        : 'Gmail not connected. Connect it in the Email tab.',
                    style: const TextStyle(color: MC.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          SectionLabel('About'),
          MCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('METIS',
                    style: TextStyle(
                        color: MC.cyan,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3)),
                const SizedBox(height: 4),
                const Text('Always listening. Never forgetting.',
                    style: TextStyle(color: MC.text, fontSize: 12)),
                const SizedBox(height: 10),
                const Divider(color: MC.border, height: 1),
                const SizedBox(height: 10),
                const Text(
                  'A personal reminder companion. Reminders live on this '
                  'device only — no login, no cloud account.',
                  style:
                      TextStyle(color: MC.muted, fontSize: 11, height: 1.5),
                ),
                const SizedBox(height: 6),
                const Text('v0.1.0',
                    style: TextStyle(color: MC.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: MC.muted,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold)),
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: MC.muted, fontSize: 12),
        filled: true,
        fillColor: MC.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: MC.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: MC.cyan)),
      );
}
