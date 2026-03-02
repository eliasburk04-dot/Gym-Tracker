import 'package:flutter/cupertino.dart';

/// A +/- stepper control with large touch targets (44pt+)
/// HIG compliant: system font, minimal chrome, clear affordance.
class StepperControl extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final double minTouchTarget;

  const StepperControl({
    super.key,
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
    this.minTouchTarget = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark
                ? CupertinoColors.systemGrey
                : CupertinoColors.systemGrey2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? CupertinoColors.systemGrey6.darkColor
                : CupertinoColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepperButton(
                icon: CupertinoIcons.minus,
                onTap: onDecrement,
                size: minTouchTarget,
              ),
              SizedBox(
                width: 64,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.textStyle.color,
                  ),
                ),
              ),
              _StepperButton(
                icon: CupertinoIcons.plus,
                onTap: onIncrement,
                size: minTouchTarget,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: CupertinoTheme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}
