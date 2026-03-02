import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/database_provider.dart';

class SetupWorkoutScreen extends ConsumerStatefulWidget {
  const SetupWorkoutScreen({super.key});

  @override
  ConsumerState<SetupWorkoutScreen> createState() =>
      _SetupWorkoutScreenState();
}

class _SetupWorkoutScreenState extends ConsumerState<SetupWorkoutScreen> {
  bool _isSeeding = false;

  Future<void> _useDefaults() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isSeeding = true);
    try {
      final repo = ref.read(workoutRepositoryProvider);
      await repo.seedDefaultWorkouts(userId);
      if (mounted) context.go('/today');
    } catch (e) {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  Future<void> _startCustom() async {
    // Seed defaults, then redirect to settings to edit
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isSeeding = true);
    try {
      final repo = ref.read(workoutRepositoryProvider);
      await repo.seedDefaultWorkouts(userId);
      if (mounted) context.go('/settings/workout-days');
    } catch (e) {
      if (mounted) {
        setState(() => _isSeeding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              Text(
                'Set up your\nworkout split',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? CupertinoColors.white
                      : CupertinoColors.black,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Start with a Push/Pull/Legs template,\nor customize your own.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.systemGrey,
                  height: 1.4,
                ),
              ),

              const Spacer(flex: 2),

              // PPL template preview
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? CupertinoColors.systemGrey6.darkColor
                      : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _DayPreview(label: 'Mon', value: 'Push'),
                    _DayPreview(label: 'Tue', value: 'Pull'),
                    _DayPreview(label: 'Wed', value: 'Legs'),
                    _DayPreview(label: 'Thu', value: 'Push'),
                    _DayPreview(label: 'Fri', value: 'Pull'),
                    _DayPreview(label: 'Sat', value: 'Legs'),
                    _DayPreview(label: 'Sun', value: 'Rest', isRest: true),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Use defaults button
              GestureDetector(
                onTap: _isSeeding ? null : _useDefaults,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark
                        ? CupertinoColors.white
                        : CupertinoColors.black,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _isSeeding
                        ? CupertinoActivityIndicator(
                            color: isDark
                                ? CupertinoColors.black
                                : CupertinoColors.white,
                          )
                        : Text(
                            'Use Push/Pull/Legs',
                            style: TextStyle(
                              color: isDark
                                  ? CupertinoColors.black
                                  : CupertinoColors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              CupertinoButton(
                onPressed: _isSeeding ? null : _startCustom,
                child: const Text(
                  'Customize',
                  style: TextStyle(fontSize: 16),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayPreview extends StatelessWidget {
  final String label;
  final String value;
  final bool isRest;

  const _DayPreview({
    required this.label,
    required this.value,
    this.isRest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isRest ? FontWeight.w400 : FontWeight.w600,
              color: isRest
                  ? CupertinoColors.systemGrey
                  : CupertinoTheme.of(context).textTheme.textStyle.color,
            ),
          ),
        ],
      ),
    );
  }
}
