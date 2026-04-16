📱 Edoras Member App

Edoras Member App, Edoras Akademi üyeleri için geliştirilmiş bir mobil uygulamadır.
Kullanıcılar antrenman programlarını, beslenme planlarını ve seanslarını tek bir platform üzerinden takip edebilir.

🚀 Özellikler
🔐 JWT tabanlı güvenli giriş sistemi
🏋️‍♂️ Antrenman planlarını görüntüleme
🥗 Beslenme planı takibi
📅 Seans (randevu) yönetimi
👤 Profil ve vücut ölçüleri yönetimi
📊 Günlük kalori ve makro hedefleri
🧠 Koç tarafından atanan planları görüntüleme
🛠️ Kullanılan Teknolojiler
Mobile
Flutter (Dart)
Dio (HTTP client)
flutter_secure_storage (Token saklama)
Backend
PHP (Custom REST API)
MySQL
JWT Authentication
🔗 API

Uygulama aşağıdaki backend API ile haberleşir:

https://kocluk.edorasakademi.com/api
📂 Proje Yapısı
lib/
│
├── core/
│   ├── api/
│   ├── storage/
│
├── features/
│   ├── auth/
│   ├── home/
│   ├── nutrition/
│   ├── workout/
│   ├── profile/
│   ├── sessions/
│
└── main.dart
🔐 Authentication
JWT tabanlı authentication kullanılır
Token, flutter_secure_storage içinde saklanır
Dio interceptor ile tüm isteklere otomatik eklenir
401 hatalarında otomatik logout yapılır
📦 Kurulum
1. Repo’yu klonla
git clone https://github.com/furkanesmer-dev/edoras-member-app.git
cd edoras-member-app
2. Paketleri yükle
flutter pub get
3. Uygulamayı çalıştır
flutter run
⚙️ Ortam Ayarları

Gerekirse base URL’i güncelle:

const baseUrl = "https://kocluk.edorasakademi.com/api";
📸 Ekranlar
Login / Register
Home Dashboard
Antrenman Planı
Beslenme Planı
Seanslarım
Profil
🧩 Geliştirme Notları
Tüm API çağrıları Dio üzerinden yapılır
State yönetimi basit ve modüler yapıdadır
Feature-based architecture kullanılmıştır
Backend ile tamamen stateless (JWT) iletişim vardır
📌 Roadmap
 Beslenme günlük takip geliştirmeleri
 Workout detay ekranı iyileştirmeleri
 UI kit oluşturulması
 Push notification sistemi
 Offline cache desteği
👨‍💻 Geliştirici

Furkan Esmer

📄 Lisans

Bu proje özel kullanım için geliştirilmiştir.
