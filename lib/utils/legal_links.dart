import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';

/// The public web pages Google Play requires (Privacy Policy, plus Terms
/// and the account-deletion instructions page). The source HTML lives in
/// this repo's `docs/` folder; these constants must match wherever that
/// folder is actually published (see Documents/FOUNDER_LAUNCH_GUIDE.md,
/// "Publish your legal pages").
///
/// NOTE for the founder: after you publish the pages, change [baseUrl] to your
/// real address (it must end with a slash) and re-release.
abstract final class LegalLinks {
  static const String baseUrl = 'https://amankumar96.github.io/BrainMantra/';

  static final Uri privacyPolicy = Uri.parse('${baseUrl}privacy.html');
  static final Uri termsOfService = Uri.parse('${baseUrl}terms.html');
  static final Uri deleteAccount = Uri.parse('${baseUrl}delete-account.html');
}

/// Opens [uri] in the phone's browser. A function type (not a direct
/// `launchUrl` call) so widget tests can swap in a fake instead of hitting
/// the real platform channel.
typedef UrlOpener = Future<bool> Function(Uri uri);

Future<bool> defaultUrlOpener(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// A small, tappable "Privacy Policy" / "Terms of Service" text link.
class LegalLinkText extends StatelessWidget {
  const LegalLinkText({
    super.key,
    required this.label,
    required this.uri,
    this.opener = defaultUrlOpener,
    this.fontSize = 12,
  });

  final String label;
  final Uri uri;
  final UrlOpener opener;
  final double fontSize;

  Future<void> _open(BuildContext context) async {
    var opened = false;
    try {
      opened = await opener(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't open the link. Check your internet connection."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: AppColors.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

/// "Privacy Policy · Terms of Service" on one row.
class LegalLinksRow extends StatelessWidget {
  const LegalLinksRow({super.key, this.opener = defaultUrlOpener});

  final UrlOpener opener;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      children: [
        LegalLinkText(
          label: 'Privacy Policy',
          uri: LegalLinks.privacyPolicy,
          opener: opener,
        ),
        const Text('·', style: TextStyle(color: AppColors.neutral)),
        LegalLinkText(
          label: 'Terms of Service',
          uri: LegalLinks.termsOfService,
          opener: opener,
        ),
      ],
    );
  }
}
