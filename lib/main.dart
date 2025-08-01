import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'consolidated_gemma_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("Starting Gemma Flutter application");
  
  // We're now using native mode by default, which uses the actual GGUF model
  // Native mode is set in the ConsolidatedGemmaService class
  // If you need mock mode for testing, uncomment this line:
  // ConsolidatedGemmaService.setMockMode(true);
  
  // Pre-initialize the model in the background with status updates
  print("Starting model initialization in the background...");
  print("NOTE: Loading large models may take several minutes on first run");
  
  ConsolidatedGemmaService.initModel().then((success) {
    print("Background model initialization ${success ? 'succeeded' : 'failed'}");
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const ChatScreen(),
    );
  }
}
