# PersiPad

PersiPad is an offline-first journal for writing in Persian or English. It is an independent fork of [StoryPad](https://github.com/theachoem/storypad). The original diary, editor and timeline are the work of the StoryPad authors and contributors. [Alireza Haeri](https://github.com/alireza-haeri) maintains this fork and adapted it for Persian-first journaling. PersiPad releases are not official StoryPad releases.

## Download for Android

**[Download PersiPad for ARM64 phones](https://github.com/alireza-haeri/persipad/releases/latest)**. Under **Assets**, choose the `.apk` ending in `arm64-v8a.apk`. The `.sha256` file is its checksum; the source archives are not installers. The ARM64 build is not intended for x86 Android emulators.

If Android refuses to update an existing debug installation, the two builds may have different signing keys. **Back up your journal and media and verify the backup before uninstalling anything.** Settings shows the installed version and links to GitHub Releases; the app does not install updates automatically.

## What's different in PersiPad?

- A Persian interface with right-to-left layouts, a Solar Hijri calendar, and configurable first days of the week and weekends.
- Calendar-based reminders, including monthly intervals and yearly schedules.
- Daily scores, customizable shortcuts and sidebar order, and profile illustrations.
- Portable settings in backups, including language, calendar preferences, reminder rules and daily scores.

## Back up and restore

Entries are stored locally. You can sync with Google Drive or export files yourself. For an offline move, keep **both** the native JSON export (entries, settings and attachment metadata) **and** the **Export Media** archive (the actual photos, audio and videos). Check that entries and attachments open on the destination before removing the originals.

Google credentials, app-lock PINs, recovery answers, biometric enrollment and system permissions do not transfer. Sign in and grant notification permission on the new device.

## Build from source

Use the Flutter and Java versions in [`.tool-versions`](.tool-versions) and install the Android SDK. From the repository root:

```sh
flutter pub get
bin/build_apk --install --launch     # Debug build for a connected device
bin/build_apk --release --abi arm64  # Release build; requires your signing key
```

See `bin/build_apk --help` for build options and [the environment guide](ai/ENVIRONMENT.md) for setup. Run `flutter test` for the app, and run `flutter test` inside `packages/storypad_editor` for the editor.

## Contributing and license

Report bugs and suggest changes in [GitHub Issues](https://github.com/alireza-haeri/persipad/issues). See the [contribution guide](CONTRIBUTING.md) and the [GNU General Public License v3](LICENSE).
