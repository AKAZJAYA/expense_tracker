import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Say hi to your new\nfinance tracker',
      description:
          'You\'re amazing for taking this first step towards getting better control over your money and financial goals.',
      illustration: OnboardingIllustration.welcome,
      buttonText: 'GET STARTED',
    ),
    OnboardingData(
      title: 'Control your spend and\nstart saving',
      description:
          'Monefy helps you control your spending, track your expenses, and ultimately save more money.',
      illustration: OnboardingIllustration.saving,
      buttonText: 'AMAZING',
    ),
    OnboardingData(
      title: 'Together we\'ll reach your\nfinancial goals',
      description:
          'If you fail to plan, you plan to fail. Monefy will help you stay focused on tracking your spend and reach your financial goals.',
      illustration: OnboardingIllustration.goals,
      buttonText: 'I\'M READY',
    ),
  ];

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _onButtonPressed() async {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Mark onboarding as completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstLaunch', false);

      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF63B4A0),
      body: SafeArea(
        child: Column(
          children: [
            // App Store back button
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white.withOpacity(0.8),
                      size: 16,
                    ),
                    Text(
                      'App Store',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildDot(index),
                ),
              ),
            ),

            // Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF63B4A0),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _pages[_currentPage].buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
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

  Widget _buildPage(OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Illustration
          _buildIllustration(data.illustration),

          const SizedBox(height: 60),

          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildIllustration(OnboardingIllustration type) {
    switch (type) {
      case OnboardingIllustration.welcome:
        return _buildWelcomeIllustration();
      case OnboardingIllustration.saving:
        return _buildSavingIllustration();
      case OnboardingIllustration.goals:
        return _buildGoalsIllustration();
    }
  }

  Widget _buildWelcomeIllustration() {
    return Container(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xFF4A9985),
              shape: BoxShape.circle,
            ),
          ),

          // Person meditating
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Head
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF2C5F6F),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),

              // Body
              Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                ),
              ),

              // Legs
              Container(
                width: 140,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF2C3E50),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(70),
                  ),
                ),
              ),
            ],
          ),

          // Floating books - left
          Positioned(
            left: 20,
            top: 100,
            child: Transform.rotate(
              angle: -0.3,
              child: Container(
                width: 60,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A7C8F),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // Floating books - right
          Positioned(
            right: 20,
            top: 100,
            child: Transform.rotate(
              angle: 0.3,
              child: Container(
                width: 60,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A7C8F),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // Plant
          Positioned(
            left: 40,
            bottom: 40,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A7C59),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(40),
                    ),
                  ),
                ),
                Container(
                  width: 50,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingIllustration() {
    return Container(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Piggy bank
          Container(
            width: 200,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.pink.shade100,
              borderRadius: BorderRadius.circular(100),
            ),
          ),

          // Snout
          Positioned(
            right: 120,
            child: Container(
              width: 60,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),

          // Ears
          Positioned(
            top: 50,
            left: 100,
            child: Container(
              width: 40,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
            ),
          ),

          Positioned(
            top: 50,
            right: 100,
            child: Container(
              width: 40,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
            ),
          ),

          // Tail
          Positioned(
            left: 110,
            top: 120,
            child: Transform.rotate(
              angle: -0.5,
              child: Container(
                width: 12,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.pink.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // Coins
          Positioned(
            top: 20,
            right: 130,
            child: _buildCoin(30, Colors.amber.shade300),
          ),
          Positioned(
            top: 10,
            right: 100,
            child: _buildCoin(25, Colors.amber.shade400),
          ),
          Positioned(
            top: 0,
            right: 115,
            child: _buildCoin(28, Colors.amber.shade500),
          ),

          // Shadow
          Positioned(
            bottom: -20,
            child: Container(
              width: 220,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4A9985).withOpacity(0.3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsIllustration() {
    return Container(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Mountains
          Positioned(
            bottom: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Back mountain
                CustomPaint(
                  size: const Size(120, 100),
                  painter: MountainPainter(const Color(0xFF5A8B7C)),
                ),

                // Front mountain with flag
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    CustomPaint(
                      size: const Size(150, 130),
                      painter: MountainPainter(const Color(0xFF4A7C6D)),
                    ),

                    // Peak snow
                    Positioned(
                      top: 0,
                      child: Container(
                        width: 100,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(50),
                            topRight: Radius.circular(50),
                          ),
                        ),
                      ),
                    ),

                    // Happy face on mountain
                    Positioned(
                      top: 35,
                      child: Column(
                        children: [
                          // Eyes
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2C5F6F),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(3)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 8,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2C5F6F),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(3)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Smile
                          Container(
                            width: 30,
                            height: 15,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFF2C5F6F),
                                  width: 3,
                                ),
                              ),
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Flag pole
                    Positioned(
                      top: -10,
                      child: Container(
                        width: 3,
                        height: 60,
                        color: const Color(0xFF5A7C8F),
                      ),
                    ),

                    // Flag
                    Positioned(
                      top: -8,
                      left: 78,
                      child: ClipPath(
                        clipper: FlagClipper(),
                        child: Container(
                          width: 30,
                          height: 25,
                          color: Colors.amber.shade400,
                        ),
                      ),
                    ),
                  ],
                ),

                // Back mountain
                CustomPaint(
                  size: const Size(100, 90),
                  painter: MountainPainter(const Color(0xFF5A8B7C)),
                ),
              ],
            ),
          ),

          // Clouds
          Positioned(
            left: 30,
            top: 80,
            child: _buildCloud(60, 35),
          ),
          Positioned(
            right: 150,
            top: 100,
            child: _buildCloud(70, 40),
          ),

          // Shadow
          Positioned(
            bottom: 40,
            child: Container(
              width: 300,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF4A9985).withOpacity(0.2),
                borderRadius: BorderRadius.circular(150),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoin(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildCloud(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(50),
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? Colors.white
            : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// Custom painter for mountains
class MountainPainter extends CustomPainter {
  final Color color;

  MountainPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom clipper for flag
class FlagClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Data class for onboarding pages
class OnboardingData {
  final String title;
  final String description;
  final OnboardingIllustration illustration;
  final String buttonText;

  OnboardingData({
    required this.title,
    required this.description,
    required this.illustration,
    required this.buttonText,
  });
}

enum OnboardingIllustration {
  welcome,
  saving,
  goals,
}
