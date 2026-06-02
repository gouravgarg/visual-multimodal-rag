import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $urlString');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final DateTime currentDateTime = DateTime.now();
        final String envVal = AppConfig.appEnvironment;
        final bool showEnv = envVal.toLowerCase() != 'production';
        final String style = AppConfig.aboutScreenStyle.toLowerCase();

        Widget dialogContent;
        if (style == 'minimalistseal') {
          dialogContent = _buildMinimalistSeal(context, showEnv, envVal, currentDateTime);
        } else if (style == 'cyberglow') {
          dialogContent = _buildCyberGlow(context, showEnv, envVal, currentDateTime);
        } else {
          dialogContent = _buildSapphirePlaque(context, showEnv, envVal, currentDateTime);
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          elevation: 0,
          child: dialogContent,
        );
      },
    );
  }

  Widget _buildSapphirePlaque(
    BuildContext context,
    bool showEnv,
    String envVal,
    DateTime currentDateTime,
  ) {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.04),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFD4AF37),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppConfig.appName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.1,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v${AppConfig.appVersion}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: const Color(0xFFD4AF37).withValues(alpha: 0.3), thickness: 1),
                  const SizedBox(height: 14),
                  if (showEnv) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFD4AF37),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.developer_mode_outlined,
                                color: Color(0xFFD4AF37),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                envVal.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD4AF37),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'PRODUCT OWNER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD4AF37),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gourav Garg',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => _launchURL('https://gouravgarg.co.uk'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.language,
                                  color: Color(0xFFD4AF37),
                                  size: 14,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'gouravgarg.co.uk',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFD4AF37),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Retrieved: ${currentDateTime.day}/${currentDateTime.month}/${currentDateTime.year} at ${currentDateTime.hour.toString().padLeft(2, '0')}:${currentDateTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Acknowledge & Close',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalistSeal(
    BuildContext context,
    bool showEnv,
    String envVal,
    DateTime currentDateTime,
  ) {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF1F5F9),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: const Text(
                'SP',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppConfig.appName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Release Version ${AppConfig.appVersion}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
            const SizedBox(height: 16),
            if (showEnv) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF0F172A),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  envVal.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'PRODUCT OWNER',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Gourav Garg',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _launchURL('https://gouravgarg.co.uk'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'gouravgarg.co.uk',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF0F172A),
                      size: 11,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCyberGlow(
    BuildContext context,
    bool showEnv,
    String envVal,
    DateTime currentDateTime,
  ) {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00F2FE),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F2FE).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFF4FACFE).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF00F2FE), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F2FE).withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bolt,
                      color: Color(0xFF00F2FE),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppConfig.appName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Color(0xFF00F2FE),
                          offset: Offset(0, 0),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ENGINE-SYS CORE V${AppConfig.appVersion}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00F2FE),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: const Color(0xFF00F2FE).withValues(alpha: 0.2), thickness: 1),
                  const SizedBox(height: 16),
                  if (showEnv) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.redAccent,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'UNRESTRICTED: ${envVal.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Courier',
                              color: Colors.redAccent,
                              letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF1E293B),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'PRODUCT OWNER',
                          style: TextStyle(
                            fontSize: 9,
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gourav Garg',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: () => _launchURL('https://gouravgarg.co.uk'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00F2FE).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.terminal,
                                  color: Color(0xFF090D16),
                                  size: 14,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'gouravgarg.co.uk',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF090D16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'NODE ACTIVE • ${DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ')}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontFamily: 'Courier',
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: const Color(0xFF00F2FE),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF00F2FE), width: 1.5),
                        ),
                      ),
                      child: const Text(
                        'DISMISS CONSOLE',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_user_outlined, color: Colors.green, size: 12),
                                const SizedBox(width: 4),
                                const Text(
                                  'Verified factual database record',
                                  style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
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
