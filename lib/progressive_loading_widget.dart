import 'dart:async';
import 'package:flutter/material.dart';
import 'executive_theme.dart';

enum StageStatus { waiting, inProgress, completed }

class ProgressiveStage {
  final String title;
  final String description;
  final int estimatedSeconds;
  final IconData icon;
  final String? gifAsset;
  StageStatus status;

  ProgressiveStage({
    required this.title,
    required this.description,
    required this.estimatedSeconds,
    required this.icon,
    this.gifAsset,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? ExecutiveTheme.darkCardBg : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? ExecutiveTheme.darkCardBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Processing Request (${_elapsedSeconds}s)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
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
                        color: isDark
                            ? const Color(0xFF2E2416)
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFFC5A059).withValues(alpha: 0.3)
                              : Colors.amber.shade200,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: isDark ? const Color(0xFFD4B170) : Colors.amber.shade800,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This is taking a little longer because the system is conducting a deep search across the entire part catalogue.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? const Color(0xFFF3E8EE)
                                    : const Color(0xFF78350F),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final bool isCompleted = stage.status == StageStatus.completed;
    final bool isInProgress = stage.status == StageStatus.inProgress;

    Color cardBgColor;
    Color borderColor;
    Color iconColor;
    Color titleColor;
    Color descColor;
    double elevation;

    if (isCompleted) {
      cardBgColor = isDark ? ExecutiveTheme.darkCardBg : Colors.white;
      borderColor = isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade100;
      iconColor = isDark ? ExecutiveTheme.successGreen : Colors.green.shade600;
      titleColor = isDark ? ExecutiveTheme.darkTextPrimary : Colors.grey.shade800;
      descColor = isDark ? ExecutiveTheme.darkTextSecondary.withValues(alpha: 0.7) : Colors.grey.shade500;
      elevation = 0;
    } else if (isInProgress) {
      cardBgColor = isDark ? const Color(0xFF1C1C1F) : Colors.white;
      borderColor = primaryColor.withValues(alpha: 0.3);
      iconColor = primaryColor;
      titleColor = primaryColor;
      descColor = isDark ? ExecutiveTheme.darkTextPrimary : Colors.grey.shade700;
      elevation = 2;
    } else {
      // Waiting
      cardBgColor = isDark ? Colors.black26 : Colors.grey.shade50.withValues(alpha: 0.5);
      borderColor = isDark ? ExecutiveTheme.darkCardBorder : Colors.grey.shade100;
      iconColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
      titleColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
      descColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
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
                  color: primaryColor.withValues(alpha: 0.08),
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
                    ? primaryColor.withValues(alpha: 0.08)
                    : isCompleted
                    ? (isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green.shade50)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: _buildStageIcon(
                stage,
                iconColor,
                isInProgress,
                isCompleted,
              ),
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
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      child: LinearProgressIndicator(
                        minHeight: 2.5,
                        backgroundColor: isDark ? Colors.grey.shade900 : const Color(0xFFEFF6FF),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
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
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryColor,
                      ),
                    )
                  : Icon(
                      Icons.radio_button_unchecked_rounded,
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      size: 16,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageIcon(
    ProgressiveStage stage,
    Color color,
    bool isInProgress,
    bool isCompleted,
  ) {
    if (stage.gifAsset != null && isInProgress) {
      return Image.asset(
        stage.gifAsset!,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return ActiveStageAnimation(stage: stage, color: color);
        },
      );
    }

    if (isInProgress) {
      return ActiveStageAnimation(stage: stage, color: color);
    }

    return Icon(stage.icon, color: color, size: 20);
  }
}

class ActiveStageAnimation extends StatefulWidget {
  final ProgressiveStage stage;
  final Color color;

  const ActiveStageAnimation({
    super.key,
    required this.stage,
    required this.color,
  });

  @override
  State<ActiveStageAnimation> createState() => _ActiveStageAnimationState();
}

class _ActiveStageAnimationState extends State<ActiveStageAnimation>
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
    final icon = widget.stage.icon;

    if (icon == Icons.settings_suggest_rounded ||
        icon == Icons.manage_search_rounded) {
      return RotationTransition(
        turns: _controller,
        child: Icon(icon, color: widget.color, size: 20),
      );
    } else if (icon == Icons.image_search_rounded ||
        icon == Icons.compare_rounded ||
        icon == Icons.find_in_page_rounded) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.15).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Icon(icon, color: widget.color, size: 20),
      );
    } else if (icon == Icons.auto_awesome_rounded) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 0.15,
            child: Opacity(
              opacity:
                  0.5 +
                  (_controller.value < 0.5
                      ? _controller.value
                      : 1.0 - _controller.value),
              child: Icon(icon, color: widget.color, size: 20),
            ),
          );
        },
      );
    } else {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Icon(icon, color: widget.color, size: 20),
      );
    }
  }
}
