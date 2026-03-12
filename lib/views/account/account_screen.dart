import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/backend_auth_service.dart';
import '../../providers/auth_provider.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  AuthServerProfile? _serverProfile;
  String? _serverError;
  String? _baseUrl;
  bool _isLoadingProfile = true;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadServerProfile);
  }

  Future<void> _loadServerProfile() async {
    final authService = ref.read(authServiceProvider);
    final backendAuthService = ref.read(backendAuthServiceProvider);

    setState(() {
      _isLoadingProfile = true;
      _serverError = null;
    });

    final token = await authService.getIdToken();
    final baseUrl = await backendAuthService.getBaseUrl();

    if (token == null) {
      if (!mounted) return;
      setState(() {
        _baseUrl = baseUrl;
        _isLoadingProfile = false;
        _serverError = 'No Firebase token available';
      });
      return;
    }

    try {
      final profile = await backendAuthService.verifyToken(token);
      if (!mounted) return;
      setState(() {
        _baseUrl = baseUrl;
        _serverProfile = profile;
        _isLoadingProfile = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _baseUrl = baseUrl;
        _isLoadingProfile = false;
        _serverError = error.toString();
      });
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await ref.read(authServiceProvider).signOut();
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    if (user == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Account')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Signed in',
              style: CupertinoTheme.of(
                context,
              ).textTheme.navLargeTitleTextStyle,
            ),
            const SizedBox(height: 12),
            Text(
              'The app is now stripped down to authentication only. '
              'This screen confirms both Firebase auth and the backend token check.',
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? CupertinoColors.systemGrey2.darkColor
                    : CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 24),
            _InfoCard(
              title: 'Firebase',
              rows: [
                _InfoRow(label: 'UID', value: user.uid),
                _InfoRow(label: 'Email', value: user.email ?? 'No email'),
                _InfoRow(label: 'Provider', value: _providerSummary(user)),
              ],
            ),
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Backend',
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isLoadingProfile ? null : _loadServerProfile,
                child: const Text('Reload'),
              ),
              rows: [
                _InfoRow(label: 'Base URL', value: _baseUrl ?? 'Loading...'),
                _InfoRow(
                  label: 'Status',
                  value: _isLoadingProfile
                      ? 'Verifying token...'
                      : _serverError == null
                      ? 'Verified'
                      : 'Verification failed',
                ),
                if (_serverProfile != null) ...[
                  _InfoRow(label: 'User ID', value: _serverProfile!.id),
                  _InfoRow(
                    label: 'Auth Provider',
                    value: _serverProfile!.authProvider,
                  ),
                  _InfoRow(
                    label: 'Display Name',
                    value: _serverProfile!.displayName ?? 'Not set',
                  ),
                ],
                if (_serverError != null)
                  _InfoRow(label: 'Error', value: _serverError!),
              ],
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _isSigningOut ? null : _signOut,
              child: Text(_isSigningOut ? 'Signing out...' : 'Sign out'),
            ),
          ],
        ),
      ),
    );
  }

  String _providerSummary(User user) {
    final providers = user.providerData
        .map((provider) => provider.providerId)
        .where((provider) => provider.isNotEmpty)
        .toSet()
        .toList();

    if (providers.isEmpty) return 'Unknown';
    return providers.join(', ');
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows, this.trailing});

  final String title;
  final Widget? trailing;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? CupertinoColors.systemGrey6.darkColor
            : CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            _InfoRowView(row: rows[index]),
          ],
        ],
      ),
    );
  }
}

class _InfoRow {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;
}

class _InfoRowView extends StatelessWidget {
  const _InfoRowView({required this.row});

  final _InfoRow row;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? CupertinoColors.systemGrey2.darkColor
                : CupertinoColors.systemGrey,
          ),
        ),
        const SizedBox(height: 4),
        Text(row.value, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}
