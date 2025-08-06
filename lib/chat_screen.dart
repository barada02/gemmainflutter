import 'package:flutter/material.dart';
import 'consolidated_gemma_service.dart';
import 'loading_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  
  ChatMessage({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isModelInitialized = false;
  String _currentResponse = '';

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print("Starting model initialization...");
      print("IMPORTANT: First run may take several minutes to copy and load the model");
      
      // Update UI with loading message
      setState(() {
        _messages.add(ChatMessage(
          text: "Initializing Gemma model... This may take several minutes on first run.",
          isUser: false,
        ));
      });
      
      bool success = await ConsolidatedGemmaService.initModel();
      
      setState(() {
        _isModelInitialized = success;
        
        // Update the initialization message
        if (_messages.isNotEmpty) {
          _messages[0] = ChatMessage(
            text: success 
                ? "Model initialized successfully! You can now ask questions."
                : "Model initialization failed. Please try restarting the app.",
            isUser: false,
          );
        }
      });
      
      if (success) {
        print("Model initialized successfully");
        // Listen to the stream for responses
        ConsolidatedGemmaService.responseStream.listen((token) {
          setState(() {
            // Add token to the current response
            _currentResponse += token;
            
            // Update the last message if it's from the assistant
            if (_messages.isNotEmpty && !_messages.last.isUser) {
              _messages.last = ChatMessage(text: _currentResponse, isUser: false);
            }
          });
        }, onError: (error) {
          print("Error from response stream: $error");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        });
      } else {
        print("Failed to initialize model");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize model')),
        );
      }
    } catch (e) {
      print("Exception during model initialization: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing model: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleSubmitted(String text) async {
    _textController.clear();
    
    if (text.trim().isEmpty) return;
    
    // Add user message to the chat
    ChatMessage userMessage = ChatMessage(
      text: text,
      isUser: true,
    );
    
    // Add empty assistant message (will be updated as tokens arrive)
    ChatMessage assistantMessage = ChatMessage(
      text: '',
      isUser: false,
    );
    
    setState(() {
      _messages.add(userMessage);
      _messages.add(assistantMessage);
      _currentResponse = '';
      _isLoading = true;
    });
    
    // Send the prompt to the model
    try {
      await ConsolidatedGemmaService.sendPrompt(text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending prompt: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildMessageItem(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) 
            Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundColor: const Color(0xFF4285F4), // Google Blue
                child: const Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(15.0),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? const Color(0xFF4285F4) // Google Blue for user messages
                    : const Color(0xFFF8F9FA), // Light gray for AI messages
                borderRadius: BorderRadius.circular(20.0),
                border: message.isUser 
                    ? null 
                    : Border.all(color: const Color(0xFFE8EAED)), // Light border for AI messages
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser 
                      ? Colors.white // White text for user messages
                      : const Color(0xFF202124), // Dark text for AI messages
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser)
            Container(
              margin: const EdgeInsets.only(left: 16.0),
              child: CircleAvatar(
                backgroundColor: const Color(0xFFEA4335), // Google Red
                child: const Text('U', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _messages.isEmpty) {
      return LoadingScreen(
        message: _isModelInitialized 
          ? "Model ready! You can start chatting." 
          : "Initializing model... This may take several minutes on first run.",
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemma AI Chat'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/download'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _currentResponse = '';
                _messages.add(ChatMessage(
                  text: "Chat reset. You can start a new conversation!",
                  isUser: false,
                ));
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/download');
            },
            tooltip: 'Manage Models',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFF8F9FA), // Light gray background
              const Color(0xFFFFFFFF), // White
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                reverse: false,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageItem(_messages[index]);
                },
              ),
            ),
            if (_isLoading && _messages.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: LinearProgressIndicator(
                  backgroundColor: const Color(0xFFE8EAED),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF4285F4), // Google Blue
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: const Color(0xFFE8EAED), width: 1),
                ),
              ),
              child: _buildTextComposer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: const Color(0xFFE8EAED)),
                color: const Color(0xFFF8F9FA),
              ),
              child: TextField(
                controller: _textController,
                onSubmitted: _isModelInitialized && !_isLoading ? _handleSubmitted : null,
                decoration: InputDecoration(
                  hintText: 'Send a message',
                  hintStyle: TextStyle(color: const Color(0xFF5F6368)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                ),
                style: TextStyle(
                  color: const Color(0xFF202124),
                  fontSize: 16,
                ),
                enabled: _isModelInitialized && !_isLoading,
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isModelInitialized && !_isLoading 
                  ? const Color(0xFF4285F4) // Google Blue
                  : const Color(0xFFE8EAED), // Disabled gray
            ),
            child: IconButton(
              icon: Icon(
                Icons.send,
                color: _isModelInitialized && !_isLoading 
                    ? Colors.white 
                    : const Color(0xFF5F6368),
              ),
              onPressed: _isModelInitialized && !_isLoading
                  ? () => _handleSubmitted(_textController.text)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ConsolidatedGemmaService.dispose();
    super.dispose();
  }
}
