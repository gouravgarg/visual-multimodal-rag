import 'dart:async';
import 'package:flutter/material.dart';

enum StageStatus { waiting, inProgress, completed }

class ProgressiveStage {
  final String title;
  final String description;
  final int estimatedSeconds;
  final IconData icon;
  StageStatus status;

  ProgressiveStage({
    required this.title,
    required this.description,
    required this.estimatedSeconds,
    required this.icon,
    this.status = StageStatus.waiting,
  });
}

class ProgressiveLoadingWidget extends StatefulWidget {
  final bool hasImage;
  final VoidCallback? onTimeoutWarning;

  const ProgressiveLoadingWidget({
    super.key,
    this.hasImage = true,
    this.onTimeoutWarning,
  });

  @override
  State<ProgressiveLoadingWidget> createState() =>
      _ProgressiveLoadingWidgetState();
}

class _ProgressiveLoadingWidgetState extends State<ProgressiveLoadingWidget> {
  late List<ProgressiveStage> _stages;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _showDelayWarning = false;

  @override
  void initState() {
    super.initState();
    _initializeStages();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeStages() {
    if (widget.hasImage) {
      _stages = [
        ProgressiveStage(
          title: 'Preparing request',
          description: 'System is compiling search terms and metadata.',
          estimatedSeconds: 1,
          icon: Icons.settings_suggest_rounded,
          status: StageStatus.inProgress,
        ),
        ProgressiveStage(
          title: 'Analysing uploaded image',
          description:
              'System is identifying visible part details from your uploaded image.',
          estimatedSeconds: 3,
          icon: Icons.image_search_rounded,
        ),
        ProgressiveStage(
          title: 'Searching for similar part images in catalogue',
          description:
              'System is comparing your image with catalogue part images.',
          estimatedSeconds: 3,
          icon: Icons.compare_rounded,
        ),
        ProgressiveStage(
          title: 'Searching the part catalogue',
          description:
              'System is checking matching part names, numbers, and descriptions.',
          estimatedSeconds: 3,
          icon: Icons.find_in_page_rounded,
        ),
        ProgressiveStage(
          title: 'Generating final answer',
          description:
              'System is combining image results, catalogue matches, and text search results.',
          estimatedSeconds: 15,
          icon: Icons.auto_awesome_rounded,
        ),
        ProgressiveStage(
          title: 'Finalising response',
          description: 'System is preparing the answer for display.',
          estimatedSeconds: 3,
          icon: Icons.fact_check_rounded,
        ),
      ];
    } else {
      _stages = [
        ProgressiveStage(
          title: 'Preparing request',
          description: 'System is compiling search terms and metadata.',
          estimatedSeconds: 1,
          icon: Icons.settings_suggest_rounded,
          status: StageStatus.inProgress,
        ),
        ProgressiveStage(
          title: 'Searching the part catalogue',
          description:
              'System is checking matching part names, numbers, and descriptions.',
          estimatedSeconds: 3,
          icon: Icons.find_in_page_rounded,
        ),
        ProgressiveStage(
          title: 'Conducting deep search',
          description:
              'System is performing a deep semantic search for details.',
          estimatedSeconds: 8,
          icon: Icons.manage_search_rounded,
        ),
        ProgressiveStage(
          title: 'Preparing final response',
          description: 'System is preparing the answer for display.',
          estimatedSeconds: 3,
          icon: Icons.fact_check_rounded,
        ),
      ];
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _elapsedSeconds++;

        final int warningLimit = widget.hasImage ? 15 : 10;
        if (_elapsedSeconds >= warningLimit) {
          _showDelayWarning = true;
        }

        _updateStageStatuses();
      });
    });
  }

  void _updateStageStatuses() {
    int timeSum = 0;
    for (var stage in _stages) {
      final int start = timeSum;
      final int end = timeSum + stage.estimatedSeconds;

      if (_elapsedSeconds >= end) {
        stage.status = StageStatus.completed;
      } else if (_elapsedSeconds >= start && _elapsedSeconds < end) {
        stage.status = StageStatus.inProgress;
      } else {
        stage.status = StageStatus.waiting;
      }

      timeSum = end;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Processing Request (${_elapsedSeconds}s)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progressive Loading Cards
          ..._stages.map((stage) => _buildStageCard(stage)),

          // Animated long processing warning
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showDelayWarning
                ? Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.amber.shade800,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'This is taking a little longer because the system is conducting a deep search across the entire part catalogue.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF78350F),
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStageCard(ProgressiveStage stage) {
    final bool isCompleted = stage.status == StageStatus.completed;
    final bool isInProgress = stage.status == StageStatus.inProgress;

    Color cardBgColor;
    Color borderColor;
    Color iconColor;
    Color titleColor;
    Color descColor;
    double elevation;

    if (isCompleted) {
      cardBgColor = Colors.white;
      borderColor = Colors.green.shade100;
      iconColor = Colors.green.shade600;
      titleColor = Colors.grey.shade800;
      descColor = Colors.grey.shade500;
      elevation = 0;
    } else if (isInProgress) {
      cardBgColor = Colors.white;
      borderColor = const Color(0xFF1E3A8A).withValues(alpha: 0.3);
      iconColor = const Color(0xFF1E3A8A);
      titleColor = const Color(0xFF1E3A8A);
      descColor = Colors.grey.shade700;
      elevation = 2;
    } else {
      // Waiting
      cardBgColor = Colors.grey.shade50.withValues(alpha: 0.5);
      borderColor = Colors.grey.shade100;
      iconColor = Colors.grey.shade300;
      titleColor = Colors.grey.shade400;
      descColor = Colors.grey.shade400;
      elevation = 0;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isInProgress ? 1.5 : 1.0),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Icon Container
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isInProgress
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.08)
                    : isCompleted
                    ? Colors.green.shade50
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(stage.icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stage.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage.description,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: descColor,
                    ),
                  ),
                  if (isInProgress) ...[
                    const SizedBox(height: 10),
                    const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      child: LinearProgressIndicator(
                        minHeight: 2.5,
                        backgroundColor: Color(0xFFEFF6FF),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Status Indicator (Spinner, Tick or Empty)
            SizedBox(
              width: 20,
              height: 20,
              child: isCompleted
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 20,
                    )
                  : isInProgress
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1E3A8A),
                      ),
                    )
                  : Icon(
                      Icons.radio_button_unchecked_rounded,
                      color: Colors.grey.shade300,
                      size: 16,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
