# PersiPad

[![GitHub stars](https://img.shields.io/github/stars/alireza-haeri/persipad?style=social)](https://github.com/alireza-haeri/persipad/stargazers) [![GitHub license](https://img.shields.io/github/license/alireza-haeri/persipad)](LICENSE) [![GitHub issues](https://img.shields.io/github/issues/alireza-haeri/persipad)](https://github.com/alireza-haeri/persipad/issues)

📝 **PersiPad** is a beautiful, privacy-first, open source journal & diary app designed for people who value simplicity, minimalism, and control over their personal data.

## 🌟 Key Features

- **Timeline journaling** – your life flows naturally, no folders or tabs
- **Dedicated tablet UI** – optimized layouts for iPad & Android tablets, making writing and reading more immersive
- **Fully customizable writing** – bold, lists, checkboxes, colors, 1300+ Google Fonts
- **Throwback memories** – see what you wrote on this day years ago
- **Photo memories** – add multiple photos per page with custom layout
- **Feelings & moods tracker** – 45+ emotions, history & calendar view
- **Multi-page entries** – perfect for novels, prompts, or daily notes
- **Tags, stars & search** – keep your story organized and easy to find
- **Privacy first** – PIN, FaceID, fingerprint lock; data stays on your device
- **Backup & sync** – private Google Drive sync & offline local export
- **Themes & customization** – 20+ color themes, dark/light mode, fonts & layouts
- **Export & share** – text, markdown, or full backups with attachments (images, audio, etc.)
- **Available in Persian and English** – and fully open source for transparency

## ⚙️ Setup & Run

Before getting started, ensure you have the following tools:

- Java: 21 [(LTS)](https://www.oracle.com/java/technologies/java-se-support-roadmap.html) (for Android)
- Ruby: 3.3.5 (for IOS)
- Flutter: 3.29.0

For easy setup and running, the GoogleService-Info.plist and google-services.json are provided directly in this repo, and `bin/dev` generates an empty Dart-defines fallback automatically (RevenueCat, Maps, Google Sign-In, etc. just no-op). Simply run the project with any of the following commands:

```sh
# For android
bin/dev --community

# For ios
bin/dev --community-ios

# For macos
bin/dev --community-macos
```

## 🛠 PersiPad Project Overview

PersiPad is designed with simplicity in mind, both in its UI and codebase. We aimed to keep the code understandable while staying true to Flutter's principles.

### 1. State Management:

PersiPad uses Provider and Stateful widgets to manage its state, distinctly organized into three levels to avoid confusion:

- Global State: Managed by [ProviderScope](lib/provider_scope.dart), disposed when the app closes.
- View State: Managed by ChangeNotifierProvider (package:provider/provider.dart), disposed when the page closes.
- Widget State: Managed by Stateful widgets, where the widget itself controls its own state and is disposed when removed from the tree.

### 2. MVVM Pattern:

PersiPad leverages the MVVM (Model-View-ViewModel) pattern while each view is composed of three to four key files:

- Model (optional): Represents the data structure, e.g., StoryDbModel.
- View: Constructs the view model and builds the UI content, e.g., EditStoryView.
- ViewContent: Displays the actual UI, keeping the visual layout separate from business logic, e.g., EditStoryContent.
- ViewModel: Manages business logic, provides data & operations to the view, keeping the UI free from unnecessary logic, e.g., EditStoryViewModel.

[![MVVM with layers](https://docs.flutter.dev/assets/images/docs/app-architecture/guide/mvvm-intro-with-layers.png)](https://docs.flutter.dev/app-architecture/guide#mvvm)

### 3. Local Database:

PersiPad uses ObjectBox as the local database solution for persistent data storage. ObjectBox provides fast, efficient, and scalable database operations with rich search capabilities, making it ideal for mobile apps that require high-performance data handling.

## 🤝 Learn & Contribute

Explore the PersiPad source code and contribute through our repository. It's a great resource for learning how to build efficient, maintainable mobile apps with Flutter. You can also contribute improvements or new features, helping enhance the project for everyone.

Check out our [Contribution Guide](CONTRIBUTING.md) for more details on how to contribute. Raise an issue if you need any support.

A big thank you to the maintainers of the packages PersiPad relies on - without their work, PersiPad wouldn't be possible. You can view all the dependencies in the [pubspec.yaml](pubspec.yaml) file.

## 📄 License

PersiPad is distributed under the GNU General Public License v3.0. The original copyright attribution is preserved in [LICENSE](LICENSE); modifications and redistribution must comply with that license.

## 🔗 Connect with Us

- 🌐 **Project repository:** [https://github.com/alireza-haeri/persipad](https://github.com/alireza-haeri/persipad)
- 🐛 **Issues and feature requests:** [https://github.com/alireza-haeri/persipad/issues](https://github.com/alireza-haeri/persipad/issues)
