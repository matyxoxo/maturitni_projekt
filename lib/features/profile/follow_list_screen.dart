import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/user_tile.dart';
import '../home/feed_repository.dart';
import 'profile_repository.dart';

/// Seznam followers nebo following uzivatele s moznosti follow/unfollow.
class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({super.key, required this.userId, required this.type});

  final String userId;

  /// 'followers' nebo 'following'
  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowers = type == 'followers';
    final listAsync = isFollowers
        ? ref.watch(followersListProvider(userId))
        : ref.watch(followingListProvider(userId));
    final myFollowing = ref.watch(myFollowingProvider).value ?? <String>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(isFollowers ? 'Followers' : 'Following'),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent.withValues(alpha: 0.10),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        isFollowers
                            ? Icons.group_outlined
                            : Icons.person_add_alt_1_outlined,
                        size: 32,
                        color: AppTheme.accentBright,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isFollowers
                          ? 'No followers yet.'
                          : 'Not following anyone.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isFollowing = myFollowing.contains(user.id);
              return UserTile(
                username: user.username,
                fullName: user.fullName,
                photoUrl: user.profilePhotoUrl,
                isFollowing: isFollowing,
                onTap: () => context.push('/u/${user.id}'),
                onToggleFollow: () =>
                    _toggleFollow(context, ref, user, isFollowing),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    PublicUser user,
    bool isFollowing,
  ) async {
    final ok = await setFollow(user.id, follow: !isFollowing);
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update follow.')),
        );
      }
      return;
    }
    ref.invalidate(myFollowingProvider);
    ref.invalidate(followCountsProvider);
    ref.invalidate(followersListProvider);
    ref.invalidate(followingListProvider);
    ref.invalidate(feedProvider);
  }
}
