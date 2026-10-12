import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppAuthStatus {
  loading,
  signedOut,
  needsUsername,
  needsWeight,
  ready,
}

final authControllerProvider =
    NotifierProvider<AuthController, AppAuthStatus>(AuthController.new);

class AuthController extends Notifier<AppAuthStatus> {
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  AppAuthStatus build() {
    final sub = _client.auth.onAuthStateChange.listen((_) {
      unawaited(refresh());
    });
    ref.onDispose(() {
      sub.cancel();
      _changes.close();
    });
    unawaited(refresh());
    return AppAuthStatus.loading;
  }

  Future<void> refresh() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      state = AppAuthStatus.signedOut;
      _changes.add(null);
      return;
    }
    try {
      final row = await _client
          .from('users')
          .select('username, body_weight_kg')
          .eq('id', session.user.id)
          .maybeSingle();
      if (row == null) {
        state = AppAuthStatus.needsUsername;
      } else if (row['body_weight_kg'] == null) {
        state = AppAuthStatus.needsWeight;
      } else {
        state = AppAuthStatus.ready;
      }
    } catch (_) {
      state = AppAuthStatus.needsUsername;
    }
    _changes.add(null);
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await refresh();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Unexpected error. Please try again.';
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      final res =
          await _client.auth.signUp(email: email, password: password);
      if (res.session == null) {
        return '__confirmation__';
      }
      await refresh();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Unexpected error. Please try again.';
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Unexpected error. Please try again.';
    }
  }

  Future<String?> saveUsername(String username) async {
    final session = _client.auth.currentSession;
    if (session == null) return 'Not signed in.';
    final trimmed = username.trim();
    if (trimmed.length < 3 || trimmed.length > 20) {
      return 'Username must be 3-20 characters long.';
    }
    try {
      await _client.from('users').insert({
        'id': session.user.id,
        'email': session.user.email ?? '',
        'username': trimmed,
      });
      await refresh();
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'This username is already taken.';
      return e.message;
    } catch (_) {
      return 'Could not save username. Please try again.';
    }
  }

  Future<String?> saveBodyWeight(double weightKg) async {
    final session = _client.auth.currentSession;
    if (session == null) return 'Not signed in.';
    if (weightKg < 30 || weightKg > 300) {
      return 'Weight must be between 30 and 300 kg.';
    }
    try {
      await _client
          .from('users')
          .update({'body_weight_kg': weightKg})
          .eq('id', session.user.id);
      await refresh();
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save weight. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    await refresh();
  }
}
