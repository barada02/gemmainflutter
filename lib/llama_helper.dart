import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class LlamaHelper {
  // Copy native libraries from assets to a readable location based on platform
  static Future<String> getNativeLibraryPath() async {
    if (Platform.isAndroid) {
      return await _extractLibraryForAndroid("libllama.so");
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
  }

  static Future<String> _extractLibraryForAndroid(String libraryName) async {
    // For Android, we don't need to extract the library as it's loaded 
    // directly from the jniLibs directory by the system
    // Just return the library name, and the system will find it
    return libraryName;
  }

  static Future<String> _extractLibraryForDesktop(String libraryName, String platform) async {
    final directory = await getApplicationSupportDirectory();
    final libFile = File('${directory.path}/$libraryName');
    
    if (!await libFile.exists()) {
      final data = await rootBundle.load('assets/libs/$platform/$libraryName');
      await libFile.writeAsBytes(data.buffer.asUint8List());
    }
    
    return libFile.path;
  }
}
