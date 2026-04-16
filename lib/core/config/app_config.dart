/// Uygulama genelinde kullanılan konfigürasyon sabitleri.
///
/// PROD: baseUrl burada merkezileştirildi.
/// İleride --dart-define ile ortam bazlı değer enjekte edilebilir:
///   flutter run --dart-define=BASE_URL=https://...
class AppConfig {
  AppConfig._();

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://kocluk.edorasakademi.com/api',
  );
}
