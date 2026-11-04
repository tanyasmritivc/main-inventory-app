import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:file_picker/file_picker.dart';

class CapturePhotoPicker extends ImagePickerPlatform {
  List<XFile> images = [];
  final sources = <ImageSource>[];
  int multiCalls = 0;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    sources.add(source);
    return null; // Native cancellation, with the active route preserved.
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    multiCalls++;
    return images;
  }
}

class CaptureFilePicker extends FilePicker {
  int calls = 0;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    calls++;
    return null;
  }
}
