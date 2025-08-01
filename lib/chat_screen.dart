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
      bool success = await ConsolidatedGemmaService.initModel();
      
      setState(() {
        _isModelInitialized = success;
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
              child: const CircleAvatar(child: Text('G')),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(15.0),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.blue[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Text(message.text),
            ),
          ),
          if (message.isUser)
            Container(
              margin: const EdgeInsets.only(left: 16.0),
              child: const CircleAvatar(child: Text('U')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _messages.isEmpty) {
      return const LoadingScreen();
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemma Chat'),
      ),
      body: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    reverse: false,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageItem(_messages[index]);
                    },
                  ),
                ),
                if (_isLoading && _messages.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: LinearProgressIndicator(),
                  ),
                const Divider(height: 1.0),
                Container(
                  decoration: BoxDecoration(color: Theme.of(context).cardColor),
                  child: _buildTextComposer(),
                ),
              ],
            ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _isModelInitialized && !_isLoading ? _handleSubmitted : null,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Send a message',
                ),
                enabled: _isModelInitialized && !_isLoading,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isModelInitialized && !_isLoading
                    ? () => _handleSubmitted(_textController.text)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    ConsolidatedGemmaService.dispose();
    super.dispose();
  }
}
