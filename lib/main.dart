import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'screens/model_download_screen.dart';
import 'consolidated_gemma_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Starting Gemma Flutter application
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AppFlowManager(),
    );
  }
}

/// Manages the app flow - shows download screen or chat screen based on model availability
class AppFlowManager extends StatefulWidget {
  const AppFlowManager({super.key});

  @override
  State<AppFlowManager> createState() => _AppFlowManagerState();
}

class _AppFlowManagerState extends State<AppFlowManager> {
  bool _isCheckingModel = true;
  bool _hasDownloadedModel = false;

  @override
  void initState() {
    super.initState();
    _checkModelAvailability();
  }

  Future<void> _checkModelAvailability() async {
    try {
      // Check if any model is ready
      final isReady = await ConsolidatedGemmaService.isCurrentModelReady();
      
      if (mounted) {
        setState(() {
          _hasDownloadedModel = isReady;
          _isCheckingModel = false;
        });
      }
    } catch (e) {
      // Error checking model availability: $e
      if (mounted) {
        setState(() {
          _hasDownloadedModel = false;
          _isCheckingModel = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingModel) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Checking models...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    // If no model is downloaded, show download screen
    if (!_hasDownloadedModel) {
      return const ModelDownloadScreen();
    }

    // If model is available, show chat screen
    return const ChatScreen();
  }
}
