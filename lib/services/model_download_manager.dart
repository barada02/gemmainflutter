import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_model.dart';
import '../models/model_repository.dart';

/// Manages downloading and caching of AI models
class ModelDownloadManager {
  static final ModelDownloadManager _instance = ModelDownloadManager._internal();
  factory ModelDownloadManager() => _instance;
  ModelDownloadManager._internal();

  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};
  
  // Stream controllers for download progress
  final StreamController<DownloadProgress> _progressController = 
      StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  /// Get the directory where models are stored
  Future<String> get _modelsDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  /// Check if a model is already downloaded and verified
  Future<bool> isModelDownloaded(String modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMarkedDownloaded = prefs.getBool('model_downloaded_$modelId') ?? false;
      
      if (!isMarkedDownloaded) return false;
      
      // Verify the file actually exists and has correct size
      final modelsDir = await _modelsDirectory;
      final model = ModelRepository.getModel(modelId);
      if (model == null) return false;
      
      final file = File('$modelsDir/${model.fileName}');
      if (!await file.exists()) {
        // File doesn't exist, update preferences
        await prefs.setBool('model_downloaded_$modelId', false);
        return false;
      }
      
      final fileSize = await file.length();
      // Allow 5% tolerance for file size differences
      final expectedSize = model.sizeInBytes;
      final sizeDiff = (fileSize - expectedSize).abs();
      final tolerance = expectedSize * 0.05;
      
      if (sizeDiff > tolerance) {
        // Model file size mismatch - delete corrupted file
        // Expected: $expectedSize, Got: $fileSize
        // File is corrupted or incomplete, delete it
        await file.delete();
        await prefs.setBool('model_downloaded_$modelId', false);
        return false;
      }
      
      return true;
    } catch (e) {
      // Error checking model download status: $e
      return false;
    }
  }

  /// Get the full path to a downloaded model file
  Future<String?> getModelPath(String modelId) async {
    if (!await isModelDownloaded(modelId)) return null;
    
    final model = ModelRepository.getModel(modelId);
    if (model == null) return null;
    
    final modelsDir = await _modelsDirectory;
    return '$modelsDir/${model.fileName}';
  }

  /// Download a model with progress tracking
  Future<bool> downloadModel(String modelId) async {
    final model = ModelRepository.getModel(modelId);
    if (model == null) {
      _progressController.add(DownloadProgress(
        status: DownloadStatus.failed,
        progress: 0.0,
        downloadedBytes: 0,
        totalBytes: 0,
        modelName: 'Unknown',
        error: 'Model not found',
      ));
      return false;
    }

    try {
      final modelsDir = await _modelsDirectory;
      final filePath = '$modelsDir/${model.fileName}';
      final file = File(filePath);
      
      // Create cancel token for this download
      final cancelToken = CancelToken();
      _cancelTokens[modelId] = cancelToken;

      // Check available storage space
      if (!await _checkStorageSpace(model.sizeInBytes)) {
        _progressController.add(DownloadProgress(
          status: DownloadStatus.failed,
          progress: 0.0,
          downloadedBytes: 0,
          totalBytes: model.sizeInBytes,
          modelName: model.name,
          error: 'Insufficient storage space',
        ));
        return false;
      }

      _progressController.add(DownloadProgress(
        status: DownloadStatus.starting,
        progress: 0.0,
        downloadedBytes: 0,
        totalBytes: model.sizeInBytes,
        modelName: model.name,
      ));

      // Check if file is partially downloaded (resume support)
      int startByte = 0;
      if (await file.exists()) {
        startByte = await file.length();
        // Resuming download from byte $startByte
      }

      // Configure dio for the download
      final options = Options(
        headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
        receiveTimeout: Duration(minutes: 30), // 30 minute timeout
      );

      _progressController.add(DownloadProgress(
        status: DownloadStatus.downloading,
        progress: (startByte / model.sizeInBytes).clamp(0.0, 1.0),
        downloadedBytes: startByte,
        totalBytes: model.sizeInBytes,
        modelName: model.name,
      ));

      await _dio.download(
        model.url,
        filePath,
        options: options,
        cancelToken: cancelToken,
        deleteOnError: false,
        onReceiveProgress: (received, total) {
          final totalReceived = startByte + received;
          final totalSize = startByte + (total > 0 ? total : model.sizeInBytes - startByte);
          final progress = totalReceived / totalSize;

          _progressController.add(DownloadProgress(
            status: DownloadStatus.downloading,
            progress: progress.clamp(0.0, 1.0),
            downloadedBytes: totalReceived,
            totalBytes: totalSize,
            modelName: model.name,
          ));
        },
      );

      // Verify download completion
      if (await file.exists()) {
        final fileSize = await file.length();
        // Download completed. File size: $fileSize bytes
        
        // Mark as downloaded in preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('model_downloaded_$modelId', true);
        
        _progressController.add(DownloadProgress(
          status: DownloadStatus.completed,
          progress: 1.0,
          downloadedBytes: fileSize,
          totalBytes: fileSize,
          modelName: model.name,
        ));

        // Clean up cancel token
        _cancelTokens.remove(modelId);
        return true;
      } else {
        throw Exception('Download completed but file not found');
      }
    } catch (e) {
      // Download error: $e
      
      // Clean up cancel token
      _cancelTokens.remove(modelId);
      
      // Determine error type
      String errorMessage;
      DownloadStatus status;
      
      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) {
          errorMessage = 'Download cancelled';
          status = DownloadStatus.cancelled;
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Connection timeout';
          status = DownloadStatus.failed;
        } else {
          errorMessage = 'Network error: ${e.message}';
          status = DownloadStatus.failed;
        }
      } else {
        errorMessage = e.toString();
        status = DownloadStatus.failed;
      }

      _progressController.add(DownloadProgress(
        status: status,
        progress: 0.0,
        downloadedBytes: 0,
        totalBytes: model.sizeInBytes,
        modelName: model.name,
        error: errorMessage,
      ));

      return false;
    }
  }

  /// Cancel an ongoing download
  Future<void> cancelDownload(String modelId) async {
    final cancelToken = _cancelTokens[modelId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('User cancelled');
      _cancelTokens.remove(modelId);
    }
  }

  /// Delete a downloaded model
  Future<bool> deleteModel(String modelId) async {
    try {
      final modelPath = await getModelPath(modelId);
      if (modelPath != null) {
        final file = File(modelPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      // Update preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('model_downloaded_$modelId', false);
      
      return true;
    } catch (e) {
      // Error deleting model: $e
      return false;
    }
  }

  /// Check if there's enough storage space for the download
  Future<bool> _checkStorageSpace(int requiredBytes) async {
    try {
      // This is a simplified check - in a real app you'd want more robust storage checking
      final modelsDir = await _modelsDirectory;
      final directory = Directory(modelsDir);
      
      // For now, just check if the directory is accessible
      // In production, you'd want to check actual available space
      return await directory.exists() || await directory.create(recursive: true).then((_) => true);
    } catch (e) {
      // Error checking storage space: $e
      return false;
    }
  }

  /// Get download progress for a specific model
  Stream<DownloadProgress> getModelProgress(String modelId) {
    return progressStream.where((progress) => 
        ModelRepository.getModel(modelId)?.name == progress.modelName);
  }

  /// Dispose resources
  void dispose() {
    // Cancel all ongoing downloads
    for (final cancelToken in _cancelTokens.values) {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('Service disposed');
      }
    }
    _cancelTokens.clear();
    _progressController.close();
  }
}
