class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://upciaiqtbinvchdmvkek.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_8WcXLNJ9kxnOvJogE4UXag_OTMzTJ5M',
  );

  const SupabaseConfig._();
}
