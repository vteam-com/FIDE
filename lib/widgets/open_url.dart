import 'package:fide/widgets/message_box.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the system browser, showing an error message on
/// [context] when it can't be parsed or opened.
Future<void> openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var opened = false;
  try {
    opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    MessageBox.showError(context, 'Could not open link: $url');
  }
}
