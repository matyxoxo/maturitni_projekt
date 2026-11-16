import 'package:flutter/material.dart';

import '../theme.dart';

/// Karta uzivatele v seznamu lidi (find friends, followers, following).
class UserTile extends StatelessWidget {
  const UserTile({
    super.key,
    required this.username,
    required this.isFollowing,
    required this.onTap,
    required this.onToggleFollow,
    this.fullName,
    this.photoUrl,
  });

  final String username;
  final String? fullName;
  final String? photoUrl;
  final bool isFollowing;
  final VoidCallback onTap;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final radius = BorderRadius.circular(20);
    final subtitle =
        fullName != null && fullName!.isNotEmpty ? fullName! : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 21,
                    backgroundColor: AppTheme.avatarColor(username),
                    backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
                    child: hasPhoto
                        ? null
                        : Text(
                            _initial(username),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _FollowButton(
                  isFollowing: isFollowing,
                  onPressed: onToggleFollow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowing, required this.onPressed});

  final bool isFollowing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 38,
      child: isFollowing
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(104, 38),
                padding: EdgeInsets.zero,
                foregroundColor: AppTheme.textMuted,
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Following'),
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size(104, 38),
                padding: EdgeInsets.zero,
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Follow'),
            ),
    );
  }
}
