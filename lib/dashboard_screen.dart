import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'app_config.dart';
import 'auth_service.dart';
import 'part_model.dart';
import 'image_compressor.dart';
import 'progressive_loading_widget.dart';
import 'search_history_service.dart';

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
  bool _isProcessingWithImage = false;
  bool _isCompressing = false;
  String? _errorMessage;
  String? _userEmail;
  final SearchHistoryService _searchHistoryService = SearchHistoryService();
  String? _lastQueryText;
  String? _lastSelectedModel;
  List<Uint8List>? _lastAttachedImages;

  final ImagePicker _imagePicker = ImagePicker();
  final List<Uint8List> _selectedImageBytes = [];
  final List<String> _selectedImageNames = [];

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isEmpty) return;

      setState(() {
        _isCompressing = true;
      });

      int invalidCount = 0;
      for (final image in images) {
        final String name = image.name.toLowerCase();
        final bool isValid =
            name.endsWith('.png') ||
            name.endsWith('.jpg') ||
            name.endsWith('.jpeg');

        if (isValid) {
          final Uint8List originalBytes = await image.readAsBytes();

          // Compresses the image on a separate isolate (or main thread on Web)
          final Uint8List compressedBytes = await ImageCompressor.compress(
            originalBytes: originalBytes,
            imageName: image.name,
          );

          if (mounted) {
            setState(() {
              _selectedImageBytes.add(compressedBytes);
              _selectedImageNames.add(image.name);
            });
          }
        } else {
          invalidCount++;
        }
      }

      if (mounted) {
        setState(() {
          _isCompressing = false;
        });
      }

      if (invalidCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              '$invalidCount files ignored. Only PNG, JPG, and JPEG images are allowed.',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCompressing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Error selecting images: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImageBytes.removeAt(index);
      _selectedImageNames.removeAt(index);
    });
  }

  void _showFullscreenImage(Uint8List imageBytes) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Dialog(
            backgroundColor: Colors.black.withValues(alpha: 0.9),
            insetPadding: EdgeInsets.zero,
            child: Stack(
              alignment: Alignment.center,
              children: [
                InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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

    if (userEmail != null && userEmail.trim().isNotEmpty) {
      final List<AgentResponse> history = await _searchHistoryService
          .getHistory(userEmail);
      if (mounted) {
        setState(() {
          _chatHistory.clear();
          _chatHistory.addAll(history);
        });
        _scrollToBottom();
      }
    }
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

  Future<String?> _showTradeModelSelectionDialog() async {
    final List<String> models = AppConfig.supportedTradeModels;
    if (models.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Configuration Error: No Trade Models are configured.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
      return null;
    }

    // If only one trade model is supported, use it directly without showing dialog
    if (models.length == 1) {
      return models.first;
    }

    String? selectedModel;

    await showDialog<void>(
      context: context,
      barrierDismissible: false, // Force explicit action
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
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
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.blueAccent,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.blueAccent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Trade Model',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a trade model to resolve your catalog query.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 20),
                    ...models.map((model) {
                      final bool isSelected = selectedModel == model;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedModel = model;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blueAccent.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blueAccent
                                  : Colors.white.withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? Colors.blueAccent
                                    : Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                model,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                              const Spacer(),
                              if (model == 'TIGER')
                                const Icon(
                                  Icons.bolt,
                                  color: Colors.amber,
                                  size: 18,
                                )
                              else if (model == 'RX')
                                const Icon(
                                  Icons.speed,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              selectedModel = null;
                              Navigator.of(dialogContext).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedModel == null
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.white12,
                              disabledForegroundColor: Colors.white30,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return selectedModel;
  }

  Future<void> _submitAgentQuery({
    String? retryQuery,
    String? retryModel,
    List<Uint8List>? retryImages,
  }) async {
    final String queryText = retryQuery ?? _queryController.text.trim();
    if (queryText.isEmpty && retryQuery == null) return;

    // 1. Prompt for Trade Model selection and validate choice before API invocation
    final String? selectedModel =
        retryModel ?? await _showTradeModelSelectionDialog();
    if (selectedModel == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Validation Error: A Trade Model must be selected before submitting a query.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
      setState(() {
        _errorMessage = 'Validation Error: A Trade Model must be selected.';
      });
      return;
    }

    final List<Uint8List> submittedBytes =
        retryImages ?? List.from(_selectedImageBytes);

    if (retryQuery == null) {
      _queryController.clear();
      setState(() {
        _selectedImageBytes.clear();
        _selectedImageNames.clear();
      });
    }

    setState(() {
      _isProcessing = true;
      _isProcessingWithImage = submittedBytes.isNotEmpty;
      _errorMessage = null;
      // Save last attempt parameters for retry UI
      _lastQueryText = queryText;
      _lastSelectedModel = selectedModel;
      _lastAttachedImages = submittedBytes;
    });

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final List<String> base64Images = submittedBytes
          .map((bytes) => base64Encode(bytes))
          .toList();

      // Prepends the selected Trade Model in uppercase format before calling API Gateway
      final String finalQueryText = "${selectedModel.toUpperCase()} $queryText";

      final Map<String, dynamic> rawEnvelope = await _apiService.searchCatalog(
        finalQueryText,
        base64Images: base64Images.isNotEmpty ? base64Images : null,
      );

      stopwatch.stop();
      final double processingSeconds = stopwatch.elapsedMilliseconds / 1000.0;

      setState(() {
        _chatHistory.add(
          AgentResponse.fromJson(
            queryText, // Keep clean queryText for display, while API processed finalQueryText
            rawEnvelope,
            attachedImages: submittedBytes.isNotEmpty ? submittedBytes : null,
            processingTimeSeconds: processingSeconds,
          ),
        );
      });
      _scrollToBottom();

      // Client-side local search history logging
      if (_userEmail != null && _userEmail!.trim().isNotEmpty) {
        await _searchHistoryService.saveSearch(
          userEmail: _userEmail!,
          query: queryText,
          rawEnvelope: rawEnvelope,
          attachedImages: submittedBytes.isNotEmpty ? submittedBytes : null,
          processingTimeSeconds: processingSeconds,
        );
      }
    } on HttpException catch (e) {
      stopwatch.stop();
      final double processingSeconds = stopwatch.elapsedMilliseconds / 1000.0;
      final Map<String, dynamic> errorEnvelope = {
        'answer': e.message,
        'is_error': true,
        'sources': <dynamic>[],
      };
      setState(() {
        _chatHistory.add(
          AgentResponse.fromJson(
            queryText,
            errorEnvelope,
            attachedImages: submittedBytes.isNotEmpty ? submittedBytes : null,
            processingTimeSeconds: processingSeconds,
            isError: true,
          ),
        );
      });
      _scrollToBottom();

      if (_userEmail != null && _userEmail!.trim().isNotEmpty) {
        await _searchHistoryService.saveSearch(
          userEmail: _userEmail!,
          query: queryText,
          rawEnvelope: errorEnvelope,
          attachedImages: submittedBytes.isNotEmpty ? submittedBytes : null,
          processingTimeSeconds: processingSeconds,
        );
      }
    } catch (e) {
      stopwatch.stop();
      final double processingSeconds = stopwatch.elapsedMilliseconds / 1000.0;
      final Map<String, dynamic> errorEnvelope = {
        'answer': 'Failed to fetch agent resolution data.',
        'is_error': true,
        'sources': <dynamic>[],
      };
      setState(() {
        _chatHistory.add(
          AgentResponse.fromJson(
            queryText,
            errorEnvelope,
            attachedImages: submittedBytes.isNotEmpty ? submittedBytes : null,
            processingTimeSeconds: processingSeconds,
            isError: true,
          ),
        );
      });
      _scrollToBottom();

      if (_userEmail != null && _userEmail!.trim().isNotEmpty) {
        await _searchHistoryService.saveSearch(
          userEmail: _userEmail!,
          query: queryText,
          rawEnvelope: errorEnvelope,
          attachedImages: submittedBytes.isNotEmpty ? submittedBytes : null,
          processingTimeSeconds: processingSeconds,
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _submitFeedback(
    AgentResponse targetResponse,
    bool isHelpful,
  ) async {
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
        const SnackBar(
          content: Text('Network warning: Feedback telemetry failed to sync.'),
        ),
      );
    }
  }

  Widget _buildModernErrorCard() {
    final String errorText = _errorMessage ?? '';

    // Determine error type for contextual design
    IconData errorIcon = Icons.error_outline_rounded;
    String errorCategory = 'Query Rejection';
    Color themeColor = const Color(0xFFEF4444); // Red-500

    if (errorText.toLowerCase().contains('timeout') ||
        errorText.toLowerCase().contains('connection')) {
      errorIcon = Icons.wifi_off_rounded;
      errorCategory = 'Network Timeout';
      themeColor = const Color(0xFFF59E0B); // Amber-500
    } else if (errorText.toLowerCase().contains('unauthorized') ||
        errorText.toLowerCase().contains('session')) {
      errorIcon = Icons.lock_clock_rounded;
      errorCategory = 'Session Expired';
      themeColor = const Color(0xFFEC4899); // Pink-500
    } else if (errorText.toLowerCase().contains('backend') ||
        errorText.toLowerCase().contains('server')) {
      errorIcon = Icons.dns_rounded;
      errorCategory = 'Server Error';
      themeColor = const Color(0xFFEF4444); // Red-500
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeColor.withValues(alpha: 0.1),
            themeColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: themeColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(errorIcon, color: themeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorCategory.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  errorText,
                  style: TextStyle(
                    fontSize: 14,
                    color: themeColor,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_lastQueryText != null) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          _submitAgentQuery(
                            retryQuery: _lastQueryText,
                            retryModel: _lastSelectedModel,
                            retryImages: _lastAttachedImages,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.replay_rounded, size: 14),
                        label: const Text(
                          'Retry Search',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B), // Slate-500
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSearchHistoryBottomSheet() async {
    if (_userEmail == null) return;

    // Fetch fresh logs (automatically prunes old ones)
    final List<AgentResponse> history = await _searchHistoryService.getHistory(
      _userEmail!,
    );

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Pull handler line
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              color: Color(0xFF1E3A8A),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Search History (3 Days)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        if (history.isNotEmpty)
                          TextButton.icon(
                            onPressed: () async {
                              final bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Clear History'),
                                  content: const Text(
                                    'Are you sure you want to clear your local search history?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text(
                                        'Clear',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await _searchHistoryService.clearAllHistory(
                                  _userEmail!,
                                );
                                setSheetState(() {
                                  history.clear();
                                });
                                setState(() {
                                  _chatHistory.clear();
                                });
                              }
                            },
                            icon: const Icon(
                              Icons.delete_sweep_rounded,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            label: const Text(
                              'Clear All',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),

                  // History list
                  Expanded(
                    child: history.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_toggle_off_rounded,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No search history yet',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your searches of the last 3 days will appear here.',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: history.length,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemBuilder: (context, index) {
                              final item =
                                  history[history.length -
                                      1 -
                                      index]; // Show newest first
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    // Set query in text field and close sheet so user can search again or view
                                    _queryController.text = item.query;
                                    Navigator.of(sheetContext).pop();
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF1E3A8A,
                                                ).withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                item.kbModel?.toUpperCase() ??
                                                    'CATALOG',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1E3A8A),
                                                ),
                                              ),
                                            ),
                                            if (item.processingTimeSeconds !=
                                                null)
                                              Text(
                                                '${item.processingTimeSeconds!.toStringAsFixed(2)}s',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item.query,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.unifiedAnswer,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint(
          'canLaunchUrl returned false, attempting direct launch for $urlString',
        );
        await launchUrl(url, mode: LaunchMode.externalApplication);
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
          dialogContent = _buildMinimalistSeal(
            context,
            showEnv,
            envVal,
            currentDateTime,
          );
        } else if (style == 'cyberglow') {
          dialogContent = _buildCyberGlow(
            context,
            showEnv,
            envVal,
            currentDateTime,
          );
        } else {
          dialogContent = _buildSapphirePlaque(
            context,
            showEnv,
            envVal,
            currentDateTime,
          );
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 28.0,
              ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
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
                  Divider(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    thickness: 1,
                  ),
                  const SizedBox(height: 14),
                  if (showEnv) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFD4AF37,
                            ).withValues(alpha: 0.15),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFD4AF37,
                              ).withValues(alpha: 0.1),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
        border: Border.all(color: const Color(0xFF00F2FE), width: 1.5),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 28.0,
              ),
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
                  Divider(
                    color: const Color(0xFF00F2FE).withValues(alpha: 0.2),
                    thickness: 1,
                  ),
                  const SizedBox(height: 16),
                  if (showEnv) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.redAccent, width: 1.0),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00F2FE,
                                  ).withValues(alpha: 0.3),
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
                          side: const BorderSide(
                            color: Color(0xFF00F2FE),
                            width: 1.5,
                          ),
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
        title: const Text(
          AppConfig.appName,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Search History (3 Days)',
            onPressed: _showSearchHistoryBottomSheet,
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ProgressiveLoadingWidget(hasImage: _isProcessingWithImage),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8,
              ),
              child: _buildModernErrorCard(),
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
          colors: [Color(0xFF05070D), Color(0xFF111827), Color(0xFF1E3A8A)],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (response.attachedImages != null &&
                    response.attachedImages!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: List.generate(response.attachedImages!.length, (
                        imgIndex,
                      ) {
                        final imgBytes = response.attachedImages![imgIndex];
                        final double sizeKB = imgBytes.lengthInBytes / 1024.0;

                        return GestureDetector(
                          onTap: () => _showFullscreenImage(imgBytes),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  imgBytes,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${sizeKB.toStringAsFixed(1)} KB',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
                Text(
                  response.query,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
        ),

        // Unified Knowledge Base Synthesized Card
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 24),
          color: response.isError ? const Color(0xFFFEF2F2) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: response.isError
                ? const BorderSide(color: Color(0xFFFCA5A5), width: 1.5)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          response.isError
                              ? Icons.error_outline_rounded
                              : Icons.auto_awesome,
                          color: response.isError
                              ? const Color(0xFFEF4444)
                              : Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          response.isError
                              ? 'Query Rejection'
                              : 'Synthesized Response',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: response.isError
                                ? const Color(0xFFEF4444)
                                : Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),

                    // Dynamic visual badges showing true data origin
                    if (!response.isError)
                      Row(
                        children: [
                          if (response.kbAHasData)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'α Alpha',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (response.kbBHasData)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'β Beta',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          // 💡 New Pill: Displays when BOTH KBs are false, indicating a master database hit
                          if (!response.kbAHasData && !response.kbBHasData)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified_user_outlined,
                                    color: Colors.green,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (response.kbModel != null &&
                                            response.kbModel!.isNotEmpty)
                                        ? response.kbModel!
                                        : 'Verified factual database record',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const Divider(height: 20),
                MarkdownBody(
                  selectable: true,
                  data: response.unifiedAnswer,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: response.isError
                          ? const Color(0xFFEF4444)
                          : Colors.black87,
                    ),
                    strong: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: response.isError
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF1E3A8A),
                    ),
                    listBullet: TextStyle(
                      color: response.isError
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF1E3A8A),
                    ),
                  ),
                ),
                if (response.sources.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book,
                        color: Color(0xFF1E3A8A),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Retrieved References (${response.sources.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...response.sources.map(
                    (source) => ReferenceCardWidget(source: source),
                  ),
                ],
                if (!response.isError) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!hasSubmittedFeedback)
                        const Text(
                          'Was this answer helpful?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        )
                      else
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 14,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Thank you!',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      if (response.processingTimeSeconds != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 13,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Time: ${response.processingTimeSeconds!.toStringAsFixed(1)}s',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (!hasSubmittedFeedback) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _submitFeedback(response, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade200,
                              disabledForegroundColor: Colors.grey.shade500,
                            ),
                            icon: const Icon(
                              Icons.thumb_up_alt_outlined,
                              size: 14,
                            ),
                            label: const Text(
                              'Helpful',
                              style: TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _submitFeedback(response, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade200,
                              disabledForegroundColor: Colors.grey.shade500,
                            ),
                            icon: const Icon(
                              Icons.thumb_down_alt_outlined,
                              size: 14,
                            ),
                            label: const Text(
                              'Not Helpful',
                              style: TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isCompressing)
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0, left: 4.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Optimizing images locally...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedImageBytes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImageBytes.length,
                    itemBuilder: (context, index) {
                      final imgBytes = _selectedImageBytes[index];
                      final double sizeKB = imgBytes.lengthInBytes / 1024.0;

                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 70,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  imgBytes,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              left: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${sizeKB.toStringAsFixed(1)} KB',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Color(0xFF1E3A8A),
                  ),
                  tooltip: 'Attach photos (PNG, JPG, JPEG only)',
                  onPressed: _pickImages,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      hintText: AppConfig.queryHintText,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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
          ],
        ),
      ),
    );
  }
}

class ReferenceCardWidget extends StatefulWidget {
  final KbSource source;

  const ReferenceCardWidget({super.key, required this.source});

  @override
  State<ReferenceCardWidget> createState() => _ReferenceCardWidgetState();
}

class _ReferenceCardWidgetState extends State<ReferenceCardWidget> {
  bool _isExpanded = false;

  Future<void> _openPresignedUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try launching directly
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final String fileName = source.sourceUri.split('/').last;
    final int matchPercent = (source.score * 100).round();
    final isTiger = source.kbModel.toUpperCase() == 'TIGER';
    final String? presignedUrl =
        source.s3PresignedUrl ?? source.s3ImageUriPresigned;

    String cleanText = source.text.trim();
    while ((cleanText.startsWith("'") && cleanText.endsWith("'")) ||
        (cleanText.startsWith('"') && cleanText.endsWith('"')) ||
        (cleanText.startsWith('`') && cleanText.endsWith('`'))) {
      cleanText = cleanText.substring(1, cleanText.length - 1).trim();
    }

    final bool hasBody = cleanText.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasBody
                ? () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isTiger
                          ? Colors.amber.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${source.kbModel} Catalog',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isTiger
                            ? Colors.amber.shade900
                            : Colors.blue.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Match: $matchPercent%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '📄 $fileName',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (presignedUrl != null &&
                      presignedUrl.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Open reference document',
                      child: InkWell(
                        onTap: () => _openPresignedUrl(presignedUrl),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.open_in_new,
                                color: Colors.blue,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Open',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (hasBody) ...[
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade500,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasBody && _isExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: 12.0,
                right: 12.0,
                bottom: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final bool isTable = cleanText.contains('|');

                      Widget markdownWidget = MarkdownBody(
                        selectable: true,
                        data: cleanText,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                          strong: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                          listBullet: const TextStyle(color: Color(0xFF1E3A8A)),
                          tableBody: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade800,
                          ),
                          tableHead: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                          tableBorder: TableBorder.all(
                            color: Colors.grey.shade300,
                            width: 1.0,
                          ),
                        ),
                      );

                      if (isTable) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: IntrinsicWidth(child: markdownWidget),
                              ),
                            );
                          },
                        );
                      }

                      return markdownWidget;
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
