import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../format.dart';
import '../theme.dart';
import '../../features/home/feed_repository.dart';

/// Otevre bottom sheet s komentari workoutu.
Future<void> showCommentSheet(
  BuildContext context, {
  required String workoutId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CommentSheet(workoutId: workoutId),
  );
}

/// Bottom sheet s komentari: seznam + zadavani.
class CommentSheet extends ConsumerStatefulWidget {
  const CommentSheet({super.key, required this.workoutId});

  final String workoutId;

  @override
  ConsumerState<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<CommentSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await addWorkoutComment(widget.workoutId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send comment.')),
      );
      return;
    }
    _controller.clear();
    ref.invalidate(workoutCommentsProvider(widget.workoutId));
    ref.invalidate(workoutEngagementProvider(widget.workoutId));
    ref.invalidate(feedProvider);
    ref.invalidate(userFeedProvider);
  }

  Future<void> _delete(WorkoutComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment'),
        content: const Text('Delete this comment? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(84, 44),
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await deleteWorkoutComment(comment.commentId);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete comment.')),
      );
      return;
    }
    ref.invalidate(workoutCommentsProvider(widget.workoutId));
    ref.invalidate(workoutEngagementProvider(widget.workoutId));
    ref.invalidate(feedProvider);
    ref.invalidate(userFeedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(workoutCommentsProvider(widget.workoutId));
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Text(
                'Comments',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            Expanded(
              child: commentsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ),
                data: (comments) {
                  if (comments.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mode_comment_outlined,
                              size: 30,
                              color: AppTheme.textMuted,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'No comments yet. Be the first!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final isMine = comment.userId == myId;
                      return _CommentTile(
                        comment: comment,
                        isMine: isMine,
                        onDelete: () => _delete(comment),
                      );
                    },
                  );
                },
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: IconButton.filled(
                        onPressed: _sending ? null : _send,
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppTheme.accent.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 19),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isMine,
    required this.onDelete,
  });

  final WorkoutComment comment;
  final bool isMine;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final photo = comment.profilePhotoUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.avatarColor(comment.username),
            backgroundImage: hasPhoto ? NetworkImage(photo) : null,
            child: hasPhoto
                ? null
                : Text(
                    comment.username.isEmpty
                        ? '?'
                        : comment.username[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      timeAgo(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (isMine)
                      InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4, top: 2, bottom: 2),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 15,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    color: Color(0xFFE3EAF6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
