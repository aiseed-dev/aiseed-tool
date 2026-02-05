import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class PhotoService {
  Future<String> savePhoto(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath);
    final fileName = '${const Uuid().v4()}$ext';
    final destPath = p.join(photosDir.path, fileName);

    await File(sourcePath).copy(destPath);
    return destPath;
  }

  Future<void> deletePhotoFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
