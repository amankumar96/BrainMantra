import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/legal_links.dart';
import '../utils/network_error.dart';

/// The in-app half of Google Play's required account-deletion flow (the
/// other half is the public instructions page linked from the Play
/// listing — see ARCHITECTURE.md's §4c). Reaching this screen at all
/// (via `home_screen.dart`'s corner button) plus deliberately pressing
/// its one destructive action is the confirmation step — no further
/// dialog stacked on top of it.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _isDeleting = false;
  String? _errorMessage;
  bool _isOffline = false;

  Future<void> _confirmDelete() async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
      _isOffline = false;
    });
    try {
      await AuthService.deleteAccount();
      // deleteAccount() signs out on success, but this screen was
      // *pushed* on top of Home — the root _AuthGate in main.dart only
      // controls what sits at the bottom of the navigation stack, so it
      // swapping to the login flow wouldn't, by itself, pop this screen
      // (and Home underneath it) off the top. Popping back to the first
      // route explicitly is what actually reveals that swap — the same
      // pattern results_screen.dart's Home button already uses.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      // A dropped connection (confirmed via a real offline device test)
      // otherwise surfaced as a raw FunctionsFetchException/
      // SocketException string — an OfflineNotice reads far better than
      // that for something as ordinary as "no signal right now".
      final offline = isOfflineError(e);
      setState(() {
        _isDeleting = false;
        _isOffline = offline;
        _errorMessage = offline ? null : 'Could not delete your account: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Delete Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Deleting your account is permanent and cannot be undone.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('This removes:'),
              const SizedBox(height: AppSpacing.sm),
              const _DeletedItem(
                'Your account and sign-in (email or linked Google account)',
              ),
              const _DeletedItem('Your display name'),
              const _DeletedItem('Your persistent score'),
              const _DeletedItem('Your day streak'),
              const _DeletedItem(
                "Your Daily Challenge history and leaderboard placement",
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_isOffline) ...[
                const OfflineNotice(actionDescription: 'delete your account'),
                const SizedBox(height: AppSpacing.md),
              ] else if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.wrong),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isDeleting ? null : _confirmDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.wrong,
                    disabledBackgroundColor: Colors.black12,
                  ),
                  child: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Delete My Account'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isDeleting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Center(child: LegalLinksRow()),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeletedItem extends StatelessWidget {
  const _DeletedItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.close, size: 16, color: AppColors.wrong),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
