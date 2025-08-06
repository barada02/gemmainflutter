import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'screens/model_download_screen.dart';
import 'screens/welcome_screen.dart';

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
      title: 'Gemma AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4285F4), // Google Blue
          brightness: Brightness.light,
        ).copyWith(
          secondary: const Color(0xFFEA4335), // Google Red
          tertiary: const Color(0xFF34A853), // Google Green
        ),
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4285F4), // Google Blue
          brightness: Brightness.dark,
        ).copyWith(
          secondary: const Color(0xFFEA4335), // Google Red
          tertiary: const Color(0xFF34A853), // Google Green
        ),
        fontFamily: 'Roboto',
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/download': (context) => const ModelDownloadScreen(),
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
