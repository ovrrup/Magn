import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';

/// Abstract contract for session persistence.
abstract class SessionRepository {
  Future<List<SessionModel>> getSessions();
  Future<void> saveSession(SessionModel session);
  Future<void> deleteSession(String id);
  Future<void> clearAll();
}

/// SharedPreferences-backed repository with robust in-memory fallback.
class LocalSessionRepository implements SessionRepository {
  static const String _storageKey = 'magn_sessions_v1';
  final List<SessionModel> _inMemoryCache = [];
  bool _isInitialized = false;

  Future<SharedPreferences?> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<SessionModel>> getSessions() async {
    if (!_isInitialized) {
      final prefs = await _getPrefs();
      if (prefs != null) {
        final rawJson = prefs.getStringList(_storageKey);
        if (rawJson != null) {
          _inMemoryCache.clear();
          for (final item in rawJson) {
            try {
              final map = jsonDecode(item) as Map<String, dynamic>;
              _inMemoryCache.add(SessionModel.fromMap(map));
            } catch (_) {
              // Ignore corrupted records
            }
          }
        }
      }
      _isInitialized = true;
    }
    return List.unmodifiable(_inMemoryCache);
  }

  @override
  Future<void> saveSession(SessionModel session) async {
    await getSessions();
    _inMemoryCache.add(session);
    await _persist();
  }

  @override
  Future<void> deleteSession(String id) async {
    await getSessions();
    _inMemoryCache.removeWhere((item) => item.id == id);
    await _persist();
  }

  @override
  Future<void> clearAll() async {
    _inMemoryCache.clear();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await _getPrefs();
    if (prefs != null) {
      final serialized = _inMemoryCache.map((s) => s.toJson()).toList();
      await prefs.setStringList(_storageKey, serialized);
    }
  }
}
