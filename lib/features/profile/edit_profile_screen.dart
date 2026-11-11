import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (profile) {
          _initControllers(profile);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.length < 3 || v.length > 20) {
                      return 'Username must be 3-20 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Body weight (kg)',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _photoUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Profile photo URL',
                    helperText: 'Paste a link to an image',
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _loading ? null : () => _save(profile),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
