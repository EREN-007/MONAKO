import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/profile_controller.dart';
import '../widgets/monako_logo.dart';

/// Connexion: courriel + mot de passe, lien magique, Sign in with Apple.
/// Le compte sert à la synchronisation entre appareils; l'app fonctionne
/// aussi sans compte (sauvegarde locale).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.fromOnboarding = false});

  final bool fromOnboarding;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final msg = await action();
      if (!mounted) return;
      if (msg == null) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        setState(() {
          _message = msg;
          _error = false;
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _message = e.message;
        _error = true;
      });
    } catch (e) {
      setState(() {
        _message = '$e';
        _error = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = context.read<AuthService>();
    final pc = context.watch<ProfileController>();
    final isApple = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.account),
        automaticallyImplyLeading: !widget.fromOnboarding,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(child: MonakoLogo(profile: pc.profile, size: 96)),
                  const SizedBox(height: 12),
                  Text(l.accountWhy, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  if (isApple) ...[
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                await auth.signInWithApple();
                                return null;
                              }),
                      icon: const Icon(Icons.apple),
                      label: Text(l.signInWithApple),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(l.or),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: l.email,
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: [
                      _signUp ? AutofillHints.newPassword : AutofillHints.password
                    ],
                    decoration: InputDecoration(
                      labelText: l.password,
                      helperText: _signUp ? l.passwordHelp : null,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              if (_signUp) {
                                final needsConfirm = await auth.signUp(
                                    _email.text, _password.text);
                                return needsConfirm ? l.checkEmailConfirm : null;
                              }
                              await auth.signInWithPassword(
                                  _email.text, _password.text);
                              return null;
                            }),
                    child: Text(_signUp ? l.createAccount : l.signIn),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _signUp = !_signUp),
                    child: Text(_signUp ? l.haveAccount : l.noAccount),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || !_email.text.contains('@')
                        ? null
                        : () => _run(() async {
                              await auth.sendMagicLink(_email.text);
                              return l.magicLinkSent;
                            }),
                    icon: const Icon(Icons.link),
                    label: Text(l.sendMagicLink),
                  ),
                  TextButton(
                    onPressed: _busy || !_email.text.contains('@')
                        ? null
                        : () => _run(() async {
                              await auth.resetPassword(_email.text);
                              return l.resetSent;
                            }),
                    child: Text(l.forgotPassword),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Row(children: [
                        Icon(_error ? Icons.error_outline : Icons.info_outline,
                            color: _error
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_message!)),
                      ]),
                    ),
                  ],
                  if (widget.fromOnboarding) ...[
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.continueWithoutAccount),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
