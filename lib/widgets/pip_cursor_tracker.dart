

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class PipCursorTracker extends StatefulWidget {
  final double? width;
  final double? height;
  final bool enableTouchFallback;
  final bool enableIdleFloating;
  final bool isNightMode;
  final bool isPointerInsideApp;
  final double deadzoneRadiusRatio;
  final Animation<double>? laughAnimation;
  final ValueChanged<double>? onAngleChanged;
  final VoidCallback? onEyeContact;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const PipCursorTracker({
    super.key,
    this.width,
    this.height,
    this.enableTouchFallback = true,
    this.enableIdleFloating = true,
    this.isNightMode = false,
    this.isPointerInsideApp = true,
    this.deadzoneRadiusRatio = 0.08,
    this.laughAnimation,
    this.onAngleChanged,
    this.onEyeContact,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  State<PipCursorTracker> createState() => _PipCursorTrackerState();
}

enum _GazeDirection {
  upperLeft,
  up,
  upperRight,
  left,
  center,
  right,
  lowerLeft,
  down,
  lowerRight,
}

class _PipCursorTrackerState extends State<PipCursorTracker>
    with SingleTickerProviderStateMixin {
  final GlobalKey _trackerKey = GlobalKey();

  static const int totalDirectionalFrames = 16;

  late Ticker _ticker;
  double _currentAngle = 0.0;
  double _targetAngle = 0.0;
  double _currentDeadzoneFactor = 1.0;
  double _targetDeadzoneFactor = 1.0;

  bool _isInteracting = false;
  Offset _cursorPos = Offset.zero;
  int _activeFrameIndex = 0;

  double _idleTime = 0.0;

  _GazeDirection _gazeDirection = _GazeDirection.center;
  int _horizontalDirection = 0;
  int _verticalDirection = 0;
  bool _isInEyeContact = false;

  static const Map<_GazeDirection, (int, int)> _gazeFrameMap = {
    _GazeDirection.upperLeft: (0, 16),
    _GazeDirection.up: (1, 9),
    _GazeDirection.upperRight: (2, 10),
    _GazeDirection.left: (7, 15),
    _GazeDirection.center: (8, 16),
    _GazeDirection.right: (3, 12),
    _GazeDirection.lowerLeft: (6, 14),
    _GazeDirection.down: (5, 13),
    _GazeDirection.lowerRight: (4, 11),
  };

  static const Map<int, int> _laughFrameNumbers = {
    9: 50,
    10: 65,
    11: 110,
    12: 90,
    13: 135,
    14: 170,
    15: 185,
    16: 220,
  };

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
    widget.laughAnimation?.addStatusListener(_handleLaughAnimationStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAllFrames();
  }

  void _precacheAllFrames() {
    precacheImage(
        const AssetImage('assets/images/gayathri_character_transparent_git_original.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_transparent/frame_050.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_transparent/frame_065.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_transparent/frame_090.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_transparent/frame_110.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_transparent/frame_135.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_transparent/frame_170.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_transparent/frame_185.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_transparent/frame_220.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_laugh_base/frame_050.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_laugh_base/frame_065.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_laugh_base/frame_090.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_laugh_base/frame_110.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_laugh_base/frame_135.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_laugh_base/frame_170.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_laugh_base/frame_185.png'), context);
    precacheImage(const AssetImage('assets/images/gayathri_gaze_laugh_base/frame_220.png'), context);
  }

  @override
  void didUpdateWidget(covariant PipCursorTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.laughAnimation != widget.laughAnimation) {
      oldWidget.laughAnimation?.removeStatusListener(_handleLaughAnimationStatus);
      widget.laughAnimation?.addStatusListener(_handleLaughAnimationStatus);
    }
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
    _ticker.dispose();
    widget.laughAnimation?.removeStatusListener(_handleLaughAnimationStatus);
    super.dispose();
  }

double _lerpAngle(double current, double target, double t) {
    double diff = (target - current) % (2.0 * math.pi);
    if (diff > math.pi) diff -= 2.0 * math.pi;
    if (diff < -math.pi) diff += 2.0 * math.pi;
    return current + diff * t;
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;

    setState(() {
      _idleTime += 0.02;

      _currentAngle = _lerpAngle(_currentAngle, _targetAngle, 0.22);

      _currentDeadzoneFactor +=
          (_targetDeadzoneFactor - _currentDeadzoneFactor) * 0.20;

      if (_currentDeadzoneFactor > 0.65) {
        if (_gazeDirection != _GazeDirection.center) {
          _horizontalDirection = 0;
          _verticalDirection = 0;
          _gazeDirection = _GazeDirection.center;
          widget.onEyeContact?.call();
        }
      } else {
        double normalized =
            (_currentAngle % (2.0 * math.pi) + 2.0 * math.pi) % (2.0 * math.pi);
        int sector = (normalized / (math.pi / 4)).round() % 8;
        int horizontal, vertical;
        switch (sector) {
          case 0:
            horizontal = 1;
            vertical = 0;
            break;
          case 1:
            horizontal = 1;
            vertical = 1;
            break;
          case 2:
            horizontal = 0;
            vertical = 1;
            break;
          case 3:
            horizontal = -1;
            vertical = 1;
            break;
          case 4:
            horizontal = -1;
            vertical = 0;
            break;
          case 5:
            horizontal = -1;
            vertical = -1;
            break;
          case 6:
            horizontal = 0;
            vertical = -1;
            break;
          case 7:
            horizontal = 1;
            vertical = -1;
            break;
          default:
            horizontal = 0;
            vertical = 0;
        }
        if (horizontal != _horizontalDirection ||
            vertical != _verticalDirection) {
          _horizontalDirection = horizontal;
          _verticalDirection = vertical;
          _gazeDirection = _directionFor(horizontal, vertical);
        }
      }
    });
  }

  void _updateTargetFromPosition(Offset localPos, Size size) {
    final faceCenter = Offset(size.width * 0.50, size.height * 0.41);
    final delta = localPos - faceCenter;
    final distance = delta.distance;
    final deadzoneThreshold =
        math.min(size.width, size.height) * widget.deadzoneRadiusRatio;

    if (distance <= deadzoneThreshold) {
      _targetDeadzoneFactor = 1.0;
    } else {
      _targetDeadzoneFactor = 0.0;
      _targetAngle = math.atan2(delta.dy, delta.dx);
    }
  }

  void _onGlobalPointer(PointerEvent event) {
    if (event is! PointerHoverEvent) return;
    final box = _trackerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    _cursorPos = box.globalToLocal(event.position);
    _updateTargetFromPosition(_cursorPos, box.size);
  }

  void _onPointerHover(PointerHoverEvent event, Size size) {
    _isInteracting = true;
    _cursorPos = event.localPosition;
    _updateTargetFromPosition(_cursorPos, size);
  }

  void _onPointerExit(PointerExitEvent event) {
    _isInteracting = false;
    _targetDeadzoneFactor = 1.0;
  }

  void _onPanStart(DragStartDetails details, Size size) {
    _isInteracting = true;
    _cursorPos = details.localPosition;
    _updateTargetFromPosition(_cursorPos, size);
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    _cursorPos = details.localPosition;
    _updateTargetFromPosition(_cursorPos, size);
  }

  void _onPanEnd(DragEndDetails details) {
    _isInteracting = false;
    _targetDeadzoneFactor = 1.0;
  }

  int _quantizeAxis(double value, int current) {
    return switch (current) {
      -1 => value > 0.2 ? 1 : value > -0.12 ? 0 : -1,
      1 => value < -0.2 ? -1 : value < 0.12 ? 0 : 1,
      _ => value < -0.2 ? -1 : value > 0.2 ? 1 : 0,
    };
  }

  _GazeDirection _directionFor(int horizontal, int vertical) {
    return switch ((horizontal, vertical)) {
      (-1, -1) => _GazeDirection.upperLeft,
      (0, -1) => _GazeDirection.up,
      (1, -1) => _GazeDirection.upperRight,
      (-1, 0) => _GazeDirection.left,
      (0, 0) => _GazeDirection.center,
      (1, 0) => _GazeDirection.right,
      (-1, 1) => _GazeDirection.lowerLeft,
      (0, 1) => _GazeDirection.down,
      (1, 1) => _GazeDirection.lowerRight,
      _ => _GazeDirection.center,
    };
  }

  void _resetGaze() {
    if (_gazeDirection == _GazeDirection.center &&
        _horizontalDirection == 0 &&
        _verticalDirection == 0) {
      return;
    }
    setState(() {
      _setNeutralGaze();
    });
  }

  void _setNeutralGaze() {
    _horizontalDirection = 0;
    _verticalDirection = 0;
    _gazeDirection = _GazeDirection.center;
    _isInEyeContact = false;
  }

  void _handleLaughAnimationStatus(AnimationStatus status) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final renderWidth = math.min(widget.width ?? 340.0, constraints.maxWidth);
        final renderHeight = widget.height ?? (renderWidth * (1024.0 / 682.0));
        final targetSize = Size(renderWidth, renderHeight);

        return Center(
          child: MouseRegion(
            onHover: (e) => _onPointerHover(e, targetSize),
            onExit: _onPointerExit,
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              onDoubleTap: widget.onDoubleTap,
              onPanStart: widget.enableTouchFallback
                  ? (d) => _onPanStart(d, targetSize)
                  : null,
              onPanUpdate: widget.enableTouchFallback
                  ? (d) => _onPanUpdate(d, targetSize)
                  : null,
              onPanEnd: widget.enableTouchFallback
                  ? (d) => _onPanEnd(d)
                  : null,
              child: _buildLoadedCharacter(context, renderWidth, renderHeight),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadedCharacter(BuildContext context, double width, double height) {
    final floatOffsetY = widget.enableIdleFloating && !_isInteracting
        ? math.sin(_idleTime) * 3.5
        : 0.0;

    final (int restIndex, int laughIndex) = _gazeFrameMap[_gazeDirection]!;

    final restingImage = restIndex > 0
        ? _pipGazeFrame(restIndex)
        : _pipImage(
            'assets/images/gayathri_character_transparent_git_original.png',
          );

    final laughAnimation = widget.laughAnimation;
    final image = laughAnimation == null
        ? restingImage
        : AnimatedBuilder(
            animation: laughAnimation,
            child: restingImage,
            builder: (context, child) {
              final isLaughing =
                  laughAnimation.status == AnimationStatus.forward ||
                  laughAnimation.status == AnimationStatus.reverse;
              if (!isLaughing) return child!;
              return _pipLaughImage(
                restIndex: restIndex,
                laughIndex: laughIndex,
                fallback: child!,
                progress: laughAnimation.value,
              );
            },
          );

    return SizedBox(
      key: _trackerKey,
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Transform.translate(
              offset: Offset(0, floatOffsetY),
              child: image,
            ),
          ),
          if (_currentDeadzoneFactor > 0.5)
            IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: (_currentDeadzoneFactor - 0.5) * 1.5,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, -0.20),
                      radius: 0.40,
                      colors: [
                        const Color(0xFFFFE082).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pipGazeFrame(int index) {
    const Map<int, String> gazeFrames = {
      1: 'assets/images/gayathri_gaze_transparent/frame_050.png',
      2: 'assets/images/gayathri_gaze_transparent/frame_065.png',
      3: 'assets/images/gayathri_gaze_transparent/frame_090.png',
      4: 'assets/images/gayathri_gaze_transparent/frame_110.png',
      5: 'assets/images/gayathri_gaze_transparent/frame_135.png',
      6: 'assets/images/gayathri_gaze_transparent/frame_170.png',
      7: 'assets/images/gayathri_gaze_transparent/frame_185.png',
      8: 'assets/images/gayathri_gaze_transparent/frame_220.png',
    };
    if (index >= 1 && index <= 8) {
      return _pipImage(gazeFrames[index]!);
    }
    return _pipImage(
      'assets/images/gayathri_character_transparent_git_original.png',
    );
  }

  Widget _pipImage(String assetName) {
    return Image.asset(
      assetName,
      width: widget.width ?? 320,
      height: widget.height ?? 570,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Text(
            'Could not load Gayathri frame.',
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Widget _pipLaughImage({
    required int restIndex,
    required int laughIndex,
    required Widget fallback,
    required double progress,
  }) {
    final frameNumber = _laughFrameNumbers[laughIndex];
    if (frameNumber == null) return fallback;

    final laughFrameName =
        'assets/images/gayathri_gaze_laugh_base/frame_${frameNumber.toString().padLeft(3, '0')}.png';

    return Stack(
      fit: StackFit.expand,
      children: [
        _pipImage(laughFrameName),
        CustomPaint(
          key: const ValueKey('pip-laugh-mouth'),
          painter: _PipLaughMouthPainter(frame: frameNumber, progress: progress),
        ),
      ],
    );
  }

  String? _laughFrameFor(int restIndex, int laughIndex) {
    if (laughIndex >= 9 && laughIndex <= 16) {
      return 'assets/images/gayathri_gaze_laugh_base/frame_${laughIndex.toString().padLeft(3, '0')}.png';
    }
    return null;
  }
}

class _PipLaughMouthPainter extends CustomPainter {
  final int frame;
  final double progress;

  const _PipLaughMouthPainter({required this.frame, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final pose = _mouthPoses[frame];
    if (pose == null) return;

    final openness = _mouthOpenness(progress);
    final scaleX = size.width / 720;
    final scaleY = size.height / 1280;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.translate(pose.$1, pose.$2);
    canvas.rotate(pose.$4);

    final halfWidth = pose.$3 / 2;
    const outlineColor = Color(0xFF594036);
    final outline = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (openness < 0.025) {
      final smile = Path()
        ..moveTo(-halfWidth, 0)
        ..quadraticBezierTo(0, 12, halfWidth, 0);
      canvas.drawPath(smile, outline);
    } else {
      final openHeight = 32 * openness;
      final mouth = Path()
        ..moveTo(-halfWidth, 0)
        ..quadraticBezierTo(0, 4, halfWidth, 0)
        ..quadraticBezierTo(0, openHeight * 1.5 + 2, -halfWidth, 0)
        ..close();
      canvas.drawPath(mouth, outline);

      if (openness > 0.38) {
        final tongue = Path()
          ..moveTo(-halfWidth * 0.48, openHeight * 0.92)
          ..quadraticBezierTo(0, openHeight * 1.28, halfWidth * 0.48, openHeight * 0.92)
          ..quadraticBezierTo(0, openHeight * 0.75, -halfWidth * 0.48, openHeight * 0.92)
          ..close();
        canvas.drawPath(
          tongue,
          Paint()..color = const Color(0xFFE89AA9)..style = PaintingStyle.fill,
        );
      }
    }

    canvas.restore();
  }

  double _mouthOpenness(double value) {
    const stages = [0.0, 0.18, 0.82, 0.32, 1.0, 0.24, 0.0];
    final scaled = value.clamp(0.0, 1.0) * (stages.length - 1).toDouble();
    final index = scaled.floor().clamp(0, stages.length - 2).toInt();
    final t = Curves.easeInOut.transform(scaled - index);
    return stages[index] + (stages[index + 1] - stages[index]) * t;
  }

  @override
  bool shouldRepaint(covariant _PipLaughMouthPainter oldDelegate) {
    return frame != oldDelegate.frame || progress != oldDelegate.progress;
  }

  static const _mouthPoses = <int, (double, double, double, double)>{
    50: (407.5, 540, 81, 0),
    65: (428.5, 522, 73, -0.04),
    90: (490, 553.5, 58, 0.08),
    110: (507.5, 602, 57, 0.08),
    135: (401, 614, 82, 0),
    170: (269.5, 602, 69, -0.06),
    185: (247, 592, 62, -0.04),
    200: (269.5, 551, 63, -0.03),
    220: (358.5, 581, 83, 0),
  };
}
