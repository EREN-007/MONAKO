import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/roles.dart';
import '../../l10n/app_localizations.dart';
import '../../services/profile_controller.dart';
import '../../services/speech_service.dart';
import 'editor_toolbar.dart';

class TextBlockResult {
  TextBlockResult(this.text, this.role, this.size, {this.delete = false});
  final String text;
  final InkRole role;
  final double size;
  final bool delete;
}

/// Saisie d'un bloc de texte au clavier ou par dictée vocale.
Future<TextBlockResult?> showTextBlockDialog(
  BuildContext context, {
  required String initialText,
  required InkRole initialRole,
  required double initialSize,
}) =>
    showDialog<TextBlockResult>(
      context: context,
      builder: (_) => _TextDialog(
        initialText: initialText,
        initialRole: initialRole,
        initialSize: initialSize,
      ),
    );

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.initialText,
    required this.initialRole,
    required this.initialSize,
  });

  final String initialText;
  final InkRole initialRole;
  final double initialSize;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initialText);
  late InkRole _role = widget.initialRole;
  late double _size = widget.initialSize;
  String _beforeDictation = '';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggleDictation(SpeechService speech) async {
    final l = AppLocalizations.of(context);
    if (speech.listening) {
      await speech.stopDictation();
      return;
    }
    _beforeDictation = _text.text.isEmpty ? '' : '${_text.text} ';
    final ok = await speech.startDictation(
      languageCode: Localizations.localeOf(context).languageCode,
      onText: (t, _) => setState(() => _text.text = '$_beforeDictation$t'),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.dictationUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final palette = context.watch<ProfileController>().palette;
    final speech = context.watch<SpeechService>();
    final roles = InkRole.writingInks;
    return AlertDialog(
      title: Text(widget.initialText.isEmpty ? l.addText : l.editText),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 3,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: l.textLabel,
                  suffixIcon: IconButton(
                    tooltip: speech.listening ? l.stopDictation : l.dictate,
                    onPressed: () => _toggleDictation(speech),
                    icon: Icon(speech.listening ? Icons.mic_off : Icons.mic_none),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                children: [
                  for (final r in roles)
                    RoleChip(
                      role: r,
                      color: palette[r],
                      paper: palette.paper,
                      selected: r == _role,
                      onTap: () => setState(() => _role = r),
                    ),
                ],
              ),
              Text(l.textSizeValue(_size.round())),
              Slider(
                value: _size,
                min: 10,
                max: 48,
                divisions: 38,
                semanticFormatterCallback: (v) => '${v.round()} pt',
                onChanged: (v) => setState(() => _size = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.initialText.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(
                context, TextBlockResult('', _role, _size, delete: true)),
            child: Text(l.delete),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, TextBlockResult(_text.text, _role, _size)),
          child: Text(l.save),
        ),
      ],
    );
  }
}
