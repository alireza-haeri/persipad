# نقشه‌ی کد (Architecture)

مرجع رسمی: `README.md` و `CONTRIBUTING.md` خود پروژه. این فایل خلاصه‌ی عملی
برای کار روزمره‌ی ماست. آمارها در تاریخ 2026-11-15 گرفته شده‌اند (نسخه 2.34.0).

## اطلاعات پایه

| مورد | مقدار |
|---|---|
| فramework | Flutter (Dart SDK `^3.11.0`) |
| نسخه‌ی اپ | `2.34.0+834` |
| تعداد فایل Dart | ~981 (بدون `build/`) |
| تست | 92 فایل در `test/` + 57 فایل در `packages/storypad_editor/test/` |
| دیتابیس | ObjectBox (با آداپتر قدیمی SQLite در `lib/core/databases/adapters/sqlite`) |
| State | Provider + ChangeNotifier (سه سطح: Global / View / Widget) |
| الگو | MVVM در سه‌چهار فایل: `Model` / `View` / `ViewContent` / `ViewModel` |
| i18n | `easy_localization` با ۲۰ فایل در `translations/` |
| Codegen | `build_runner` ← `json_serializable`, `copy_with_extension`, `objectbox_generator`, `flutter_gen` |

## نقطه‌ی ورود و بوت

```
lib/main.dart              → main() → App
lib/main_community.dart    → فلیور عمومی (فقط این یکی Firebase عمومی دارد)
lib/main_storypad.dart     → فلیور خصوصی (gitignored، لازم نیست)
bin/dev --community        → دستور اجرا
```

`main.dart`: `SpSplashScreenWrapper` → `_initializeApp` که به‌ترتیب این
Initializerها را صدا می‌زند (اگر Initializer جدیدی لازم شد، همین‌جا اضافه می‌شود):

`Firebase → Crashlytics → RemoteConfig → EasyLocalization → Constants →
Database → AppLock → BackupRepository → Theme → LegacyStoryPad → Onboarding →
edge-to-edge → (Android) PhotoPicker → CloudStorage → Licenses`

سپس `runApp(ProviderScope(child: App()))`.

## Providerها (State سراسری)

`lib/provider_scope.dart` — لیست کامل Providerهای گلوبال:

`RootProvider` (ناوبری و سایدبار)، `BackupProvider`، `TagsProvider`،
`AppLockProvider`، `DevicePreferencesProvider`، `InAppUpdateProvider`،
`InAppPurchaseProvider`، `NicknameProvider`، `RelaxSoundsProvider` (lazy).

> Provider جدید = افزودن به همین فایل. Provider صفحه‌ای = `ChangeNotifierProvider`
> داخل همان `XView`، نه اینجا.

## ناوبری

- `lib/views/root/` — `RootView` + `RootContent` + سایدبار (`RootSideBar`).
- هر صفحه یک `XRoute extends BaseRoute` دارد که خارج از `lib/views/X/` هم استفاده می‌شود.
- **قاعده:** ناوبری از سایدبار همیشه با `RootProvider.navigate(route)` انجام شود،
  نه `Navigator.push` مستقیم (وگرنه انتخاب سایدبار می‌شکند).
- `BaseRoute.routeName != null` → `MaterialPageRoute` از طریق `RootViewModel.generateRoute`.
  `routeName == null` → `buildRoute()` سفارشی (شیت‌ها، انیمیشن‌ها).
- `SpNestedNavigation` برای تب‌های تودرتو استفاده می‌شود (مثلاً صفحه‌ی تگ).

## لایه‌ی داده

```
lib/core/databases/
  adapters/objectbox/*.dart   ← Boxها (StoriesBox, TagsBox, EventsBox, ...)
  adapters/sqlite/            ← مسیر قدیمی/مهاجرت
  models/*_db_model.dart      ← مدل‌ها، هر کدام static db دارند
  legacy/                     ← مهاجرت از نسخه‌های قدیمی
lib/core/storages/            ← داده‌های سبک روی SharedPreferences (theme, onboarded, badges, ...)
```

