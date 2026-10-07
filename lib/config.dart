class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static bool get configured => supabaseUrl.startsWith('https://') && supabasePublishableKey.isNotEmpty;
}
