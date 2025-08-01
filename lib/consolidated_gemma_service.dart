import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'llama_helper.dart';

/// Main Gemma service that handles both native and mock implementations
class ConsolidatedGemmaService {
  // Configuration
  static const String MODEL_FILE_NAME = 'gemma-3n-E2B-it-UD-IQ2_XXS.gguf';
  static bool _useMockMode = false; // Set to false to use native implementation when ready
  
  // Shared state
  static final StreamController<String> _responseController = 
      StreamController<String>.broadcast();
  static Stream<String> get responseStream => _responseController.stream;
  
  // Native implementation variables
  static LlamaParent? _llamaParent;
  static final ChatHistory _chatHistory = ChatHistory();
  static bool _isFirstMessage = true;
  
  // Mock implementation variables
  static final Map<String, String> _mockResponses = {
    "hello": "Hello! How can I assist you today?",
    "hi": "Hi there! What can I help you with?",
    "who are you": "I'm Gemma, a lightweight language model designed to run on mobile devices.",
    "what can you do": "I can answer questions, provide information, and help with various tasks.",
    "help": "I'm here to assist you. Just ask any question or request information.",
  };
  
  /// Initialize and load the model
  static Future<bool> initModel() async {
    if (_useMockMode) {
      return _initMockMode();
    } else {
      return _initNativeMode();
    }
  }
  
  /// Initialize in mock mode (simulated responses)
  static Future<bool> _initMockMode() async {
    try {
      // Simulate model initialization
      await Future.delayed(Duration(seconds: 2));
      print("Model initialization simulated in mock mode");
      return true;
    } catch (e) {
      print("Error initializing mock model: $e");
      return false;
    }
  }
  
  /// Initialize in native mode (actual GGUF model)
  static Future<bool> _initNativeMode() async {
    try {
      // Set up the library path using our helper
      try {
        if (Platform.isAndroid) {
          // For Android, use the system path for FFI to find the native library
          Llama.libraryPath = await LlamaHelper.getNativeLibraryPath();
          print("Using Android FFI library lookup: ${Llama.libraryPath}");
        } else {
          // For other platforms, use our helper
          Llama.libraryPath = await LlamaHelper.getNativeLibraryPath();
          print("Using llama library at: ${Llama.libraryPath}");
        }
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
      
      // Setup parameters matching the reference implementation
      final contextParams = ContextParams();
      contextParams.nPredict = 8192;  // Maximum number of tokens to predict
      contextParams.nCtx = 8192;      // Context size
      contextParams.nBatch = 512;     // Batch size for prompt processing

      final samplerParams = SamplerParams();
      samplerParams.temp = 0.7;       // Temperature (higher = more creative, lower = more deterministic)
      samplerParams.topK = 64;        // Consider only top K tokens
      samplerParams.topP = 0.95;      // Nucleus sampling threshold
      samplerParams.penaltyRepeat = 1.1;  // Penalty for repeating tokens
      
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
      print("Error initializing native model: $e");
      return false;
    }
  }
  
  /// Set up listeners for the model responses (native mode)
  static void _setupStreamListeners() {
    // Listen for token stream
    _llamaParent!.stream.listen((token) {
      _responseController.add(token);
    }, onError: (e) {
      print("STREAM ERROR: $e");
      _responseController.addError(e);
    });
    
    // Listen for completion events
    _llamaParent!.completions.listen((event) {
      if (event.success) {
        print("Completion finished successfully for prompt: ${event.promptId}");
      } else {
        print("Completion failed for prompt: ${event.promptId}");
        _responseController.addError("Completion failed");
      }
    }, onError: (e) {
      print("COMPLETION ERROR: $e");
    });
  }
  
  /// Send a prompt to the model
  static Future<void> sendPrompt(String userInput) async {
    if (_useMockMode) {
      await _sendMockPrompt(userInput);
    } else {
      await _sendNativePrompt(userInput);
    }
  }
  
  /// Send a prompt in mock mode
  static Future<void> _sendMockPrompt(String userInput) async {
    try {
      String response;
      
      // Check for known responses or generate a generic one
      final lowerInput = userInput.toLowerCase().trim();
      if (_mockResponses.containsKey(lowerInput)) {
        response = _mockResponses[lowerInput]!;
      } else {
        response = "I understand you're asking about \"${userInput}\". " +
                  "This is a simulated response since the native model isn't fully set up yet. " +
                  "In the full implementation, you'd get a proper response generated by the Gemma model.";
      }
      
      // Stream the response with simulated typing delays
      List<String> words = response.split(' ');
      
      for (int i = 0; i < words.length; i++) {
        _responseController.add(words[i] + " ");
        // Random delay between words to simulate thinking/typing
        await Future.delayed(Duration(milliseconds: 50 + (30 * (i % 5))));
      }
    } catch (e) {
      print("Error generating mock response: $e");
      _responseController.addError("Error: $e");
    }
  }
  
  /// Send a prompt in native mode
  static Future<void> _sendNativePrompt(String userInput) async {
    if (_llamaParent == null || _llamaParent!.status != LlamaStatus.ready) {
      _responseController.addError("Model not ready");
      return;
    }
    
    try {
      // Initialize chat history with system prompt if it's the first message
      if (_isFirstMessage) {
        _chatHistory.addMessage(
          role: Role.system,
          content: "You are a helpful, concise assistant. Keep your answers informative but brief.",
        );
        _isFirstMessage = false;
      }
      
      // Add user message to history
      _chatHistory.addMessage(role: Role.user, content: userInput);
      
      // Add empty assistant message that will be filled as tokens arrive
      _chatHistory.addMessage(role: Role.assistant, content: "");
      
      // Prepare prompt for the model using Gemini format
      String prompt = _chatHistory.exportFormat(
        ChatFormat.gemini, 
        leaveLastAssistantOpen: true
      );
      
      print("Sending prompt to model...");
      
      // Send the prompt to the model
      await _llamaParent!.sendPrompt(prompt);
    } catch (e) {
      print("Error sending native prompt: $e");
      _responseController.addError("Error: $e");
    }
  }
  
  /// Extract the model from assets to a readable location
  static Future<String> _getModelPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final modelFile = File('${directory.path}/$MODEL_FILE_NAME');
      
      if (!await modelFile.exists()) {
        print("Copying model from assets to ${modelFile.path}");
        
        try {
          final data = await rootBundle.load('assets/$MODEL_FILE_NAME');
          await modelFile.writeAsBytes(data.buffer.asUint8List());
          print("Model copied successfully");
        } catch (e) {
          print("Error copying model from assets: $e");
          throw Exception("Failed to copy model file from assets: $e");
        }
      } else {
        print("Model already exists at ${modelFile.path}");
      }
      
      // Verify the file exists and is readable
      if (await modelFile.exists()) {
        // Check file size to make sure it's not empty
        final fileSize = await modelFile.length();
        print("Model file size: $fileSize bytes");
        
        if (fileSize == 0) {
          throw Exception("Model file exists but is empty");
        }
      } else {
        throw Exception("Model file doesn't exist after copy attempt");
      }
      
      return modelFile.path;
    } catch (e) {
      print("Error in _getModelPath: $e");
      rethrow;
    }
  }
  
  /// Set the mode - mock or native
  static void setMockMode(bool useMock) {
    _useMockMode = useMock;
    print("Set mode to: ${useMock ? 'MOCK' : 'NATIVE'}");
  }
  
  /// Dispose resources
  static void dispose() {
    _llamaParent?.dispose();
    _responseController.close();
  }
}
