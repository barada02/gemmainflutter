import 'ai_model.dart';

/// Repository containing available AI models
class ModelRepository {
  static const Map<String, AIModel> availableModels = {
    'gemma-3n-E2B-it-UD-IQ2_XXS': AIModel(
      id: 'gemma-3n-E2B-it-UD-IQ2_XXS',
      name: 'Gemma 3N E4B IT (Ultra Quantized)',
      url: 'https://huggingface.co/unsloth/gemma-3n-E4B-it-GGUF/resolve/main/gemma-3n-E4B-it-UD-IQ2_XXS.gguf?download=true',
      fileName: 'gemma-3n-E4B-it-UD-IQ2_XXS.gguf',
      sizeInBytes: 2831155200, // 2699.8MB = 2.7GB
      description: 'Ultra-quantized Gemma model optimized for mobile devices. Good balance of performance and size.',
    ),
    'gemma-2b-q4': AIModel(
      id: 'gemma-2b-q4',
      name: 'Gemma 2B Q4 (Alternative)',
      url: 'https://huggingface.co/lmstudio-community/gemma-2b-it-GGUF/resolve/main/gemma-2b-it-q4_0.gguf?download=true',
      fileName: 'gemma-2b-q4.gguf',
      sizeInBytes: 800000000, // Approximate 800MB
      description: 'Smaller Gemma model for faster inference on lower-end devices.',
    ),
  };

  static AIModel? getModel(String id) {
    return availableModels[id];
  }

  static List<AIModel> getAllModels() {
    return availableModels.values.toList();
  }

  static AIModel get defaultModel => availableModels['gemma-3n-E2B-it-UD-IQ2_XXS']!;
}
