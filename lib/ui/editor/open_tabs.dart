import 'package:flutter/foundation.dart';

/// Documents ouverts en onglets (comme plusieurs cours ouverts côte à côte).
class OpenTabs extends ChangeNotifier {
  final List<String> _ids = [];
  final Map<String, String?> _lastPage = {};
  String? _active;

  List<String> get ids => List.unmodifiable(_ids);
  String? get active => _active;

  /// Page affichée en dernier dans un onglet (pour y revenir).
  String? lastPage(String id) => _lastPage[id];
  void rememberPage(String id, String? pageId) => _lastPage[id] = pageId;

  void open(String id, {String? pageId}) {
    if (!_ids.contains(id)) _ids.add(id);
    if (pageId != null) _lastPage[id] = pageId;
    _active = id;
    notifyListeners();
  }

  void activate(String id) {
    if (_active == id || !_ids.contains(id)) return;
    _active = id;
    notifyListeners();
  }

  void close(String id) {
    final i = _ids.indexOf(id);
    if (i < 0) return;
    _ids.removeAt(i);
    _lastPage.remove(id);
    if (_active == id) {
      _active = _ids.isEmpty ? null : _ids[i.clamp(0, _ids.length - 1)];
    }
    notifyListeners();
  }

  /// Retire les onglets de cahiers qui n'existent plus.
  void retain(bool Function(String id) exists) {
    final before = _ids.length;
    _ids.removeWhere((id) => !exists(id));
    if (_active != null && !_ids.contains(_active)) {
      _active = _ids.isEmpty ? null : _ids.last;
    }
    if (_ids.length != before) notifyListeners();
  }
}
