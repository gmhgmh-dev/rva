/// Centralized application version and release metadata.
/// 
/// Values can be overridden at build time via dart-define:
/// flutter build apk --dart-define=GIT_HASH=abc1234 --dart-define=BUILD_NUMBER=4
class AppVersion {
  static const String versionName = '0.2.2';
  static const String defaultBuildNumber = '4';
  static const String releaseChannel = 'stable';

  /// Compile-time passed build number or fallback to default.
  static const String buildNumber = String.fromEnvironment('BUILD_NUMBER', defaultValue: defaultBuildNumber);

  /// Compile-time passed Git commit hash (short) or empty if not provided.
  static const String gitHash = String.fromEnvironment('GIT_HASH', defaultValue: '');

  /// Compile-time passed build date/time or empty.
  static const String buildTime = String.fromEnvironment('BUILD_TIME', defaultValue: '');

  /// Formatted release tag like 'v0.2.2-stable'
  static const String releaseTag = 'v$versionName-$releaseChannel';

  /// Full display string for the About screen and logs.
  static String get displayVersion {
    final buffer = StringBuffer('Versija $versionName (Būvējums $buildNumber)');
    if (gitHash.isNotEmpty) {
      buffer.write(' • $gitHash');
    } else {
      buffer.write(' • $releaseTag');
    }
    return buffer.toString();
  }
}
