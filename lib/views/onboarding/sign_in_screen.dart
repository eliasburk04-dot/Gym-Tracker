import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _showEmailForm = false;
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithApple();
      if (mounted) _onSignInSuccess();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
      if (mounted) _onSignInSuccess();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password required');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      if (_isSignUp) {
        await authService.createAccount(email, password);
      } else {
        await authService.signInWithEmail(email, password);
      }
      if (mounted) _onSignInSuccess();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSignInSuccess() {
    context.go('/account');
  }

  String _friendlyError(String error) {
    if (error.contains('user-not-found')) {
      return 'No account found with this email';
    }
    if (error.contains('wrong-password')) return 'Incorrect password';
    if (error.contains('email-already-in-use')) return 'Account already exists';
    if (error.contains('weak-password')) {
      return 'Password must be 6+ characters';
    }
    if (error.contains('invalid-email')) return 'Invalid email address';
    if (error.contains('cancelled')) return 'Sign in cancelled';
    if (error.contains('network-request-failed')) {
      return 'Network error while signing in';
    }
    return 'Sign in failed. Please try again.';
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

              // Logo / Title
              Text(
                'TapLift',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: isDark ? CupertinoColors.white : CupertinoColors.black,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Auth-only rebuild shell.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.systemGrey,
                ),
              ),

              const Spacer(flex: 2),

              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CupertinoColors.systemRed,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (!_showEmailForm) ...[
                // Apple Sign In
                _SignInButton(
                  icon: CupertinoIcons.person_crop_circle_fill,
                  label: 'Sign in with Apple',
                  onTap: _isLoading ? null : _signInWithApple,
                  isPrimary: true,
                ),
                const SizedBox(height: 12),

                // Google Sign In
                _SignInButton(
                  icon: CupertinoIcons.globe,
                  label: 'Sign in with Google',
                  onTap: _isLoading ? null : _signInWithGoogle,
                ),
                const SizedBox(height: 12),

                // Email Sign In
                _SignInButton(
                  icon: CupertinoIcons.mail,
                  label: 'Sign in with Email',
                  onTap: _isLoading
                      ? null
                      : () => setState(() => _showEmailForm = true),
                ),
              ] else ...[
                // Email form
                CupertinoTextField(
                  controller: _emailController,
                  placeholder: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? CupertinoColors.systemGrey6.darkColor
                        : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: _passwordController,
                  placeholder: 'Password',
                  obscureText: true,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? CupertinoColors.systemGrey6.darkColor
                        : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 16),
                _SignInButton(
                  icon: CupertinoIcons.arrow_right,
                  label: _isSignUp ? 'Create Account' : 'Sign In',
                  onTap: _isLoading ? null : _signInWithEmail,
                  isPrimary: true,
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign In'
                        : 'No account? Create one',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                CupertinoButton(
                  onPressed: () => setState(() => _showEmailForm = false),
                  child: const Text('Back', style: TextStyle(fontSize: 14)),
                ),
              ],

              if (_isLoading) ...[
                const SizedBox(height: 16),
                const CupertinoActivityIndicator(),
              ],

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _SignInButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isPrimary
              ? (isDark ? CupertinoColors.white : CupertinoColors.black)
              : (isDark
                    ? CupertinoColors.systemGrey6.darkColor
                    : CupertinoColors.white),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary
                  ? (isDark ? CupertinoColors.black : CupertinoColors.white)
                  : (isDark ? CupertinoColors.white : CupertinoColors.black),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isPrimary
                    ? (isDark ? CupertinoColors.black : CupertinoColors.white)
                    : (isDark ? CupertinoColors.white : CupertinoColors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
