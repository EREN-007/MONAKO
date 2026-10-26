import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';

/// Partage d'un cahier avec un camarade ou un enseignant (version 3).
/// Chacun voit la note dans ses propres couleurs: seuls les rôles sont
/// partagés, jamais le profil visuel (donnée sensible).
Future<void> showShareDialog(BuildContext context, Notebook notebook) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ShareDialog(notebook: notebook),
    );

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.notebook});
  final Notebook notebook;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _email = TextEditingController();
  String _perm = 'read';
  List<Map<String, dynamic>> _shares = [];
  bool _busy = false;
  String? _error;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _client
          .rpc<List<dynamic>>('list_notebook_shares', params: {'nb': widget.notebook.id});
      setState(() => _shares = rows.cast<Map<String, dynamic>>());
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _share() async {
    final l = AppLocalizations.of(context);
    if (!_email.text.contains('@')) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _client.rpc<dynamic>('share_notebook', params: {
        'nb': widget.notebook.id,
        'email': _email.text.trim(),
        'perm': _perm,
      });
      _email.clear();
      await _load();
    } on PostgrestException catch (e) {
      setState(() => _error =
          e.message.contains('user_not_found') ? l.shareUserNotFound : e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unshare(String userId) async {
    await _client.rpc<dynamic>('unshare_notebook',
        params: {'nb': widget.notebook.id, 'target': userId});
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.shareNotebook),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.shareExplanation),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: l.email),
                onSubmitted: (_) => _share(),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'read', label: Text(l.permissionRead), icon: const Icon(Icons.visibility_outlined)),
                  ButtonSegment(value: 'edit', label: Text(l.permissionEdit), icon: const Icon(Icons.edit_outlined)),
                ],
                selected: {_perm},
                onSelectionChanged: (s) => setState(() => _perm = s.first),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.send_outlined),
                label: Text(l.share),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!)),
                ]),
              ],
              const Divider(height: 24),
              for (final s in _shares)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(s['permission'] == 'edit'
                      ? Icons.edit_outlined
                      : Icons.visibility_outlined),
                  title: Text('${s['email']}'),
                  subtitle: Text(s['permission'] == 'edit' ? l.permissionEdit : l.permissionRead),
                  trailing: IconButton(
                    tooltip: l.removeAccess,
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: () => _unshare('${s['user_id']}'),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
      ],
    );
  }
}
