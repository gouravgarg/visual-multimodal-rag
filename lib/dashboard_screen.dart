import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'executive_theme.dart';

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
                    colors: [Color(0xFF1F1A12), Color(0xFF0C0905)],
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
                        color: const Color(0xFFD4B170).withValues(alpha: 0.15),
                        border: Border.all(
                          color: const Color(0xFFD4B170),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Color(0xFFD4B170),
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
                                ? const Color(0xFFD4B170).withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFD4B170)
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
                                    ? const Color(0xFFD4B170)
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
                              backgroundColor: const Color(0xFFD4B170),
                              foregroundColor: Colors.black,
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

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text(
                'Response copied to clipboard!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.white,
          elevation: 4,
        ),
      );
    }
  }

  Widget _buildFooterActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    Color? iconColor,
    Color? bgColor,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color defaultBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final Color defaultBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor ?? defaultBg,
        type: MaterialType.button,
        borderRadius: BorderRadius.circular(10),
        borderOnForeground: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: bgColor != null ? Colors.transparent : defaultBorder,
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
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
                if (errorCategory != 'Query Rejection') ...[
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
                ],
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
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.only(
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
                        Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Search History (3 Days)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                                                color: isDark
                                                    ? const Color(0xFF60A5FA).withValues(alpha: 0.15)
                                                    : const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                item.kbModel?.toUpperCase() ??
                                                    'CATALOG',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A),
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
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.unifiedAnswer,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
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
          colors: [Color(0xFF1F1A12), Color(0xFF0C0905)],
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
            color: const Color(0xFFD4B170).withValues(alpha: 0.15),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
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
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                border: Border.all(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'SP',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppConfig.appName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Release Version ${AppConfig.appVersion}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Divider(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              thickness: 1.5,
            ),
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
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  envVal.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A),
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
            Text(
              'Gourav Garg',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'gouravgarg.co.uk',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                  foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  side: BorderSide(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                  ),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? ExecutiveTheme.darkScaffoldBg : ExecutiveTheme.lightScaffoldBg,
      appBar: AppBar(
        title: const Text(
          AppConfig.appName,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: isDark ? ExecutiveTheme.darkScaffoldBg : ExecutiveTheme.lightPrimaryObsidian,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<ThemeMode>(
            icon: Icon(
              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            ),
            tooltip: 'Theme Settings',
            onSelected: (ThemeMode mode) {
              Provider.of<ThemeProvider>(context, listen: false).setThemeMode(mode);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ThemeMode>>[
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.light,
                child: Row(
                  children: [
                    Icon(Icons.light_mode, size: 20),
                    SizedBox(width: 8),
                    Text('Light Theme'),
                  ],
                ),
              ),
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.dark,
                child: Row(
                  children: [
                    Icon(Icons.dark_mode, size: 20),
                    SizedBox(width: 8),
                    Text('Dark Theme'),
                  ],
                ),
              ),
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.system,
                child: Row(
                  children: [
                    Icon(Icons.settings_brightness, size: 20),
                    SizedBox(width: 8),
                    Text('System Default'),
                  ],
                ),
              ),
            ],
          ),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String greetingName = _userEmail == null || _userEmail!.trim().isEmpty
        ? 'there'
        : _userEmail!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? ExecutiveTheme.darkEmptyStateColors
              : ExecutiveTheme.lightEmptyStateColors,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 48,
                color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
              ),
              const SizedBox(height: 24),
              Text(
                'Hi $greetingName,\nWhat do you need?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  height: 1.2,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : ExecutiveTheme.lightPrimaryObsidian,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppConfig.emptyStateSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? ExecutiveTheme.darkTextSecondary : ExecutiveTheme.lightTextSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // User Query Bubble
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(left: 48, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? ExecutiveTheme.darkUserBubbleColors
                    : ExecutiveTheme.lightUserBubbleColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? ExecutiveTheme.darkAccentCognac.withValues(alpha: 0.25)
                      : ExecutiveTheme.lightPrimaryObsidian.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
                  style: TextStyle(
                    color: isDark ? const Color(0xFF09090B) : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Unified Knowledge Base Synthesized Card
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: response.isError
                ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.15) : const Color(0xFFFEF2F2))
                : (isDark ? ExecutiveTheme.darkCardBg : ExecutiveTheme.lightCardBg),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: response.isError
                  ? ExecutiveTheme.errorRed.withValues(alpha: isDark ? 0.5 : 0.3)
                  : (isDark ? ExecutiveTheme.darkCardBorder : ExecutiveTheme.lightCardBorder),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (response.isError)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: ExecutiveTheme.errorRed,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MarkdownBody(
                          selectable: true,
                          data: response.unifiedAnswer,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: ExecutiveTheme.errorRed,
                              fontWeight: FontWeight.w600,
                            ),
                            strong: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ExecutiveTheme.errorRed,
                            ),
                            listBullet: const TextStyle(
                              color: ExecutiveTheme.errorRed,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? ExecutiveTheme.darkUserBubbleColors
                                : ExecutiveTheme.lightUserBubbleColors,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? ExecutiveTheme.darkAccentCognac.withValues(alpha: 0.3)
                                  : ExecutiveTheme.lightPrimaryObsidian.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: isDark ? const Color(0xFF09090B) : Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'AI CO-PILOT',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.8,
                                color: isDark ? const Color(0xFF09090B) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Dynamic visual badges showing true data origin
                      Row(
                        children: [
                          if (response.kbAHasData)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? ExecutiveTheme.darkAlphaBg
                                    : ExecutiveTheme.lightAlphaBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? ExecutiveTheme.darkAlphaBorder
                                      : ExecutiveTheme.lightAlphaBorder,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.layers_outlined,
                                    size: 11,
                                    color: isDark ? ExecutiveTheme.darkAlphaText : ExecutiveTheme.lightAlphaText,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'α Alpha',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? ExecutiveTheme.darkAlphaText : ExecutiveTheme.lightAlphaText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (response.kbBHasData)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? ExecutiveTheme.darkBetaBg
                                    : ExecutiveTheme.lightBetaBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? ExecutiveTheme.darkBetaBorder
                                      : ExecutiveTheme.lightBetaBorder,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    size: 11,
                                    color: isDark ? ExecutiveTheme.darkBetaText : ExecutiveTheme.lightBetaText,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'β Beta',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? ExecutiveTheme.darkBetaText : ExecutiveTheme.lightBetaText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // 💡 New Pill: Displays when BOTH KBs are false, indicating a master database hit
                          if (!response.kbAHasData && !response.kbBHasData)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? ExecutiveTheme.darkMatchBg
                                    : ExecutiveTheme.lightMatchBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? ExecutiveTheme.darkMatchBorder
                                      : ExecutiveTheme.lightMatchBorder,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    color: isDark ? ExecutiveTheme.darkMatchText : ExecutiveTheme.lightMatchText,
                                    size: 11,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (response.kbModel != null &&
                                            response.kbModel!.isNotEmpty)
                                        ? response.kbModel!
                                        : 'Verified factual database record',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? ExecutiveTheme.darkMatchText : ExecutiveTheme.lightMatchText,
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
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                      ),
                      strong: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                      ),
                      listBullet: TextStyle(
                        color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                      ),
                      blockquote: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        color: isDark ? ExecutiveTheme.darkBlockquoteText : ExecutiveTheme.lightBlockquoteText,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: isDark ? ExecutiveTheme.darkBlockquoteBg : ExecutiveTheme.lightBlockquoteBg,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        border: Border(
                          left: BorderSide(
                            color: isDark ? ExecutiveTheme.darkBlockquoteBorder : ExecutiveTheme.lightBlockquoteBorder,
                            width: 4,
                          ),
                        ),
                      ),
                      code: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        color: isDark ? ExecutiveTheme.darkCodeText : ExecutiveTheme.lightCodeText,
                        backgroundColor: isDark ? ExecutiveTheme.darkCodeBg : ExecutiveTheme.lightCodeBg,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isDark ? ExecutiveTheme.darkCodeBlockBg : ExecutiveTheme.lightCodeBlockBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? ExecutiveTheme.darkCodeBlockBorder : ExecutiveTheme.lightCodeBlockBorder,
                        ),
                      ),
                      tableBody: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                      ),
                      tableHead: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? ExecutiveTheme.darkTableHeaderText : ExecutiveTheme.lightTableHeaderText,
                      ),
                      tableBorder: TableBorder.all(
                        color: isDark ? ExecutiveTheme.darkTableBorder : ExecutiveTheme.lightTableBorder,
                        width: 1.0,
                      ),
                      h1: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                      ),
                      h2: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                      ),
                      h3: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                      ),
                      h4: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                      ),
                    ),
                  ),
                ],
                if (response.sources.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.explore_outlined,
                        color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Retrieved References',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.5,
                          color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? ExecutiveTheme.darkPrimaryGold.withValues(alpha: 0.15)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? ExecutiveTheme.darkPrimaryGold.withValues(alpha: 0.3)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Text(
                          '${response.sources.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...response.sources.map(
                    (source) => ReferenceCardWidget(
                      source: source,
                      responseCreatedAt: response.createdAt,
                    ),
                  ),
                ],
                if (!response.isError) ...[
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // LEFT SIDE: Generation Time & Selection confirmation
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (response.processingTimeSeconds != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.04),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 13,
                                    color: isDark
                                        ? ExecutiveTheme.darkPrimaryGold
                                        : ExecutiveTheme.lightAccentGold,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${response.processingTimeSeconds!.toStringAsFixed(1)}s response',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          
                          // Custom subtle dynamic badge showing state of feedback
                          if (response.selectedFeedback == 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 13,
                                    color: Color(0xFF10B981),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Helpful',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (response.selectedFeedback == 2)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 13,
                                    color: Color(0xFFF43F5E),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Feedback recorded',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF43F5E),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              'Was this helpful?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      
                      // RIGHT SIDE: Action Buttons (Copy, Thumbs Up, Thumbs Down)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Copy Button (Subtle & Glassy)
                          _buildFooterActionButton(
                            icon: Icons.copy_all_rounded,
                            tooltip: 'Copy unified answer',
                            onTap: () => _copyToClipboard(response.unifiedAnswer),
                            iconColor: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          
                          // Thumbs Up (Helpful)
                          _buildFooterActionButton(
                            icon: response.selectedFeedback == 1
                                ? Icons.thumb_up_rounded
                                : Icons.thumb_up_outlined,
                            tooltip: response.selectedFeedback == 1
                                ? 'Helpful'
                                : 'Mark as helpful',
                            iconColor: response.selectedFeedback == 1
                                ? const Color(0xFF10B981)
                                : response.selectedFeedback == 2
                                    ? (isDark ? Colors.white10 : Colors.black12)
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            bgColor: response.selectedFeedback == 1
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : null,
                            onTap: response.selectedFeedback != 0
                                ? null
                                : () => _submitFeedback(response, true),
                          ),
                          const SizedBox(width: 8),
                          
                          // Thumbs Down (Not Helpful)
                          _buildFooterActionButton(
                            icon: response.selectedFeedback == 2
                                ? Icons.thumb_down_rounded
                                : Icons.thumb_down_outlined,
                            tooltip: response.selectedFeedback == 2
                                ? 'Feedback recorded'
                                : 'Mark as unhelpful',
                            iconColor: response.selectedFeedback == 2
                                ? const Color(0xFFF43F5E)
                                : response.selectedFeedback == 1
                                    ? (isDark ? Colors.white10 : Colors.black12)
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            bgColor: response.selectedFeedback == 2
                                ? const Color(0xFFF43F5E).withValues(alpha: 0.15)
                                : null,
                            onTap: response.selectedFeedback != 0
                                ? null
                                : () => _submitFeedback(response, false),
                          ),
                        ],
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

  Widget _buildInputBar() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
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
                      icon: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                      ),
                      tooltip: 'Attach photos (PNG, JPG, JPEG only)',
                      onPressed: _pickImages,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _queryController,
                        keyboardType: TextInputType.multiline,
                        minLines: 1,
                        maxLines: 5,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: AppConfig.queryHintText,
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
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
                      backgroundColor: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightPrimaryObsidian,
                      child: IconButton(
                        icon: Icon(
                          Icons.send,
                          color: isDark ? Colors.black : Colors.white,
                          size: 18,
                        ),
                        onPressed: _submitAgentQuery,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_isProcessing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ShiftingGradientLine(),
          ),
      ],
    );
  }
}

