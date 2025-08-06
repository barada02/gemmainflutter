# Implementing Model Download After Installation in Flutter with GGUF and llama.cpp

Based on your interest in developing a Flutter app using GGUF models and llama.cpp, I can help you implement a post-installation download mechanism similar to what Google AI Edge Gallery uses. This approach will keep your app's installation size small by downloading large model files only when needed.

## Recommended Implementation Approach

### 1. Create a Model Management System

First, define a structure to manage your models:

```dart
class AIModel {
  final String id;
  final String name;
  final String url;
  final String filePath;
  final int sizeInBytes;
  final bool isDownloaded;
  final double downloadProgress;
  // Add any model-specific configurations

  AIModel({
    required this.id,
    required this.name,
    required this.url,
    required this.filePath,
    required this.sizeInBytes,
    this.isDownloaded = false,
    this.downloadProgress = 0.0,
  });
}
```

### 2. Set Up Download Manager Using `dio` Package

Install required packages:

```bash
flutter pub add dio path_provider shared_preferences
```

Create a download manager service:

```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelDownloadManager {
  final Dio _dio = Dio();
  
  Future<String> get _modelDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  Future<bool> isModelDownloaded(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('model_downloaded_$modelId') ?? false;
  }

  Future<void> downloadModel({
    required AIModel model,
    required Function(double) onProgressUpdate,
    required Function(bool, String?) onComplete,
  }) async {
    try {
      final modelDir = await _modelDirectory;
      final filePath = '$modelDir/${model.filePath}';
      
      // Create directory if needed
      final fileDir = Directory(filePath.substring(0, filePath.lastIndexOf('/')));
      if (!await fileDir.exists()) {
        await fileDir.create(recursive: true);
      }
      
      // Check if file is partially downloaded
      File file = File(filePath);
      int startByte = 0;
      if (await file.exists()) {
        startByte = await file.length();
      }

      await _dio.download(
        model.url,
        filePath,
        deleteOnError: false,
        options: Options(
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (startByte + received) / (startByte + total);
            onProgressUpdate(progress);
          }
        },
      );
      
      // Mark as downloaded
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('model_downloaded_${model.id}', true);
      
      onComplete(true, null);
    } catch (e) {
      onComplete(false, e.toString());
    }
  }

  Future<void> cancelDownload(String modelId) async {
    // Cancel any ongoing downloads
    _dio.close(force: true);
  }
}
```

### 3. Create a Background Download Service

For long-running downloads, you should use Flutter's background execution capabilities:

```dart
import 'package:flutter_background_service/flutter_background_service.dart';

class BackgroundDownloadService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'model_download_channel',
        initialNotificationTitle: 'Model Download',
        initialNotificationContent: 'Preparing download...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static void onStart(ServiceInstance service) {
    // Handle background download logic
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  static Future<void> startDownload(AIModel model) async {
    final service = FlutterBackgroundService();
    await service.startService();
    service.invoke('downloadModel', {
      'modelId': model.id,
      'url': model.url,
      'filePath': model.filePath,
    });
  }
}
```

### 4. Integrate with llama.cpp in Flutter

Create a bridge to llama.cpp using FFI:

```dart
import 'dart:ffi';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LlamaCppService {
  late final DynamicLibrary _lib;
  
  Future<void> initialize() async {
    // Load the llama.cpp library
    _lib = Platform.isAndroid 
      ? DynamicLibrary.open("libllama.so")
      : DynamicLibrary.process();
  }
  
  Future<String> getModelPath(String modelId) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/models/$modelId';
  }
  
  Future<bool> loadModel(String modelId) async {
    final modelPath = await getModelPath(modelId);
    // Use FFI to call llama.cpp functions to load the model
    // This is a simplified example - you'll need proper FFI setup
    final loadModelFunc = _lib.lookupFunction<Int32 Function(Pointer<Utf8>), int Function(Pointer<Utf8>)>('llama_load_model');
    final result = loadModelFunc(modelPath.toNativeUtf8());
    return result == 0;
  }
  
  // Additional methods for text generation, etc.
}
```

### 5. Create a Model Selection UI

