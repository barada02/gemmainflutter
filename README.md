# Gemma in Flutter

A Flutter application that integrates the Gemma LLM model using llama_cpp_dart.

## Setup Instructions

### Prerequisites
- Flutter SDK installed
- Android Studio or VS Code with Flutter extension
- llama_cpp_dart package
- Native libraries for your platform

### Native Libraries Setup

#### For Android (Primary Target):
1. Place `libllama.so` in these directories based on architecture:
   - For 64-bit ARM devices (most modern phones):
     `android/app/src/main/jniLibs/arm64-v8a/libllama.so`
   - For 32-bit ARM devices (older phones):
     `android/app/src/main/jniLibs/armeabi-v7a/libllama.so`

#### For Other Platforms (If Needed Later):
1. For Windows:
   - Place `llama.dll` in `assets/libs/windows/` folder

2. For macOS:
   - Place `libllama.dylib` in `assets/libs/macos/` folder

3. For Linux:
   - Place `libllama.so` in `assets/libs/linux/` folder

### Model Setup
1. Models are downloaded automatically after installation:
   - The app will download the GGUF model file from HuggingFace when needed
   - Models are stored in the app's documents directory for persistent access
   - No need to bundle large model files with the app installation
   - Available models are defined in `ModelRepository` class

### Running the App
1. Make sure native libraries are placed in the correct platform folders
2. Run `flutter pub get` to install dependencies
3. Run the app with `flutter run`
4. On first launch, use the welcome screen to navigate to model download
5. Select and download your preferred Gemma model (2.7GB download)
6. Start chatting once the model is ready!

## User Flow
1. **Welcome Screen**: Introduction to the app with animated features overview
2. **Model Download**: Select from available Gemma models and download with progress tracking
3. **Chat Interface**: Real-time conversation with streaming AI responses
4. **Model Management**: Switch between models or re-download if needed

## Application Structure
- `main.dart`: Entry point with Material Design 3 theming and navigation
- `screens/welcome_screen.dart`: Animated onboarding screen with app introduction
- `screens/model_download_screen.dart`: Model selection and download management UI
- `chat_screen.dart`: Real-time chat interface with streaming AI responses
- `consolidated_gemma_service.dart`: Main AI service with dual-mode operation (native/mock)
- `services/model_download_manager.dart`: Robust download system with progress tracking and resume support
- `models/ai_model.dart` & `model_repository.dart`: Model data structures and available model definitions
- `llama_helper.dart`: Cross-platform native library path management
- `loading_screen.dart`: Loading feedback during model initialization

## Features
- **Offline AI Chat**: Run Gemma models completely offline on your device
- **Smart Download System**: Post-installation model downloads with resume support
- **Privacy First**: All conversations and models stay on your device
- **Streaming Responses**: Real-time token-by-token response generation
- **Modern UI**: Material Design 3 with Google's color scheme and smooth animations
- **Cross-Platform**: Native library support for Android, iOS, Windows, macOS, and Linux
- **Dual-Mode Operation**: Native LLM inference with mock mode fallback
- **Progress Tracking**: Detailed download progress with bandwidth monitoring
- **Model Management**: Easy model selection and storage management

## Technical Architecture

### Implementation Modes
The application supports two operating modes for robust development and deployment:

1. **Native Mode** (Production): Uses the full GGUF model with `llama_cpp_dart` for actual AI inference
   - Real Gemma model responses
   - Requires native libraries compilation
   - Full offline AI capabilities

2. **Mock Mode** (Development/Fallback): Simulates AI responses for testing and development
   - Predefined response patterns
   - No native dependencies required
   - Perfect for UI testing and development

### Download System Architecture
- **Progressive Downloads**: Large models downloaded after installation to keep app size small
- **Resume Support**: Interrupted downloads automatically resume from where they left off
- **Verification**: File integrity checks and corruption detection
- **Storage Management**: Efficient local storage in app documents directory
- **Progress Tracking**: Real-time download progress with speed and ETA calculations

To switch between modes:
```dart
// Set to true for development/testing
ConsolidatedGemmaService.setMockMode(true);
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Current Status 

✅ **App Architecture**: Complete with modern Material Design 3 UI  
✅ **Download System**: Robust model downloading with progress tracking and resume support  
✅ **Mock Mode**: Fully functional for development and testing  
✅ **Cross-Platform UI**: Responsive design working across all platforms  
⚠️ **Native Mode**: Build issues with `llama_cpp_dart` CMake configuration  
🔄 **Active Development**: Currently working on resolving native library compilation issues  

### Known Issues
- CMake build failure in `llama_cpp_dart` dependency (missing llama.cpp submodule)
- Native library compilation requires proper NDK setup for Android
- App currently defaults to mock mode as fallback

### Troubleshooting
If you encounter build issues:
1. Enable mock mode in `ConsolidatedGemmaService.setMockMode(true)` for testing
2. Ensure Android NDK is properly installed and configured
3. Check that all native libraries are placed in correct platform folders
4. Use `flutter clean` and rebuild if experiencing cache issues