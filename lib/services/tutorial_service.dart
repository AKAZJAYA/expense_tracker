import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static final TutorialService instance = TutorialService._init();
  TutorialService._init();

  Future<bool> shouldShowTutorial(String screenName) async {
    final prefs = await SharedPreferences.getInstance();
    final tutorialShown = prefs.getBool('tutorial_shown') ?? false;
    final screenTutorialKey = 'tutorial_$screenName';
    final screenShown = prefs.getBool(screenTutorialKey) ?? false;

    return tutorialShown == false && screenShown == false;
  }

  Future<void> markTutorialShown(String screenName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_$screenName', true);

    // Mark overall tutorial as shown after first screen
    await prefs.setBool('tutorial_shown', true);
  }

  Future<void> resetTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('tutorial_')) {
        await prefs.remove(key);
      }
    }
  }

  static void showTutorialOverlay(
    BuildContext context, {
    required List<TutorialStep> steps,
    required VoidCallback onComplete,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => TutorialOverlay(
          steps: steps,
          onComplete: onComplete,
        ),
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final Offset? targetPosition;
  final Size? targetSize;
  final Alignment textAlignment;
  final IconData? icon;

  TutorialStep({
    required this.title,
    required this.description,
    this.targetPosition,
    this.targetSize,
    this.textAlignment = Alignment.bottomCenter,
    this.icon,
  });
}

class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      _controller.reverse().then((_) {
        setState(() => _currentStep++);
        _controller.forward();
      });
    } else {
      _controller.reverse().then((_) {
        Navigator.of(context).pop();
        widget.onComplete();
      });
    }
  }

  void _skipTutorial() {
    _controller.reverse().then((_) {
      Navigator.of(context).pop();
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.black.withOpacity(0.7),
      child: GestureDetector(
        onTap: _nextStep,
        child: Stack(
          children: [
            // Highlight area
            if (step.targetPosition != null && step.targetSize != null)
              CustomPaint(
                size: screenSize,
                painter: SpotlightPainter(
                  targetPosition: step.targetPosition!,
                  targetSize: step.targetSize!,
                ),
              ),

            // Tutorial content
            Positioned.fill(
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildTutorialContent(step),
                  ),
                ),
              ),
            ),

            // Skip button
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: TextButton(
                  onPressed: _skipTutorial,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                  child: const Text('SKIP'),
                ),
              ),
            ),

            // Progress indicator
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.steps.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentStep ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == _currentStep
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialContent(TutorialStep step) {
    return Align(
      alignment: step.textAlignment,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (step.icon != null) ...[
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF63B4A0).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    step.icon,
                    color: const Color(0xFF63B4A0),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF63B4A0),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                step.description,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Tap anywhere to continue',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.touch_app,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpotlightPainter extends CustomPainter {
  final Offset targetPosition;
  final Size targetSize;

  SpotlightPainter({
    required this.targetPosition,
    required this.targetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final spotlightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        targetPosition.dx - 8,
        targetPosition.dy - 8,
        targetSize.width + 16,
        targetSize.height + 16,
      ),
      const Radius.circular(12),
    );

    path.addRRect(spotlightRect);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw spotlight border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(spotlightRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
