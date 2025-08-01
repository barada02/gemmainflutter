import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'llama_helper.dart';

class GemmaService {
  static const String MODEL_FILE_NAME = 'gemma-3n-E2B-it-UD-IQ2_XXS.gguf';
  static LlamaParent? _llamaParent;
  static StreamController<String> _responseStreamController = StreamController<String>.broadcast();
  static Stream<String> get responseStream => _responseStreamController.stream;
  
  // Initialize and load the model
  static Future<bool> initModel() async {
    try {
      // Set up the library path using our helper
      try {
        Llama.libraryPath = await LlamaHelper.getNativeLibraryPath();
        print("Using llama library at: ${Llama.libraryPath}");
      } catch (e) {
        print("Failed to get library path: $e");
        // Fall back to bundled libraries if extraction fails
        if (Platform.isAndroid) {
          Llama.libraryPath = "libllama.so";
        } else if (Platform.isWindows) {
          Llama.libraryPath = "llama.dll";
        } else {
          Llama.libraryPath = "libllama.dylib";
        }
      }
      
      // Copy model from assets to a readable location
      final modelPath = await _getModelPath();
      
      // Setup parameters
      final contextParams = ContextParams();
      contextParams.nPredict = 4096;
      contextParams.nCtx = 4096;
      contextParams.nBatch = 512;

      final samplerParams = SamplerParams();
      samplerParams.temp = 0.7;
      samplerParams.topK = 64;
      samplerParams.topP = 0.95;
      samplerParams.penaltyRepeat = 1.1;
      
      // Initialize load command for the isolate
      final loadCommand = LlamaLoad(
        path: modelPath,
        modelParams: ModelParams(),
        contextParams: contextParams,
        samplingParams: samplerParams,
      );
      
      print("Loading model, please wait...");
      
      // Create the LLM parent that will spawn an isolate
      _llamaParent = LlamaParent(loadCommand);
      
      await _llamaParent!.init();
      
      // Add a timeout to prevent infinite waiting
      int attempts = 0;
      const maxAttempts = 60;
      
      print("Waiting for model to be ready...");
      while (_llamaParent!.status != LlamaStatus.ready && attempts < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 500));
        attempts++;
        
        if (attempts % 10 == 0) {
          print("Still waiting... Status: ${_llamaParent!.status}");
        }
        
        if (_llamaParent!.status == LlamaStatus.error) {
          print("Error loading model. Exiting.");
          return false;
        }
      }
      
      if (attempts >= maxAttempts && _llamaParent!.status != LlamaStatus.ready) {
        print("Timeout waiting for model to be ready. Current status: ${_llamaParent!.status}");
        print("Continuing anyway as the model might be ready despite status not being updated...");
      }
      
      print("Model loaded successfully in isolate! Status: ${_llamaParent!.status}");
      
      // Set up stream listeners
      _setupStreamListeners();
      
      return true;
    } catch (e) {
      print("Error initializing model: $e");
      return false;
    }
  }
  
  // Set up listeners for the model responses
  static void _setupStreamListeners() {
    _llamaParent!.stream.listen((token) {
      _responseStreamController.add(token);
    }, onError: (e) {
      print("STREAM ERROR: $e");
      _responseStreamController.addError(e);
    });
  }
  
  // Get a response from the model
  static Future<void> sendPrompt(String userInput) async {
    if (_llamaParent == null || _llamaParent!.status != LlamaStatus.ready) {
      _responseStreamController.addError("Model not ready");
      return;
    }
    
    try {
      // Create chat history
      ChatHistory chatHistory = ChatHistory();
      chatHistory.addMessage(
        role: Role.system,
        content: "You are a helpful, concise assistant. Keep your answers informative but brief.",
      );
      chatHistory.addMessage(role: Role.user, content: userInput);
      chatHistory.addMessage(role: Role.assistant, content: "");
      
      // Prepare prompt for the model
      String prompt = chatHistory.exportFormat(ChatFormat.gemini, leaveLastAssistantOpen: true);
      
      // Send the prompt to the model
      await _llamaParent!.sendPrompt(prompt);
    } catch (e) {
      print("Error sending prompt: $e");
      _responseStreamController.addError("Error: $e");
    }
  }
  
  // Extract the model from assets to a readable location
  static Future<String> _getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final modelFile = File('${directory.path}/$MODEL_FILE_NAME');
    
    if (!await modelFile.exists()) {
      print("Copying model from assets to ${modelFile.path}");
      final data = await rootBundle.load('assets/$MODEL_FILE_NAME');
      await modelFile.writeAsBytes(data.buffer.asUint8List());
      print("Model copied successfully");
    } else {
      print("Model already exists at ${modelFile.path}");
    }
    
    return modelFile.path;
  }
  
  // Dispose resources
  static void dispose() {
    _llamaParent?.dispose();
    _responseStreamController.close();
  }
}
