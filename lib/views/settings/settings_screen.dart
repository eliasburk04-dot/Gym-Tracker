import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),

            // Workout configuration
            CupertinoListSection.insetGrouped(
              header: const Text('WORKOUT'),
              children: [
                CupertinoListTile(
                  title: const Text('Workout Days'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => context.push('/settings/workout-days'),
                ),
                CupertinoListTile(
                  title: const Text('Weekday Schedule'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => context.push('/settings/weekday-mapping'),
                ),
              ],
            ),

            // Weight preferences
            CupertinoListSection.insetGrouped(
              header: const Text('PREFERENCES'),
              children: [
                CupertinoListTile(
                  title: const Text('Weight Unit'),
                  additionalInfo: Text(settings.weightUnit.label),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _showWeightUnitPicker(context, ref),
                ),
                CupertinoListTile(
                  title: const Text('Weight Increment'),
                  additionalInfo: Text(
                    '${settings.weightIncrement.toStringAsFixed(settings.weightIncrement % 1 == 0 ? 0 : 1)} ${settings.weightUnit.label}',
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _showIncrementPicker(context, ref),
                ),
              ],
            ),

            // Account
            CupertinoListSection.insetGrouped(
              header: const Text('ACCOUNT'),
              children: [
                CupertinoListTile(
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: CupertinoColors.destructiveRed),
                  ),
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                'TapLift v0.1.0',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeightUnitPicker(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Weight Unit'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              ref.read(settingsProvider.notifier).setWeightUnit(WeightUnit.kg);
              Navigator.pop(context);
            },
            child: const Text('Kilograms (kg)'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              ref.read(settingsProvider.notifier).setWeightUnit(WeightUnit.lb);
              Navigator.pop(context);
            },
            child: const Text('Pounds (lb)'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showIncrementPicker(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final increments = settings.weightUnit == WeightUnit.kg
        ? [1.0, 1.25, 2.0, 2.5, 5.0]
        : [2.5, 5.0, 10.0];

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Weight Increment'),
        actions: increments
            .map(
              (inc) => CupertinoActionSheetAction(
                onPressed: () {
                  ref.read(settingsProvider.notifier).setWeightIncrement(inc);
                  Navigator.pop(context);
                },
                child: Text(
                    '${inc.toStringAsFixed(inc % 1 == 0 ? 0 : 2)} ${settings.weightUnit.label}'),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _signOut(BuildContext context, WidgetRef ref) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
