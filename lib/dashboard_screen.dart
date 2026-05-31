import 'dart:io';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'part_model.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  const DashboardScreen({super.key, required this.onSignOut});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  final List<AgentResponse> _chatHistory = [];
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _queryController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submitAgentQuery() async {
    final String queryText = _queryController.text.trim();
    if (queryText.isEmpty) return;

    _queryController.clear();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> rawEnvelope = await _apiService.searchCatalog(queryText);
      
      setState(() {
        _chatHistory.add(AgentResponse.fromJson(queryText, rawEnvelope));
      });
      _scrollToBottom();
    } on HttpException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to fetch agent resolution data.');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _submitVote(AgentResponse targetResponse, int preferenceChoice) async {
    if (targetResponse.selectedPreference != 0) return;

    setState(() {
      targetResponse.selectedPreference = preferenceChoice;
    });

    final preferredId = preferenceChoice == 1 ? targetResponse.kbAId : targetResponse.kbBId;
    final rejectedId = preferenceChoice == 1 ? targetResponse.kbBId : targetResponse.kbAId;

    final bool success = await _apiService.submitAgentFeedback(
      originalQuery: targetResponse.query,
      preferredKbId: preferredId,
      rejectedKbId: rejectedId,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network warning: Feedback telemetry failed to sync.')),
      );
    }
  }
  // Continues in Module 2...
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Sonalika Knowledge Agent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await _authService.signOut();
              widget.onSignOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _chatHistory.isEmpty && !_isProcessing
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _chatHistory.length,
                    itemBuilder: (context, index) {
                      return _buildChatBubble(_chatHistory[index]);
                    },
                  ),
          ),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_outlined, size: 64, color: Colors.blueGrey),
            SizedBox(height: 16),
            Text(
              'Ask anything about Sonalika Catalogues',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
            ),
            SizedBox(height: 8),
            Text(
              'Your prompt will resolve across available knowledge repositories securely.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
  // Continues in Module 3...
    Widget _buildChatBubble(AgentResponse response) {
    final bool hasVoted = response.selectedPreference != 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // User Query Bubble
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(left: 48, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A8A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Text(response.query, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),

        // Unified Knowledge Base Synthesized Card
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Synthesized Agent Response',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey),
                    ),
                  ],
                ),
                const Divider(height: 20),
                 // 💡 Swapped out plain Text for an enterprise-grade Markdown viewer
                MarkdownBody(
                  data: response.unifiedAnswer,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                    strong: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    listBullet: const TextStyle(color: Color(0xFF1E3A8A)),
                  ),
                ),
                const Divider(height: 24),
                
                // Interactive Feedback Component
                const Text(
                  'Which Knowledge Base provided better source context for this answer?',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasVoted ? null : () => _submitVote(response, 1),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: response.selectedPreference == 1 ? Colors.green : Colors.grey.shade100,
                          foregroundColor: response.selectedPreference == 1 ? Colors.white : Colors.black87,
                        ),
                        icon: const Icon(Icons.thumb_up_alt_outlined, size: 14),
                        label: Text(
                          response.selectedPreference == 1 ? 'Voted Base A' : 'Base Alpha',
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasVoted ? null : () => _submitVote(response, 2),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: response.selectedPreference == 2 ? Colors.green : Colors.grey.shade100,
                          foregroundColor: response.selectedPreference == 2 ? Colors.white : Colors.black87,
                        ),
                        icon: const Icon(Icons.thumb_up_alt_outlined, size: 14),
                        label: Text(
                          response.selectedPreference == 2 ? 'Voted Base B' : 'Base Beta',
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: 'Ask your technical engine question...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _submitAgentQuery(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF1E3A8A),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _submitAgentQuery,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
