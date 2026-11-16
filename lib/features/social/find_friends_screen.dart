import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets/user_tile.dart';
import '../home/feed_repository.dart';
import '../profile/profile_repository.dart';

/// Vyhledavani uzivatelu a follow/unfollow.
class FindFriendsScreen extends ConsumerStatefulWidget {
  const FindFriendsScreen({super.key});

  @override
  ConsumerState<FindFriendsScreen> createState() =>
      _FindFriendsScreenState();
}

class _FindFriendsScreenState extends ConsumerState<FindFriendsScreen> {
  String _query = '';

  Future<void> _toggleFollow(PublicUser user, bool isFollowing) async {
    final ok = await setFollow(user.id, follow: !isFollowing);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update follow.')),
        );
      }
      return;
    }
    ref.invalidate(followCountsProvider);
    ref.invalidate(myFollowingProvider);
    ref.invalidate(feedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(searchUsersProvider(_query));
    final following = ref.watch(myFollowingProvider).value ?? <String>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Find friends')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search by username...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: usersAsync.when(
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
                                color:
                                    AppTheme.accent.withValues(alpha: 0.22),
                              ),
                            ),
                            child: const Icon(
                              Icons.person_search_rounded,
                              size: 34,
                              color: AppTheme.accentBright,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _query.isEmpty
                                ? 'Type a username to search.'
                                : 'No users found.',
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
                    return UserTile(
                      username: user.username,
                      fullName: user.fullName,
                      photoUrl: user.profilePhotoUrl,
                      isFollowing: following.contains(user.id),
                      onTap: () => context.push('/u/${user.id}'),
                      onToggleFollow: () =>
                          _toggleFollow(user, following.contains(user.id)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
