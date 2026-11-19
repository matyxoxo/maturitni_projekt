import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/feed_repository.dart';
import '../home/home_repository.dart';
import '../profile/profile_repository.dart';
import '../rank/rank_model.dart';
import '../rank/rank_repository.dart';
import '../routines/routines_repository.dart';
import '../workout/active_workout_provider.dart';

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
  static bool _googleInitialized = false;

  /// Posledni znamy uzivatel – pri zmene (odhlaseni / jiny ucet)
  /// se smazi vsechna data (feed, profil, follows, workouty...).
  String? _activeUserId;

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
    final userId = session?.user.id;

    // Zmena uctu (vcetne odhlaseni) – vyprazdneni cache stareho uzivatele.
    // Odlozeno mikrotaskem, aby se providery nemenily behem buildu.
    if (userId != _activeUserId) {
      _activeUserId = userId;
      scheduleMicrotask(_invalidateUserData);
    }

    if (session == null) {
      state = AppAuthStatus.signedOut;
      _changes.add(null);
      return;
    }
    try {
      final row = await _client
          .from('users')
          .select('username, body_weight_kg, sex')
          .eq('id', session.user.id)
          .maybeSingle();
      if (row == null) {
        state = AppAuthStatus.needsUsername;
      } else if (row['body_weight_kg'] == null || row['sex'] == null) {
        state = AppAuthStatus.needsWeight;
      } else {
        state = AppAuthStatus.ready;
      }
    } catch (_) {
      state = AppAuthStatus.needsUsername;
    }
    _changes.add(null);
  }

  /// Smaze vsechna data predchoziho uzivatele (volano pri zmene uctu).
  void _invalidateUserData() {
    ref.invalidate(feedProvider);
    ref.invalidate(userFeedProvider);
    ref.invalidate(likeOverridesProvider);
    ref.invalidate(workoutCommentsProvider);
    ref.invalidate(workoutEngagementProvider);
    ref.invalidate(myWorkoutsProvider);
    ref.invalidate(workoutDetailProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(workoutHistoryProvider);
    ref.invalidate(followCountsProvider);
    ref.invalidate(followersListProvider);
    ref.invalidate(followingListProvider);
    ref.invalidate(myFollowingProvider);
    ref.invalidate(searchUsersProvider);
    ref.invalidate(routinesProvider);
    ref.invalidate(routineDetailProvider);
    ref.invalidate(previousWorkoutSetsProvider);
    ref.invalidate(rankReportProvider);
    // Aktivni workout patri predchozimu uctu.
    ref.read(activeWorkoutProvider.notifier).reset();
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

  Future<String?> signInWithGoogle() async {
    try {
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      if (webClientId == null || webClientId.isEmpty) {
        return 'Google sign-in is not configured.';
      }

      final googleSignIn = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await googleSignIn.initialize(serverClientId: webClientId);
        _googleInitialized = true;
      }

      final googleUser = await googleSignIn.authenticate();
      const scopes = ['email', 'profile'];
      final authorization = await googleUser.authorizationClient
              .authorizationForScopes(scopes) ??
          await googleUser.authorizationClient.authorizeScopes(scopes);

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        return 'Could not get Google credentials. Please try again.';
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );
      await refresh();
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      return 'Google sign-in failed. Please try again.';
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Google sign-in failed. Please try again.';
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

  /// Uloží váhu těla a pohlaví během onboardingu.
  ///
  /// Obojí ovlivňuje rank (tabulky Strength Levelu jsou zvlášť pro muže
  /// a ženy), takže se ukládá jedním dotazem a rank se hned přepočítá.
  Future<String?> saveOnboarding({
    required double weightKg,
    required RankSex sex,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) return 'Not signed in.';
    if (weightKg < 30 || weightKg > 300) {
      return 'Weight must be between 30 and 300 kg.';
    }
    try {
      await _client.from('users').update({
        'body_weight_kg': weightKg,
        'sex': sex.databaseValue,
      }).eq('id', session.user.id);
      await refresh();
      ref.invalidate(rankReportProvider);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save your details. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    // Odhlasit i Google – pri dalsim "Continue with Google" se
    // zobrazi vyber uctu misto ticheho prihlaseni toho stareho.
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Google odhlaseni muze selhat – nevadi, Supabase je odhlaseny.
      }
    }
    await refresh();
  }
}
