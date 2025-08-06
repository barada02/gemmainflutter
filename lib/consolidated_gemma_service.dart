import 'dart:async';
import 'dart:io';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'llama_helper.dart';
import 'services/model_download_manager.dart';

/// Main Gemma service that handles both native and mock implementations
class ConsolidatedGemmaService {
  // Configuration
  static String _currentModelId = 'gemma-3n-E2B-it-UD-IQ2_XXS'; // Default model
  static bool _useMockMode = false; // Native mode is now the default
  static final ModelDownloadManager _downloadManager = ModelDownloadManager();
  
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
      // Check if model is downloaded
      if (!await _downloadManager.isModelDownloaded(_currentModelId)) {
        print("Model $_currentModelId not found. Please download it first.");
        return false;
      }

      // Set up the library path using our helper
      try {
        if (Platform.isAndroid) {
          Llama.libraryPath = await LlamaHelper.getNativeLibraryPath();
          print("Using Android FFI library lookup: ${Llama.libraryPath}");
        } else {
          Llama.libraryPath = await LlamaHelper.getNativeLibraryPath();
          print("Using llama library at: ${Llama.libraryPath}");
        }
      } catch (e) {
        print("Failed to get library path: $e");
        if (Platform.isAndroid) {
          Llama.libraryPath = "libllama.so";
        } else if (Platform.isWindows) {
          Llama.libraryPath = "llama.dll";
        } else {
          Llama.libraryPath = "libllama.dylib";
        }
      }
      
      // Get model path from downloaded file
      final modelPath = await _downloadManager.getModelPath(_currentModelId);
      if (modelPath == null) {
        print("Could not get path for downloaded model $_currentModelId");
        return false;
      }
      
      print("Using downloaded model at: $modelPath");
      
      // Setup parameters with reduced values for better performance on mobile
      final contextParams = ContextParams();
      contextParams.nPredict = 4096;  // Reduced max tokens to predict (was 8192)
      contextParams.nCtx = 2048;      // Reduced context size (was 8192)
      contextParams.nBatch = 256;     // Reduced batch size (was 512)

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
      
      // Add a timeout to prevent infinite waiting - increased for larger models
      int attempts = 0;
      const maxAttempts = 120; // Increased from 60 to 120
      
      print("Waiting for model to be ready...");
      print("This may take several minutes for large models. Please be patient.");
      while (_llamaParent!.status != LlamaStatus.ready && attempts < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 1000)); // Increased from 500ms to 1000ms
        attempts++;
        
        if (attempts % 10 == 0) {
          print("Still waiting... Status: ${_llamaParent!.status}, attempt $attempts/$maxAttempts");
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
    try {
      if (_useMockMode) {
        await _sendMockPrompt(userInput);
      } else {
        await _sendNativePrompt(userInput);
      }
    } catch (e) {
      print("Error in sendPrompt: $e");
      _responseController.addError("Failed to process prompt: $e");
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
        response = "I understand you're asking about \"$userInput\". " "This is a simulated response since the native model isn't fully set up yet. " +
                  "In the full implementation, you'd get a proper response generated by the Gemma model.";
      }
      
      // Stream the response with simulated typing delays
      List<String> words = response.split(' ');
      
      for (int i = 0; i < words.length; i++) {
        _responseController.add("${words[i]} ");
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
  
  /// Set the current model to use
  static Future<bool> setCurrentModel(String modelId) async {
    if (!await _downloadManager.isModelDownloaded(modelId)) {
      print("Model $modelId is not downloaded");
      return false;
    }
    _currentModelId = modelId;
    print("Set current model to: $modelId");
    return true;
  }

  /// Get the current model ID
  static String getCurrentModelId() => _currentModelId;

  /// Check if the current model is ready
  static Future<bool> isCurrentModelReady() async {
    return await _downloadManager.isModelDownloaded(_currentModelId);
  }

  /// Get download manager instance
  static ModelDownloadManager get downloadManager => _downloadManager;  /// Set the mode - mock or native
  static void setMockMode(bool useMock) {
    _useMockMode = useMock;
    print("Set mode to: ${useMock ? 'MOCK' : 'NATIVE'}");
  }
  
  /// Dispose resources
  static void dispose() {
    _llamaParent?.dispose();
    _responseController.close();
    _downloadManager.dispose();
  }
}