```dart
class ModelSelectionScreen extends StatefulWidget {
  @override
  _ModelSelectionScreenState createState() => _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends State<ModelSelectionScreen> {
  final ModelDownloadManager _downloadManager = ModelDownloadManager();
  final List<AIModel> _availableModels = [
    AIModel(
      id: 'gemma-2b-it',
      name: 'Gemma 2B-IT GGUF',
      url: 'https://yourdomain.com/models/gemma-2b-it-q4_k_m.gguf',
      filePath: 'gemma/gemma-2b-it-q4_k_m.gguf',
      sizeInBytes: 2534400000,
    ),
    // Add more models
  ];
  
  Map<String, double> _downloadProgress = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Available Models')),
      body: ListView.builder(
        itemCount: _availableModels.length,
        itemBuilder: (context, index) {
          final model = _availableModels[index];
          return FutureBuilder<bool>(
            future: _downloadManager.isModelDownloaded(model.id),
            builder: (context, snapshot) {
              final isDownloaded = snapshot.data ?? false;
              final progress = _downloadProgress[model.id] ?? 0.0;
              
              return ListTile(
                title: Text(model.name),
                subtitle: Text('${(model.sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB'),
                trailing: isDownloaded
                  ? ElevatedButton(
                      child: Text('Try It'),
                      onPressed: () {
                        // Navigate to chat screen with this model
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(modelId: model.id),
                          ),
                        );
                      },
                    )
                  : progress > 0
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(value: progress),
                          Text('${(progress * 100).toInt()}%'),
                          IconButton(
                            icon: Icon(Icons.cancel),
                            onPressed: () {
                              _downloadManager.cancelDownload(model.id);
                              setState(() {
                                _downloadProgress.remove(model.id);
                              });
                            },
                          ),
                        ],
                      )
                    : ElevatedButton(
                        child: Text('Download'),
                        onPressed: () {
                          _downloadManager.downloadModel(
                            model: model,
                            onProgressUpdate: (progress) {
                              setState(() {
                                _downloadProgress[model.id] = progress;
                              });
                            },
                            onComplete: (success, error) {
                              if (success) {
                                setState(() {
                                  _downloadProgress.remove(model.id);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Download complete!')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Download failed: $error')),
                                );
                              }
                            },
                          );
                        },
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
```

### 6. Create a ChatScreen Using the Downloaded Model

```dart
class ChatScreen extends StatefulWidget {
  final String modelId;
  
  ChatScreen({required this.modelId});
  
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final LlamaCppService _llamaService = LlamaCppService();
  final TextEditingController _textController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isGenerating = false;
  
  @override
  void initState() {
    super.initState();
    _initializeModel();
  }
  
  Future<void> _initializeModel() async {
    await _llamaService.initialize();
    final success = await _llamaService.loadModel(widget.modelId);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load model')),
      );
      Navigator.pop(context);
    }
  }
  
  // Implement the chat UI and text generation logic
}
```

## Key Technical Considerations

1. **FFI for llama.cpp**: Properly set up Flutter Foreign Function Interface (FFI) to communicate with the C++ code of llama.cpp.

2. **Model Storage**: Store downloaded models in a persistent location that won't be cleared during app updates:
   ```dart
   final appDir = await getApplicationDocumentsDirectory();
   final modelsDir = Directory('${appDir.path}/models');
   ```

3. **Handle Large Downloads**:
   - Support download resumption
   - Show notifications during downloads
   - Allow background downloading

4. **Optimize Memory Usage**:
   - Only load models when needed
   - Consider model unloading when switching models

5. **Platform-Specific Considerations**:
   - iOS has restrictions on background downloads
   - Android requires appropriate foreground services

6. **Error Handling**:
   - Network failures during download
   - Storage space issues
   - Model loading failures

By implementing this architecture, your Flutter app can efficiently manage GGUF models without bundling them with the app installation, similar to the approach used by Google AI Edge Gallery.


model i want to download is gemma-3n-E2B-it-UD-IQ2_XXS.gguf
https://huggingface.co/unsloth/gemma-3n-E2B-it-UD-IQ2_XXS/resolve/main/gemma-3n-E2B-it-UD-IQ2_XXS.gguf?download=true