import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'api_service.dart';
import 'app_config.dart';
import 'auth_service.dart';
import 'part_model.dart';

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
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserEmail() async {
    final String? userEmail = await _authService.getCurrentUserEmail();
    if (!mounted) return;

    setState(() {
      _userEmail = userEmail;
    });
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

  Future<void> _submitFeedback(AgentResponse targetResponse, bool isHelpful) async {
    if (targetResponse.selectedFeedback != 0) return;

    setState(() {
      targetResponse.selectedFeedback = isHelpful ? 1 : 2;
    });

    final bool success = await _apiService.submitAgentFeedback(
      originalQuery: targetResponse.query,
      isHelpful: isHelpful,
      kbAId: targetResponse.kbAId,
      kbBId: targetResponse.kbBId,
      kbAHasData: targetResponse.kbAHasData,
      kbBHasData: targetResponse.kbBHasData,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network warning: Feedback telemetry failed to sync.')),
      );
    }
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final DateTime currentDateTime = DateTime.now();

        return AlertDialog(
          title: const Text('About'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('App name: ${AppConfig.appName}'),
              const SizedBox(height: 8),
              Text('Version: ${AppConfig.appVersion}'),
              const SizedBox(height: 8),
              Text('Date & time: $currentDateTime'),
              const SizedBox(height: 8),
              Text('Environment: ${AppConfig.appEnvironment}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
// Continued in Module 2...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(AppConfig.appName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
          ),
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
    final String greetingName = (_userEmail == null || _userEmail!.isEmpty)
        ? 'there'
        : _userEmail!;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF05070D),
            Color(0xFF111827),
            Color(0xFF1E3A8A),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, size: 44, color: Colors.amber),
              const SizedBox(height: 24),
              Text(
                'Hi $greetingName,\nWhat do you need?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 34,
                  height: 1.18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppConfig.emptyStateSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFC7D2FE),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
// Continued in Module 3...
  Widget _buildChatBubble(AgentResponse response) {
    final bool hasSubmittedFeedback = response.selectedFeedback != 0;

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Synthesized Response',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                    
                    // Dynamic visual badges showing true data origin
                    Row(
                      children: [
                        if (response.kbAHasData)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                            child: const Text('α Alpha', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                          ),
                        if (response.kbBHasData)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4)),
                            child: const Text('β Beta', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                          ),
                          // 💡 New Pill: Displays when BOTH KBs are false, indicating a master database hit
                        if (!response.kbAHasData && !response.kbBHasData)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                            child: const Text('🗄️ DB Master', style: TextStyle(fontSize: 10, color: Color(0xFFE65100), fontWeight: FontWeight.bold)),
                          ),
                      ],
                    )
                  ],
                ),
                const Divider(height: 20),
                MarkdownBody(
                  selectable: true,
                  data: response.unifiedAnswer,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                    strong: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    listBullet: const TextStyle(color: Color(0xFF1E3A8A)),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSourceAttribution(response),
                const Divider(height: 24),
                
                const Text(
                  'Was this answer helpful?',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasSubmittedFeedback ? null : () => _submitFeedback(response, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade200,
                          disabledForegroundColor: Colors.grey.shade500,
                        ),
                        icon: const Icon(Icons.thumb_up_alt_outlined, size: 14),
                        label: Text(
                          response.selectedFeedback == 1 ? 'Marked Helpful' : 'Helpful',
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasSubmittedFeedback ? null : () => _submitFeedback(response, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade200,
                          disabledForegroundColor: Colors.grey.shade500,
                        ),
                        icon: const Icon(Icons.thumb_down_alt_outlined, size: 14),
                        label: Text(
                          response.selectedFeedback == 2 ? 'Marked Not Helpful' : 'Not Helpful',
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!response.kbAHasData && !response.kbBHasData) ...[
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: Colors.green, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Verified factual database record.',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceAttribution(AgentResponse response) {
    final List<String> sources = [
      if (response.kbAHasData) 'Alpha',
      if (response.kbBHasData) 'Beta',
    ];

    return Row(
      children: [
        const Icon(Icons.source_outlined, size: 14, color: Colors.blueGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            sources.isEmpty ? 'Source: DB Master' : 'Source: ${sources.join(', ')}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blueGrey,
              fontWeight: FontWeight.w600,
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
                  hintText: AppConfig.queryHintText,
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
