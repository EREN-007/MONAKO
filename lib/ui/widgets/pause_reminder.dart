import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../l10n/app_localizations.dart';

/// Mode pause visuelle (version 3): rappel 20-20-20 toutes les 20 minutes
/// (regarder à 6 m pendant 20 s). Bandeau calme, sans clignotement.
class PauseReminder extends StatefulWidget {
  const PauseReminder({super.key, required this.child});
  final Widget child;

  @override
  State<PauseReminder> createState() => _PauseReminderState();
}

class _PauseReminderState extends State<PauseReminder> {
  static const interval = Duration(minutes: 20);
  Timer? _timer;
  bool _visible = false;
  bool _enabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = context.watch<NotesRepository>().settings.pauseReminder;
    if (enabled != _enabled) {
      _enabled = enabled;
      _timer?.cancel();
      _timer = enabled
          ? Timer.periodic(interval, (_) => setState(() => _visible = true))
          : null;
      if (!enabled) _visible = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        widget.child,
        if (_visible)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            AppLocalizations.of(context).pauseReminderText,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _visible = false),
                        child: Text(AppLocalizations.of(context).ok),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
