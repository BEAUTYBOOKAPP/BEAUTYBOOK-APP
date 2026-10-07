class AppConfig {
  static const supabaseUrl =
      'https://xmcxwdapeadaziujlmht.supabase.co';

  static const supabasePublishableKey =
      'sb_publishable_IAZONyhCoF53_BBLQ8Uzzg_p783J5ki';

  static bool get configured =>
      supabaseUrl.startsWith('https://') &&
      supabasePublishableKey.isNotEmpty;
}
