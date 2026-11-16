import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../auth/auth_controller.dart';
import 'profile_repository.dart';

/// Nastaveni – informace o uctu a odhlaseni (uplne dole).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out',
      message: 'Do you really want to log out?',
      confirmLabel: 'Log out',
    );
    if (!confirmed) return;
    ref.invalidate(profileProvider);
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final profile = ref.watch(profileProvider(userId)).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                const _SectionHeader(title: 'Account'),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _InfoTile(
                        icon: Icons.alternate_email_rounded,
                        title: 'Username',
                        value: profile?.username ?? 'Loading...',
                      ),
                      const Divider(height: 1),
                      _InfoTile(
                        icon: Icons.mail_outline_rounded,
                        title: 'Email',
                        value: email,
                      ),
                      const Divider(height: 1),
                      _InfoTile(
                        icon: Icons.monitor_weight_outlined,
                        title: 'Body weight',
                        value: profile?.bodyWeightKg != null
                            ? '${profile!.bodyWeightKg} kg'
                            : 'Not set',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context, ref),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: AppTheme.danger,
                    backgroundColor:
                        AppTheme.danger.withValues(alpha: 0.07),
                    side: BorderSide(
                      color: AppTheme.danger.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 19),
                  label: const Text(
                    'Log out',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Radek s informaci o uctu.
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 19, color: AppTheme.accentBright),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Nadpis oddilu v nastaveni.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}
