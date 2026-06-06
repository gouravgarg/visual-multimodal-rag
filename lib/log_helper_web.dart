// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'app_config.dart';

void saveResponseLog(Map<String, dynamic> responseData) {
  try {
    final String env = AppConfig.appEnvironment.toUpperCase();
    if (env == 'LOCAL') {
      final DateTime now = DateTime.now();
      final String timestamp =
          '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}-'
          '${now.minute.toString().padLeft(2, '0')}-'
          '${now.second.toString().padLeft(2, '0')}';

      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String prettyJson = encoder.convert(responseData);

      // Create a Blob containing the pretty JSON and trigger an automatic browser download
      final blob = html.Blob([prettyJson], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'response_$timestamp.json')
        ..style.display = 'none';
      
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      safePrint('Local Log (Web): Triggered download for response_$timestamp.json');
    }
  } catch (e) {
    safePrint('Local Log Warning (Web): Failed to download response log -> $e');
  }
}
