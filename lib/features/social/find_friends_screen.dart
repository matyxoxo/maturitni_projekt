import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search by username...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (users) {
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Type a username to search.'
                          : 'No users found.',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isFollowing = following.contains(user.id);
                    return _UserTile(
                      user: user,
                      isFollowing: isFollowing,
                      onToggle: () => _toggleFollow(user, isFollowing),
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

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isFollowing,
    required this.onToggle,
  });

  final PublicUser user;
  final bool isFollowing;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _avatarColor(user.username),
        backgroundImage: user.profilePhotoUrl != null &&
                user.profilePhotoUrl!.isNotEmpty
            ? NetworkImage(user.profilePhotoUrl!)
            : null,
        child: user.profilePhotoUrl == null || user.profilePhotoUrl!.isEmpty
            ? Text(
                user.username.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      title: Text(user.username),
      subtitle: user.fullName != null && user.fullName!.isNotEmpty
          ? Text(user.fullName!)
          : null,
      trailing: FilledButton.tonal(
        onPressed: onToggle,
        style: isFollowing
            ? FilledButton.styleFrom(
                backgroundColor: Colors.grey.shade700,
                foregroundColor: Colors.white,
              )
            : null,
        child: Text(isFollowing ? 'Following' : 'Follow'),
      ),
    );
  }

  static Color _avatarColor(String name) {
    const colors = <Color>[
      Colors.teal,
      Colors.indigo,
      Colors.deepOrange,
      Colors.pink,
      Colors.blueGrey,
      Colors.green,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}
