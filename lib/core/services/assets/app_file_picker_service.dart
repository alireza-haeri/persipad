import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:storypad/core/objects/picked_media_object.dart';
import 'package:storypad/core/services/assets/asset_file_type_service.dart';
import 'package:storypad/core/services/assets/video_compression_progress.dart';
import 'package:storypad/core/services/assets/video_compression_service.dart';
import 'package:storypad/core/types/asset_compression_option.dart';
import 'package:storypad/providers/root_provider.dart';
import 'package:storypad/views/video_compression/video_compression_view.dart';

class AppFilePickerService {
  static final ImagePicker _imagePicker = ImagePicker();

  /// Extensions offered by the desktop file dialog, without leading dots (the
  /// format `file_picker` expects).
  ///
  /// [videoExtensions] must stay in sync with [AssetFileTypeService]: a video
  /// picked here has to be classified as a video downstream, otherwise it is
  /// inserted as an image. `media_picker_extensions_test.dart` enforces that.
  static const List<String> imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'];
  static const List<String> videoExtensions = ['mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp', 'wmv', 'flv'];
  static List<String> get mediaExtensions => [...imageExtensions, ...videoExtensions];

  /// `image_picker` has a Linux implementation (`image_picker_linux`, built on
  /// file_selector) but it only serves a single image: video and multi-select
  /// return `UnimplementedError` there, so "record"/"select from photos" did
  /// nothing on the desktop. `file_picker` is already a dependency and covers
  /// every case, so the desktop routes use it directly.
  static bool get _useFilePickerForMedia => !kIsWeb && (Platform.isLinux || Platform.isWindows);

  /// Opens the OS file dialog. Mirrors the `FilePicker.pickFiles` usage already
  /// proven in [pickJsonFile].
  static Future<List<XFile>> _pickFilesFromDisk({
    required List<String> allowedExtensions,
    required bool allowMultiple,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
    );
    return result.map((file) => file.xFile).toList();
  }

  static Future<PickedMediaObject?> pickImage({
    required ImageSource source,
    required AssetCompressionOption compression,
  }) async {
    if (_useFilePickerForMedia) {
      // No camera on the desktop and no imageQuality pass either: the file is
      // used as-is (video is the only media this app re-encodes itself).
      final files = await _pickFilesFromDisk(allowedExtensions: imageExtensions, allowMultiple: false);
      if (files.isEmpty) return null;
      return PickedMediaObject.read(files.first);
    }

    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: compression.imagePickerQuality,
    );
    if (image == null) return null;

    return PickedMediaObject.read(image);
  }

  /// `image_picker` applies the user's [AssetCompressionOption] to images
  /// itself (`imageQuality`) but offers nothing equivalent for video, so the
  /// re-encode is done here instead -- same moment, same setting, so nothing
  /// downstream has to know a video was ever compressed.
  ///
  /// Re-encoding takes seconds on a long clip, which is why the progress screen
  /// lives here too rather than at each call site: one that forgot it would just
  /// look frozen. [context] is only used for that -- and only to reach the
  /// root navigator's context, resolved before the picker is opened, so the
  /// screen survives the caller's own sheet/route going away while picking.
  static Future<PickedMediaObject?> pickVideo({
    required BuildContext context,
    required ImageSource source,
    required AssetCompressionOption compression,
  }) async {
    final rootContext = context.read<RootProvider>().navigatorKey.currentContext;

    if (_useFilePickerForMedia) {
      final files = await _pickFilesFromDisk(allowedExtensions: videoExtensions, allowMultiple: false);
      if (files.isEmpty) return null;
      // VideoCompressionService is a no-op on the desktop (kSupportVideoCompression),
      // so this returns the original file — no extra copy, no progress screen.
      return _compressAndRead(files.first, compression);
    }

    final video = await _imagePicker.pickVideo(source: source);
    if (video == null) return null;
    if (rootContext == null || !rootContext.mounted) return _compressAndRead(video, compression);

    final picked = await VideoCompressionRoute.run<PickedMediaObject>(
      rootContext,
      totalVideos: 1,
      task: (progress) => _compressAndRead(video, compression, progress),
    );

    return picked ?? await PickedMediaObject.read(video);
  }

  static Future<PickedMediaObject> _compressAndRead(
    XFile video,
    AssetCompressionOption compression, [
    VideoCompressionProgress? progress,
  ]) async {
    // A cancel mid-batch keeps every remaining video at its original quality,
    // the same fallback every other compression failure takes.
    if (progress?.cancelled == true) return PickedMediaObject.read(video);
    return PickedMediaObject.read(await VideoCompressionService.compress(video, compression) ?? video);
  }

  /// Opens the native OS picker for a mixed image+video multi-select
  /// (e.g. the system Photos picker). The result can contain both images and
  /// videos -- callers must classify each file (see `InsertFileToDbService.insertMedia`).
  static Future<List<PickedMediaObject>> pickMultipleMedia({
    required BuildContext context,
    required AssetCompressionOption compression,
  }) async {
    final rootContext = context.read<RootProvider>().navigatorKey.currentContext;

    if (_useFilePickerForMedia) {
      final picked = await _pickFilesFromDisk(allowedExtensions: mediaExtensions, allowMultiple: true);
      if (picked.isEmpty) return [];
      final videoCount = picked.where(AssetFileTypeService.isVideo).length;
      if (videoCount == 0 || rootContext == null || !rootContext.mounted) {
        return _readAll(picked);
      }

      final result = await VideoCompressionRoute.run<List<PickedMediaObject>>(
        rootContext,
        totalVideos: videoCount,
        task: (progress) => _compressVideosAndRead(picked, compression, progress),
      );

      return result ?? await _readAll(picked);
    }

    final files = await _imagePicker.pickMultipleMedia(imageQuality: compression.imagePickerQuality);

    // Skip the screen entirely for an all-images batch -- nothing to re-encode.
    final int videoCount = files.where(AssetFileTypeService.isVideo).length;
    if (videoCount == 0) return _readAll(files);
    if (rootContext == null || !rootContext.mounted) return _compressVideosAndRead(files, compression);

    final picked = await VideoCompressionRoute.run<List<PickedMediaObject>>(
      rootContext,
      totalVideos: videoCount,
      task: (progress) => _compressVideosAndRead(files, compression, progress),
    );

    return picked ?? await _readAll(files);
  }

  /// Compresses every video in a mixed batch, leaving images (already
  /// compressed by the picker itself) untouched.
  static Future<List<PickedMediaObject>> _compressVideosAndRead(
    List<XFile> files,
    AssetCompressionOption compression, [
    VideoCompressionProgress? progress,
  ]) async {
    final result = <PickedMediaObject>[];
    int videoIndex = 0;

    for (final file in files) {
      if (!AssetFileTypeService.isVideo(file)) {
        result.add(await PickedMediaObject.read(file));
        continue;
      }

      progress?.startVideo(videoIndex++);
      result.add(await _compressAndRead(file, compression, progress));
    }

    return result;
  }

  static Future<List<PickedMediaObject>> _readAll(List<XFile> files) async {
    final result = <PickedMediaObject>[];
    for (final file in files) {
      result.add(await PickedMediaObject.read(file));
    }
    return result;
  }

  static Future<XFile?> pickJsonFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    return result.firstOrNull?.xFile;
  }

  static Future<XFile?> pickGzipFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gz'],
    );
    return result.firstOrNull?.xFile;
  }

  static Future<LostDataResponse> retrieveLostData() {
    return _imagePicker.retrieveLostData();
  }
}
