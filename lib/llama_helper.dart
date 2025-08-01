import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class LlamaHelper {
  // Copy native libraries from assets to a readable location based on platform
  static Future<String> getNativeLibraryPath() async {
    try {
      if (Platform.isAndroid) {
        // For Android, we use the JNI libs path
        return "libllama.so";
      } else if (Platform.isIOS) {
        // For iOS, the library should be embedded in the app bundle
        return "libllama.dylib";
      } else if (Platform.isWindows) {
        return await _extractLibraryForDesktop("llama.dll", "windows");
      } else if (Platform.isMacOS) {
        return await _extractLibraryForDesktop("libllama.dylib", "macos");
      } else if (Platform.isLinux) {
        return await _extractLibraryForDesktop("libllama.so", "linux");
      } else {
        throw Exception("Unsupported platform");
      }
    } catch (e) {
      print("Error in getNativeLibraryPath: $e");
      rethrow;
    }
  }

  static Future<String> _extractLibraryForDesktop(String libraryName, String platform) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final libFile = File('${directory.path}/$libraryName');
      
      if (!await libFile.exists()) {
        print("Extracting $libraryName for $platform...");
        final data = await rootBundle.load('assets/libs/$platform/$libraryName');
        await libFile.writeAsBytes(data.buffer.asUint8List());
        print("Successfully extracted $libraryName to ${libFile.path}");
      } else {
        print("Library already exists at ${libFile.path}");
      }
      
      return libFile.path;
    } catch (e) {
      print("Error extracting library for desktop: $e");
      rethrow;
    }
  }
  
  // Helper method to check if a file is valid
  static Future<bool> isFileValid(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print("File does not exist: $filePath");
        return false;
      }
      
      final fileSize = await file.length();
      if (fileSize <= 0) {
        print("File is empty: $filePath");
        return false;
      }
      
      // For binary files, we can only check if they exist and have a size
      return true;
    } catch (e) {
      print("Error checking file: $e");
      return false;
    }
  }
}
