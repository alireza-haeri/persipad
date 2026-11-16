import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/assets/app_file_picker_service.dart';
import 'package:storypad/core/services/assets/asset_file_type_service.dart';

// The desktop file dialog (`file_picker`) is filtered by the extension lists in
// AppFilePickerService. If they drift from AssetFileTypeService, a picked video
// is classified as an image and gets inserted into the wrong embed slot — a
// silent data bug rather than a visible error.
void main() {
  group('desktop media extensions', () {
    test('every video extension is recognised as a video', () {
      for (final extension in AppFilePickerService.videoExtensions) {
        expect(
          AssetFileTypeService.isVideoExtension(extension),
          isTrue,
          reason: 'file dialog allows ".$extension" as media but it would be inserted as an image',
        );
      }
    });

    test('no image extension is recognised as a video', () {
      for (final extension in AppFilePickerService.imageExtensions) {
        expect(
          AssetFileTypeService.isVideoExtension(extension),
          isFalse,
          reason: '".$extension" is offered as an image but would be inserted as a video',
        );
      }
    });

    test('combined list is images plus videos', () {
      expect(AppFilePickerService.mediaExtensions, [
        ...AppFilePickerService.imageExtensions,
        ...AppFilePickerService.videoExtensions,
      ]);
    });

    test('extensions are lowercase, dot-free and unique', () {
      for (final extension in AppFilePickerService.mediaExtensions) {
        expect(extension, extension.toLowerCase());
        expect(extension.startsWith('.'), isFalse, reason: 'file_picker wants "jpg", not ".jpg"');
        expect(extension.trim(), extension);
      }

      expect(AppFilePickerService.mediaExtensions.toSet().length, AppFilePickerService.mediaExtensions.length);
    });

    test('covers the formats the app already stores', () {
      // Photos and videos people actually keep in a journal.
      for (final extension in ['jpg', 'jpeg', 'png', 'gif', 'webp']) {
        expect(AppFilePickerService.imageExtensions, contains(extension));
      }
      for (final extension in ['mp4', 'mov', 'webm']) {
        expect(AppFilePickerService.videoExtensions, contains(extension));
      }
    });
  });
}
