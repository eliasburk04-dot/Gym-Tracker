import 'package:flutter/cupertino.dart';

/// Large "DONE SET" button with subtle check animation on tap.
class DoneSetButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const DoneSetButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<DoneSetButton> createState() => _DoneSetButtonState();
}

class _DoneSetButtonState extends State<DoneSetButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkAnimation;
  bool _showCheck = false;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _checkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() => _showCheck = false);
            _checkController.reset();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onPressed();
    setState(() => _showCheck = true);
    _checkController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return GestureDetector(
      onTap: widget.isLoading ? null : _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: isDark
              ? CupertinoColors.white
              : CupertinoColors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: widget.isLoading
              ? CupertinoActivityIndicator(
                  color:
                      isDark ? CupertinoColors.black : CupertinoColors.white,
                )
              : _showCheck
                  ? ScaleTransition(
                      scale: _checkAnimation,
                      child: Icon(
                        CupertinoIcons.checkmark,
                        color: isDark
                            ? CupertinoColors.black
                            : CupertinoColors.white,
                        size: 24,
                      ),
                    )
                  : Text(
                      'DONE SET',
                      style: TextStyle(
                        color: isDark
                            ? CupertinoColors.black
                            : CupertinoColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
        ),
      ),
    );
  }
}
