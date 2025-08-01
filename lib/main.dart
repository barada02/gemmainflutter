import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'consolidated_gemma_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("Starting Gemma Flutter application");
  
  // By default, the application runs in mock mode
  // Uncomment the line below to use native implementation with actual GGUF model
  // ConsolidatedGemmaService.setMockMode(false);
  
  // Pre-initialize the model in the background
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
