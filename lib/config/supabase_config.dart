class SupabaseConfig {
  // The anon key is intentionally public — Supabase RLS policies enforce
  // per-user data access. Never expose the service_role key in client code.
  //
  // To build for production:
  //   flutter build appbundle --dart-define=ENV=production
  // To run dev (default):
  //   flutter run
  //   flutter run --dart-define=ENV=development

  static const _env = String.fromEnvironment('ENV', defaultValue: 'development');
  static bool get isProduction => _env == 'production';

  static const _devUrl = 'https://umunppclpmlmjpwpqosf.supabase.co';
  static const _devAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVtdW5wcGNscG1sbWpwd3Bxb3NmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxMjc1NTgsImV4cCI6MjA5NDcwMzU1OH0.CIm0BUF3NHXvgRRUVA7tjPDsrWHpwq2L2DgSEVGnqr0';

  static const _prodUrl = 'https://bqkondmchcbqabjicdfo.supabase.co';
  static const _prodAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJxa29uZG1jaGNicWFiamljZGZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxOTA0MzMsImV4cCI6MjEwMTc2NjQzM30.xIfptSxhBEZGhlgL4iVZcwdGQYvlTMCZXeczbJhIaWc';

  static String get url => isProduction ? _prodUrl : _devUrl;
  static String get anonKey => isProduction ? _prodAnonKey : _devAnonKey;
}
