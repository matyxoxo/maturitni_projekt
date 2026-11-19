import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../rank/rank_model.dart';
import '../rank/rank_widgets.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  final _controller = TextEditingController();
  RankSex? _sex;
  bool _loading = false;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Při návratu na obrazovku (např. doplnění pohlaví u staršího účtu)
  /// předvyplní, co už v profilu je.
  Future<void> _loadExisting() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingProfile = false);
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('body_weight_kg, sex')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      final weight = (row?['body_weight_kg'] as num?)?.toDouble();
      final sex = row?['sex'] as String?;
      setState(() {
        if (weight != null) {
          _controller.text = weight % 1 == 0
              ? weight.toInt().toString()
              : weight.toString();
        }
        _sex = sex == 'male'
            ? RankSex.male
            : sex == 'female'
                ? RankSex.female
                : null;
        _loadingProfile = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _save() async {
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid number.')),
      );
      return;
    }
    if (_sex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select your standards.')),
      );
      return;
    }
    setState(() => _loading = true);
    final error = await ref
        .read(authControllerProvider.notifier)
        .saveOnboarding(weightKg: parsed, sex: _sex!);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.monitor_weight_outlined,
                    size: 26,
                    color: AppTheme.accentBright,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your body weight',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We compare your lifts with lifters of the same bodyweight. '
                  'Standards differ for men and women, so pick the table that '
                  'applies to you.',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    suffixText: 'kg',
                  ),
                ),
                const SizedBox(height: 18),
                RankSexSelector(
                  value: _sex,
                  onChanged: (sex) => setState(() => _sex = sex),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Strength Level publishes separate men\'s and women\'s '
                  'by-bodyweight tables. This picks the right one.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