مدل‌های اصلی: `StoryDbModel` (سال/ماه/روز، `latestContent`, `draftContent`, tags,
assets, `pinned`, `starred`)، `StoryContentDbModel` + `StoryPageDbModel`
(چندصفحه‌ای)، `EventDbModel` (مناسبت‌ها مثل period)، `TagDbModel`,
`TemplateDbModel`, `AssetDbModel`, `PlaceDbModel`، `PreferenceDbModel`.

- الگوی دسترسی: `await StoryDbModel.db.where(...)`. در View مستقیم به Box دست نزن.
- مهاجرت/تغییر شِما → `objectbox-model.json` عوض می‌شود و
  `bin/build_runner --delete` لازم است. **مدل ObjectBox را بدون تصمیم ثبت‌شده تغییر نده.**

## سرویس‌ها (`lib/core/services/`)

مهم‌ترین‌ها برای ما:

- `backups/` — `backup_cloud_service.dart` (اینترفیس) + پیاده‌سازی‌ها:
  `google_drive_cloud_service`, `google_drive_linux_cloud_service` (لینوکس مسیر
  جدا دارد!), `dropbox_cloud_service`, `icloud_cloud_service`,
  `nextcloud_cloud_service` (WebDAV)، و `sync_steps/`.
- `cloud_storage/adaptors/` — آداپترهای ObjectBox/فایل برای دارایی‌ها.
- `notifications/`, `audio_player_service`, `voice_recorder_service`, `record`
  → صدا و یادآورها.
- `quill/`, `export/`, `markdown_*`, `story_plain_text_exporter` → ادیتور و خروجی.
- `analytics/`, `error_reporting/`, `remote_config/` → همه از نوع
  `Base*Adaptor.create()` و در لینوکس مبدل خالی (no-op) می‌گیرند.

## ویجت‌ها

- پیشوند **`Sp`** برای ویجت‌های عمومی پروژه (`SpFilledButton`, `SpFloatingActionButton`, `SpAppBar`...).
- `lib/widgets/base_view/base_route.dart` — پایه‌ی مسیرها.
- `lib/widgets/rich_editor/` — ویرایشگر، و پکیج محلی `packages/storypad_editor`
  (نسخه‌ی فورک‌شده‌ی Quill + لایه‌ی markdown/embed).
- `packages/adaptive_dialog` — دیالوگ‌های سازگار iOS/Android.

## نقشه‌ی صفحات (`lib/views/`)

| پوشه | نقش | تعداد فایل |
|---|---|---|
| `home/` | تایم‌لاین اصلی + سال‌ها | 27 |
| `stories/` | ساخت/ویرایش/نمایش/تاریخچه‌ی استوری | 29 |
| `onboarding/`, `settings/`, `templates/` | جریان‌های اصلی | 24–26 |
| `backup_services/`, `import_export/` | پشتیبان‌گیری | 17 + 10 |
| `calendar/`, `search/`, `tags/`, `library/`, `stats/`, `throwback/`, `map/` | ابزارها | 3–12 |
| `paywall/`, `relax_sounds/`, `reminders/`, `app_locks/` | قابلیت‌های Pro/امنیت | 8–12 |

## تست

- `test/` آینه‌ی `lib/core` است (models, services, adapters, repositories).
- پکیج ادیتور تست مستقل دارد: `packages/storypad_editor/test/`.
- الگوی تست موجود را دنبال می‌کنیم؛ تست جدید کنار همان دسته‌بندی موضوعی می‌رود.

## جاهای حساس (دست بزنیم، سه بار فکر کنیم)

1. `lib/core/databases/models/*` + `objectbox.g.dart` → مهاجرت داده‌ی کاربر.
2. `lib/core/initializers/` + `lib/main.dart` → ترتیب بوت همه چیز را می‌شکند.
3. `lib/core/services/backups/*` → ریسک از دست رفتن داده.
4. `lib/provider_scope.dart` و `RootProvider` → کل ناوبری.
5. `packages/storypad_editor` → فرمت محتوای ذخیره‌شده (سازگاری عقب‌رو).
