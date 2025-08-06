import 'package:flutter/material.dart';
import '../models/ai_model.dart';
import '../models/model_repository.dart';
import '../services/model_download_manager.dart';
import '../consolidated_gemma_service.dart';
import '../chat_screen.dart';

class ModelDownloadScreen extends StatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  final ModelDownloadManager _downloadManager = ModelDownloadManager();
  final Map<String, DownloadProgress> _downloadProgress = {};
  final Map<String, bool> _downloadedStatus = {};

  @override
  void initState() {
    super.initState();
    _initializeDownloadStatus();
    _listenToDownloadProgress();
  }

  Future<void> _initializeDownloadStatus() async {
    for (final model in ModelRepository.getAllModels()) {
      final isDownloaded = await _downloadManager.isModelDownloaded(model.id);
      if (mounted) {
        setState(() {
          _downloadedStatus[model.id] = isDownloaded;
        });
      }
    }
  }

  void _listenToDownloadProgress() {
    _downloadManager.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _downloadProgress[_getModelIdFromProgress(progress)] = progress;
          
          // Update download status when completed
          if (progress.status == DownloadStatus.completed) {
            _downloadedStatus[_getModelIdFromProgress(progress)] = true;
          }
        });
      }
    });
  }

  String _getModelIdFromProgress(DownloadProgress progress) {
    // Find model ID by matching the model name
    for (final model in ModelRepository.getAllModels()) {
      if (model.name == progress.modelName) {
        return model.id;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download AI Models'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a model to download',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Models are downloaded once and cached locally',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: ModelRepository.getAllModels().length,
              itemBuilder: (context, index) {
                final model = ModelRepository.getAllModels()[index];
                final isDownloaded = _downloadedStatus[model.id] ?? false;
                final progress = _downloadProgress[model.id];
                
                return _buildModelCard(model, isDownloaded, progress);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(AIModel model, bool isDownloaded, DownloadProgress? progress) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    model.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isDownloaded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Text(
                      'Downloaded',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              model.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.storage_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '${model.sizeInGB} GB',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildActionButton(model, isDownloaded, progress),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(AIModel model, bool isDownloaded, DownloadProgress? progress) {
    if (isDownloaded) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _navigateToChat(model),
          icon: const Icon(Icons.chat_rounded),
          label: const Text('Start Chatting'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      );
    }

    if (progress != null) {
      return _buildDownloadProgress(model, progress);
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _startDownload(model),
        icon: const Icon(Icons.download_rounded),
        label: const Text('Download'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          foregroundColor: Theme.of(context).colorScheme.onSecondary,
        ),
      ),
    );
  }

  Widget _buildDownloadProgress(AIModel model, DownloadProgress progress) {
    switch (progress.status) {
      case DownloadStatus.starting:
        return Column(
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text('Preparing download...', style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      
      case DownloadStatus.downloading:
        return Column(
          children: [
            LinearProgressIndicator(value: progress.progress),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.progressPercentage}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${progress.downloadedMB} / ${progress.totalMB} MB',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _cancelDownload(model),
                icon: const Icon(Icons.cancel_rounded),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        );
      
      case DownloadStatus.failed:
        return Column(
          children: [
            Text(
              'Download failed: ${progress.error ?? "Unknown error"}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startDownload(model),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
          ],
        );
      
      case DownloadStatus.cancelled:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _startDownload(model),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download'),
          ),
        );
      
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _startDownload(AIModel model) async {
    // Show confirmation dialog for large downloads
    if (model.sizeInBytes > 1000000000) { // > 1GB
      final confirmed = await _showDownloadConfirmation(model);
      if (!confirmed) return;
    }

    await _downloadManager.downloadModel(model.id);
  }

  Future<bool> _showDownloadConfirmation(AIModel model) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Large Download'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This model is ${model.sizeInGB} GB in size.'),
            const SizedBox(height: 8),
            const Text('Please ensure you have:'),
            const Text('• Stable internet connection'),
            const Text('• Sufficient storage space'),
            const Text('• WiFi connection recommended'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _cancelDownload(AIModel model) {
    _downloadManager.cancelDownload(model.id);
    setState(() {
      _downloadProgress.remove(model.id);
    });
  }

  void _navigateToChat(AIModel model) async {
    // Set the current model in the service
    final success = await ConsolidatedGemmaService.setCurrentModel(model.id);
    if (success) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to set model. Please try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    // Don't dispose the download manager here as it's a singleton
    super.dispose();
  }
}
