import 'package:flutter/material.dart';

import 'constants.dart';

/// Best-effort heuristic: does [error] look like "the device has no
/// internet connection" rather than a genuine server-side failure?
///
/// This project has no connectivity-checking package (`connectivity_plus`
/// etc.) and no mocked-network test infrastructure — adding either just
/// for this one classification would be a lot of new surface for what's
/// fundamentally a copy decision (which message to show), not a
/// functional one (the request already failed either way; this only
/// picks how to word it). Instead this matches the actual runtime
/// exception types/messages Dart's `dart:io`/`http`/Supabase stack
/// already produces for a dropped connection (confirmed against a real
/// on-device offline test: `FunctionsFetchException` wrapping a
/// `ClientException` wrapping a `SocketException` with "Connection reset
/// by peer").
bool isOfflineError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('socketexception') ||
      message.contains('clientexception') ||
      message.contains('connection reset') ||
      message.contains('connection refused') ||
      message.contains('failed host lookup') ||
      message.contains('network is unreachable') ||
      message.contains('timeoutexception');
}

/// A friendly "you're offline" card — used wherever an online-only action
/// (account deletion today; any future one can reuse this) fails with an
/// [isOfflineError]-classified error, instead of showing that error's raw
/// technical text.
class OfflineNotice extends StatelessWidget {
  const OfflineNotice({super.key, required this.actionDescription});

  /// e.g. "delete your account" — filled into "Connect to the internet to
  /// {actionDescription}.".
  final String actionDescription;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.neutral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off, color: AppColors.neutral),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "You're offline",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text('Connect to the internet to $actionDescription.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
