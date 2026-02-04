import 'dart:io';
import 'package:native_exif/native_exif.dart';

class ExifService {
  /// Extract the original date from EXIF data.
  /// Falls back to file lastModified if EXIF date is not available.
  Future<DateTime?> getPhotoDate(String filePath) async {
    try {
      final exif = await Exif.fromPath(filePath);
      try {
        final date = await exif.getOriginalDate();
        if (date != null) return date;
      } finally {
        await exif.close();
      }
    } catch (_) {
      // EXIF reading failed, fall back to file date
    }

    // Fallback: file lastModified
    try {
      final file = File(filePath);
      return await file.lastModified();
    } catch (_) {
      return null;
    }
  }

  /// Strip GPS coordinates from a photo file (modifies in-place).
  /// Returns true if GPS data was found and removed.
  Future<bool> stripGpsData(String filePath) async {
    try {
      final exif = await Exif.fromPath(filePath);
      try {
        final coords = await exif.getLatLong();
        if (coords == null) return false;

        // Clear all GPS-related EXIF fields
        await exif.writeAttribute('GPSLatitude', '');
        await exif.writeAttribute('GPSLatitudeRef', '');
        await exif.writeAttribute('GPSLongitude', '');
        await exif.writeAttribute('GPSLongitudeRef', '');
        await exif.writeAttribute('GPSAltitude', '');
        await exif.writeAttribute('GPSAltitudeRef', '');

        return true;
      } finally {
        await exif.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Create a copy of the photo with GPS data stripped.
  /// Returns the path to the new file without GPS data.
  Future<String> copyWithoutGps(String sourcePath, String destPath) async {
    // Copy the file first
    await File(sourcePath).copy(destPath);
    // Strip GPS from the copy
    await stripGpsData(destPath);
    return destPath;
  }
}
