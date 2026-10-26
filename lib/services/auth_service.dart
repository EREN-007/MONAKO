import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local_store.dart';
import '../data/repository.dart';

/// Connexion (courriel + mot de passe, lien magique, Sign in with Apple)
/// via Supabase Auth.
class AuthService extends ChangeNotifier {
  AuthService(this._client, this._store, this._repo) {
    final client = _client;
    if (client != null) {
      _sub = client.auth.onAuthStateChange.listen(
        _onAuth,
        // Lien expiré ou ouvert dans un autre navigateur: on garde l'app
        // utilisable, l'élève peut se connecter avec son mot de passe.
        onError: (Object e) => debugPrint('Retour de connexion: $e'),
      );
      final u = client.auth.currentUser;
      if (u != null) unawaited(_onSignedIn(u));
    }
  }

  final SupabaseClient? _client;
  final LocalStore _store;
  final NotesRepository _repo;
  StreamSubscription<AuthState>? _sub;

  static const redirectUrl = 'com.monako.app://login-callback';

  /// Faux si l'app est construite sans SUPABASE_URL / SUPABASE_ANON_KEY:
  /// elle fonctionne alors en mode local seulement.
  bool get configured => _client != null;
  User? get user => _client?.auth.currentUser;
  bool get signedIn => user != null;

  /// Adresse de retour des liens envoyés par courriel. Sur le web: la page
  /// où l'app est publiée (ex. https://compte.github.io/MONAKO/), pour ne
  /// pas dépendre de la « Site URL » de Supabase.
  String get _redirect => kIsWeb ? webRedirectUrl(Uri.base) : redirectUrl;

  @visibleForTesting
  static String webRedirectUrl(Uri page) => '${page.origin}${page.path}';

  Future<void> _onAuth(AuthState s) async {
    switch (s.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.initialSession:
        final u = s.session?.user;
        if (u != null) await _onSignedIn(u);
      case AuthChangeEvent.signedOut:
        // Session expirée avec des changements non envoyés: on les garde
        // pour les envoyer à la prochaine connexion du même compte.
        if (_store.pendingCount == 0) await _wipeLocal();
      default:
        break;
    }
    notifyListeners();
  }

  /// Les notes créées sans compte sont adoptées par le premier compte
  /// connecté. Les données locales d'un autre compte sont effacées.
  Future<void> _onSignedIn(User u) async {
    final owner = _store.meta<String>('owner');
    if (owner != null && owner != u.id) {
      await _store.clearAll();
      await _repo.sync.resetCursors();
      _repo.reloadAll();
    }
    await _store.setMeta('owner', u.id);
    await _repo.sync.sync();
    notifyListeners();
  }

  Future<void> _wipeLocal() async {
    await _store.clearAll();
    _repo.reloadAll();
  }

  Future<void> signInWithPassword(String email, String password) =>
      _client!.auth.signInWithPassword(email: email.trim(), password: password);

  /// Retourne vrai si une confirmation par courriel est nécessaire.
  Future<bool> signUp(String email, String password) async {
    final r = await _client!.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _redirect,
    );
    return r.session == null;
  }

  Future<void> sendMagicLink(String email) => _client!.auth
      .signInWithOtp(email: email.trim(), emailRedirectTo: _redirect);

  Future<void> signInWithApple() => _client!.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: _redirect,
      );

  Future<void> resetPassword(String email) => _client!.auth
      .resetPasswordForEmail(email.trim(), redirectTo: _redirect);

  /// Déconnexion: les données locales sont effacées de l'appareil (données
  /// sensibles). Elles restent dans le compte.
  Future<void> signOut() async {
    await _repo.sync.sync();
    await _client!.auth.signOut();
    await _wipeLocal();
    notifyListeners();
  }

  /// Suppression de compte: notes, profils et fichiers effacés.
  Future<void> deleteAccount() async {
    await _repo.sync.deleteAccount();
    try {
      await _client!.auth.signOut();
    } catch (_) {
      // la session n'existe déjà plus
    }
    await _wipeLocal();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
