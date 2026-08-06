import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void debug(String message) {
    if (kDebugMode) developer.log(message, name: 'SkillForge');
  }

  static void warn(String message) {
    if (kDebugMode) developer.log(message, name: 'SkillForge', level: 900);
  }

  static void error(String message) {
    if (kDebugMode) developer.log(message, name: 'SkillForge', level: 1000);
  }
}
