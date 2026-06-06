import 'dart:convert';
import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'app_config.dart';

void saveResponseLog(Map<String, dynamic> responseData) async {
  try {
    final String env = AppConfig.appEnvironment.toUpperCase();
    if (env == 'LOCAL') {
      Directory logsDir = Directory('response_logs');
      try {
        if (!await logsDir.exists()) {
          await logsDir.create(recursive: true);
        }
      } catch (e) {
        // Fallback to system temp directory if current working directory isn't writeable (e.g. mobile sandbox)
        logsDir = Directory('${Directory.systemTemp.path}/response_logs');
        if (!await logsDir.exists()) {
          await logsDir.create(recursive: true);
        }
      }

      final DateTime now = DateTime.now();
      final String timestamp =
          '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}-'
          '${now.minute.toString().padLeft(2, '0')}-'
          '${now.second.toString().padLeft(2, '0')}_'
          '${now.millisecond.toString().padLeft(3, '0')}';

      final File logFile = File('${logsDir.path}/response_$timestamp.json');

      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String prettyJson = encoder.convert(responseData);

      await logFile.writeAsString(prettyJson);
      safePrint('Local Log: Saved response to ${logFile.absolute.path}');
    }
  } catch (e) {
    safePrint('Local Log Warning: Failed to save response log -> $e');
  }
}
