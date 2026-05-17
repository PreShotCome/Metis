import 'package:shared_preferences/shared_preferences.dart';

/// Persistent app settings. Claude API usage is fully optional and off by
/// default — the built-in heuristic parser handles capture on its own.
class SettingsStore {
  static const _kClaudeKey      = 'claude_api_key';
  static const _kClaudeEnabled  = 'claude_enabled';
  static const _kClaudeModel    = 'claude_model';
  static const _kForeground     = 'foreground_enabled';
  static const _kGmailScanned   = 'gmail_last_scan';

  String claudeApiKey  = '';
  bool   claudeEnabled = false;
  String claudeModel   = 'claude-opus-4-7';
  bool   foregroundEnabled = true;
  DateTime? gmailLastScan;

  /// Claude is only consulted when the user has explicitly enabled it AND
  /// supplied a key — and even then only as a rare fallback (see ReminderParser).
  bool get claudeAvailable => claudeEnabled && claudeApiKey.trim().isNotEmpty;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    claudeApiKey      = p.getString(_kClaudeKey) ?? '';
    claudeEnabled     = p.getBool(_kClaudeEnabled) ?? false;
    claudeModel       = p.getString(_kClaudeModel) ?? 'claude-opus-4-7';
    foregroundEnabled = p.getBool(_kForeground) ?? true;
    final scan = p.getInt(_kGmailScanned);
    gmailLastScan = scan == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(scan);
  }

  Future<void> setClaudeApiKey(String v) async {
    claudeApiKey = v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kClaudeKey, claudeApiKey);
  }

  Future<void> setClaudeEnabled(bool v) async {
    claudeEnabled = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kClaudeEnabled, v);
  }

  Future<void> setClaudeModel(String v) async {
    claudeModel = v.trim().isEmpty ? 'claude-opus-4-7' : v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kClaudeModel, claudeModel);
  }

  Future<void> setForegroundEnabled(bool v) async {
    foregroundEnabled = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kForeground, v);
  }

  Future<void> markGmailScanned() async {
    gmailLastScan = DateTime.now();
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kGmailScanned, gmailLastScan!.millisecondsSinceEpoch);
  }
}

final settings = SettingsStore();
