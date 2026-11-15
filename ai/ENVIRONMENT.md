# محیط اجرا و بیلد

## وضعیت محیط سندباکس (جایی که من کد می‌زنم) — مهم

بررسی‌شده در 2026-11-15:

| مورد | وضعیت | معنی |
|---|---|---|
| Flutter SDK | ❌ نصب نیست | `flutter`, `dart` در PATH نیستند |
| دسترسی به `pub.dev` | ❌ بلاک | `flutter pub get` ممکن نیست |
| دسترسی به `storage.googleapis.com` / `dl.google.com` | ❌ بلاک | دانلود SDK یا NDK ممکن نیست |
| دسترسی به `services.gradle.org` | ❌ بلاک | بیلد Gradle/اندروید ممکن نیست |
| دسترسی به `github.com`, `api.github.com`, `codeload` | ✅ باز | کلون/پوش/PR ممکن است |
| دسترسی به `registry.npmjs.org`, `pypi.org` | ✅ باز | (برای این پروژه کاربردی ندارد) |

**نتیجه‌ی عملی:**

- من می‌توانم کد را **بخوانم، بنویسم، بازآرایی کنم، مستند کنم و کامیت/پوش کنم**.
- من **نمی‌توانم** در این محیط `flutter analyze` / `flutter test` / بیلد اجرا کنم.
- پس **تأیید نهایی همیشه با تو است** روی ماشین خودت (لینوکس یا اندروید).
- برای جبران، من: تغییرات را کوچک نگه می‌دارم، الگوی موجود کد را دقیق کپی می‌کنم،
  و در پایان هر تسک دقیقاً می‌نویسم «چی را باید تست کنی».

اگر روزی یکی از این‌ها در دسترس شد (مثلاً آینه‌ی pub یا نصب SDK)، همین جدول
آپدیت می‌شود و می‌توانیم تحلیل ایستا را هم خودکار کنیم.

## پیش‌نیازهای ماشین خودت

طبق `.tool-versions` و `README.md` پروژه:

- Flutter `3.47.4-stable` (README قدیمی‌تر 3.29 می‌گوید؛ `pubspec.yaml` روی
  `sdk: ^3.11.0` است — **نسخه‌ی معتبر همان `.tool-versions` است**)
- Java 21 (`openjdk-21`) برای اندروید
- Node 24، Python 3.12 (فقط برای اسکریپت‌های `bin/`)
- اندروید: minSdk 24، compileSdk 37
- لینوکس: ابزارهای GTK/CMake استاندارد Flutter desktop
  (`clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev`)

## دستورهای کار روزمره

```bash
# وابستگی‌ها + تولید کد
flutter pub get
bin/build_runner --delete        # گاهی لازم است چون *.g.dart کامیت شده‌اند

# اجرا روی اندروید (فلیور عمومی؛ فلیور storypad به کلید خصوصی نیاز دارد)
bin/dev --community

# اجرا روی لینوکس (اسکریپت bin/dev برای لینوکس ساخته نشده؛ مستقیم اجرا کن)
flutter run -d linux --target=lib/main_community.dart --dart-define-from-file=bin/.tmp/private_keys/dart_defines/community.json
# اگر فایل dart-defines ساخته نشد، bin/dev --community یک بار اجرا شود تا
# sync_private_keys آن را بسازد؛ یا با --dart-define های خالی اجرا کن.

# کیفیت
dart format lib packages
flutter analyze
flutter test
flutter test packages/storypad_editor
```

### نکته‌ی لینوکس

`bin/dev` هیچ ورودی `--linux` ندارد (فقط android/ios/macos). اگر بخواهی می‌توانیم
یک `--community-linux` به آن اضافه کنیم — این کار در [`BACKLOG.md`](BACKLOG.md)
ثبت شده است.

در لینوکس این‌ها عمداً خاموش/جایگزین می‌شوند و باید در تست‌ها به یاد داشته باشیم:

- Firebase (`firebase_initializer.dart`: `if (Platform.isLinux) return;`) → پس
  Analytics/Crashlytics/RemoteConfig خالی می‌شوند و نباید فرض کنیم کار می‌کنند.
- Local auth / بیومتریک (`local_auth_service.dart`) → قفل با PIN بماند.
- IAP (`kIAPEnabled` فقط Android/iOS/macOS) → paywall باید بدون خرید هم قابل عبور باشد.
- Google Drive مسیر جداگانه دارد: `GoogleDriveLinuxCloudService` (loopback OAuth).
- دوربین، Quick Actions، Video Compression روی لینوکس نیستند: `kSupportCamera`,
  `kSupportQuickActions`, `kSupportVideoCompression`.

## خطرات شناخته‌شده

- فایل `lib/main_storypad.dart` و `lib/firebase_options/storypad.dart` در
  `.gitignore` هستند → بیلد فلیور `storypad` بدون کلیدهای خصوصی شکست می‌خورد. از
  `--community` استفاده کن.
- `*.g.dart` در ریپو کامیت شده‌اند؛ اگر مدل را عوض کنی و build_runner اجرا نشود،
  خطاهای عجیب می‌گیری.