class ReferenceCardWidget extends StatefulWidget {
  final KbSource source;
  final DateTime? responseCreatedAt;

  const ReferenceCardWidget({
    super.key,
    required this.source,
    this.responseCreatedAt,
  });

  @override
  State<ReferenceCardWidget> createState() => _ReferenceCardWidgetState();
}

class _ReferenceCardWidgetState extends State<ReferenceCardWidget> {
  bool _isExpanded = false;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _startExpiryTimer();
  }

  @override
  void didUpdateWidget(covariant ReferenceCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.responseCreatedAt != widget.responseCreatedAt) {
      _startExpiryTimer();
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  bool get _isLinkExpired {
    final createdAt = widget.responseCreatedAt ?? DateTime.now();
    return DateTime.now().difference(createdAt).inSeconds >= 3600;
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    final createdAt = widget.responseCreatedAt ?? DateTime.now();
    final timePassed = DateTime.now().difference(createdAt);
    final remainingSeconds = 3600 - timePassed.inSeconds;
    if (remainingSeconds > 0) {
      _expiryTimer = Timer(Duration(seconds: remainingSeconds), () {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

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
    final bool isExpired = _isLinkExpired;

    String cleanText = source.text.trim();
    while ((cleanText.startsWith("'") && cleanText.endsWith("'")) ||
        (cleanText.startsWith('"') && cleanText.endsWith('"')) ||
        (cleanText.startsWith('`') && cleanText.endsWith('`'))) {
      cleanText = cleanText.substring(1, cleanText.length - 1).trim();
    }

    final bool hasBody = cleanText.isNotEmpty;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? ExecutiveTheme.darkCardBg : ExecutiveTheme.lightCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? ExecutiveTheme.darkCardBorder : ExecutiveTheme.lightCardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isTiger
                          ? (isDark ? ExecutiveTheme.darkAlphaBg : ExecutiveTheme.lightAlphaBg)
                          : (isDark ? ExecutiveTheme.darkBetaBg : ExecutiveTheme.lightBetaBg),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isTiger
                            ? (isDark ? ExecutiveTheme.darkAlphaBorder : ExecutiveTheme.lightAlphaBorder)
                            : (isDark ? ExecutiveTheme.darkBetaBorder : ExecutiveTheme.lightBetaBorder),
                      ),
                    ),
                    child: Text(
                      '${source.kbModel} Catalog',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isTiger
                            ? (isDark ? ExecutiveTheme.darkAlphaText : ExecutiveTheme.lightAlphaText)
                            : (isDark ? ExecutiveTheme.darkBetaText : ExecutiveTheme.lightBetaText),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? ExecutiveTheme.darkMatchBg : ExecutiveTheme.lightMatchBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? ExecutiveTheme.darkMatchBorder : ExecutiveTheme.lightMatchBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.radar_rounded,
                          size: 11,
                          color: isDark ? ExecutiveTheme.darkMatchText : ExecutiveTheme.lightMatchText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Match: $matchPercent%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isDark ? ExecutiveTheme.darkMatchText : ExecutiveTheme.lightMatchText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '📄 $fileName',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? ExecutiveTheme.darkTextPrimary : ExecutiveTheme.lightTextPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (presignedUrl != null &&
                      presignedUrl.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: isExpired
                          ? 'Link expired (S3 presigned URLs expire after 1 hour)'
                          : 'Open reference document',
                      child: InkWell(
                        onTap: isExpired ? null : () => _openPresignedUrl(presignedUrl),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isExpired
                                ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100)
                                : (isDark ? ExecutiveTheme.darkViewSourceBg : ExecutiveTheme.lightViewSourceBg),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isExpired
                                  ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300)
                                  : (isDark ? ExecutiveTheme.darkViewSourceBorder : ExecutiveTheme.lightViewSourceBorder),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isExpired ? Icons.link_off_rounded : Icons.open_in_new_rounded,
                                color: isExpired
                                    ? Colors.grey
                                    : (isDark ? ExecutiveTheme.darkViewSourceText : ExecutiveTheme.lightViewSourceText),
                                size: 13,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isExpired ? 'Expired' : 'View Source',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isExpired
                                      ? Colors.grey
                                      : (isDark ? ExecutiveTheme.darkViewSourceText : ExecutiveTheme.lightViewSourceText),
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
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                          strong: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                          ),
                          listBullet: TextStyle(
                            color: isDark ? ExecutiveTheme.darkPrimaryGold : ExecutiveTheme.lightAccentGold,
                          ),
                          blockquote: TextStyle(
                            fontSize: 11.5,
                            height: 1.4,
                            fontStyle: FontStyle.italic,
                            color: isDark ? ExecutiveTheme.darkBlockquoteText : ExecutiveTheme.lightBlockquoteText,
                          ),
                          blockquoteDecoration: BoxDecoration(
                            color: isDark ? ExecutiveTheme.darkBlockquoteBg : ExecutiveTheme.lightBlockquoteBg,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(6),
                              bottomRight: Radius.circular(6),
                            ),
                            border: Border(
                              left: BorderSide(
                                color: isDark ? ExecutiveTheme.darkBlockquoteBorder : ExecutiveTheme.lightBlockquoteBorder,
                                width: 3,
                              ),
                            ),
                          ),
                          code: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: isDark ? ExecutiveTheme.darkCodeText : ExecutiveTheme.lightCodeText,
                            backgroundColor: isDark ? ExecutiveTheme.darkCodeBg : ExecutiveTheme.lightCodeBg,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: isDark ? ExecutiveTheme.darkCodeBlockBg : ExecutiveTheme.lightCodeBlockBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? ExecutiveTheme.darkCodeBlockBorder : ExecutiveTheme.lightCodeBlockBorder,
                            ),
                          ),
                          tableBody: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                          ),
                          tableHead: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? ExecutiveTheme.darkTableHeaderText : ExecutiveTheme.lightTableHeaderText,
                          ),
                          tableBorder: TableBorder.all(
                            color: isDark ? ExecutiveTheme.darkTableBorder : ExecutiveTheme.lightTableBorder,
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

class ShiftingGradientLine extends StatefulWidget {
  const ShiftingGradientLine({super.key});

  @override
  State<ShiftingGradientLine> createState() => _ShiftingGradientLineState();
}

class _ShiftingGradientLineState extends State<ShiftingGradientLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 3,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: ExecutiveTheme.loadingFluidColors,
              begin: Alignment(-1.0 + _controller.value * 2.0, 0.0),
              end: Alignment(1.0 + _controller.value * 2.0, 0.0),
              tileMode: TileMode.repeated,
            ),
          ),
        );
      },
    );
  }
}
