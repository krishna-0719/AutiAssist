import '../utils/app_exceptions.dart';

/// Validates Supabase configuration injected via --dart-define.
class ConfigService {
  ConfigService._();

  /// Supabase project URL.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anonymous (public) API key.
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// AI behavior backend URL (optional, auto-discovered from system_config).
  static const String behaviorApiUrl = String.fromEnvironment(
    'BEHAVIOR_API_URL',
    defaultValue: '',
  );

  /// Returns true if all required config is present.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Returns a human-readable message if config is missing, otherwise null.
  static String? get validationMessage {
    if (supabaseUrl.isEmpty) {
      return 'SUPABASE_URL is missing. Please run the app with:\n'
          'flutter run --dart-define-from-file=.env.local\n'
          'Or use the included .vscode/launch.json to run from VS Code.';
    }
    if (supabaseAnonKey.isEmpty) {
      return 'SUPABASE_ANON_KEY is missing. Check your .env.local file.';
    }
    if (!supabaseAnonKey.startsWith('eyJ')) {
      return 'SUPABASE_ANON_KEY looks invalid (should start with "eyJ").';
    }
    return null;
  }

  /// Throws ConfigException if configuration is invalid.
  static void validate() {
    final msg = validationMessage;
    if (msg != null) throw ConfigException(msg);
  }
}
