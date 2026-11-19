import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../rank/rank_model.dart';
import '../rank/rank_repository.dart';
import '../rank/rank_widgets.dart';
import 'profile_repository.dart';

/// Uprava udaju profilu (jmeno, vaha, cele jmeno, fotka URL).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _weightController;
  late final TextEditingController _photoUrlController;
  RankSex? _sex;
  bool _loading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _fullNameController = TextEditingController();
    _weightController = TextEditingController();
    _photoUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _weightController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  void _initControllers(ProfileData profile) {
    if (_initialized) return;
    _initialized = true;
    _usernameController.text = profile.username;
    _fullNameController.text = profile.fullName ?? '';
    _weightController.text =
        profile.bodyWeightKg != null ? '${profile.bodyWeightKg}' : '';
    _photoUrlController.text = profile.profilePhotoUrl ?? '';
    _sex = profile.sex;
  }

  Future<void> _save(ProfileData profile) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final username = _usernameController.text.trim();
    final fullName = _fullNameController.text.trim();
    final photoUrl = _photoUrlController.text.trim();
    final weightText = _weightController.text.trim().replaceAll(',', '.');

    double? weight;
    if (weightText.isNotEmpty) {
      weight = double.tryParse(weightText);
      if (weight == null || weight < 30 || weight > 300) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weight must be 30-300 kg.')),
        );
        return;
      }
    }

    final error = await updateProfile(
      username: username != profile.username ? username : null,
      bodyWeightKg: weight != profile.bodyWeightKg ? weight : null,
      sex: _sex != profile.sex ? _sex : null,
      fullName: fullName != (profile.fullName ?? '') ? fullName : null,
      profilePhotoUrl: photoUrl != (profile.profilePhotoUrl ?? '')
          ? photoUrl
          : null,
    );

    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ref.invalidate(profileProvider);
    ref.invalidate(rankReportProvider);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final profileAsync = ref.watch(profileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ),
        data: (profile) {
          _initControllers(profile);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: AnimatedBuilder(
                      animation: Listenable.merge(
                        [_photoUrlController, _usernameController],
                      ),
                      builder: (context, _) => Row(
                        children: [
                          _AvatarPreview(
                            photoUrl: _photoUrlController.text.trim(),
                            username: _usernameController.text.trim(),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _usernameController.text.trim().isEmpty
                                      ? 'Your profile'
                                      : _usernameController.text.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'This is how other lifters see you.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.length < 3 || v.length > 20) {
                      return 'Username must be 3-20 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Body weight (kg)',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'STANDARDS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                RankSexSelector(
                  value: _sex,
                  onChanged: (sex) => setState(() => _sex = sex),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Picks the men\'s or women\'s Strength Level table used for '
                  'your ranks.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _photoUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Profile photo URL',
                    helperText: 'Paste a link to an image',
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _loading ? null : () => _save(profile),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Nahled profilovky podle zadaneho URL / uzivatelskeho jmena.
class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.photoUrl, required this.username});

  final String photoUrl;
  final String username;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;
    final initial = username.isEmpty ? '?' : username[0].toUpperCase();
    final safe = username.isEmpty ? '?' : username;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.accentGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.28),
            blurRadius: 16,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 27,
        backgroundColor: AppTheme.avatarColor(safe),
        backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
        onBackgroundImageError: hasPhoto ? (_, _) {} : null,
        child: hasPhoto
            ? null
            : Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}
