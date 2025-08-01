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
1. The GGUF model file should be placed in the `assets` folder:
   - Make sure `gemma-3n-E2B-it-UD-IQ2_XXS.gguf` is in the assets folder
   - Update the model name in `GemmaService.dart` if you're using a different model

### Running the App
1. Make sure all required libraries and model files are in place
2. Run `flutter pub get` to get dependencies
3. Run the app with `flutter run`

## Application Structure
- `main.dart`: Entry point of the application
- `chat_screen.dart`: UI for interacting with the model
- `gemma_service.dart`: Service for initializing and interacting with the Gemma model
- `llama_helper.dart`: Helper for loading native libraries
- `loading_screen.dart`: Loading screen during model initialization

## Features
- Chat interface for interacting with the Gemma model
- Streaming responses as they are generated
- Support for multiple platforms

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
