import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:multicrop2/auth/login_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseScaleAnimation;

  late AnimationController _rotateController;
  late Animation<double> _rotateAnimation;

  String displayedText = "";
  final String fullText = "MultiCrop";
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );

    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseScaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotate animation
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.05).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );

    // Start animations
    _entranceController.forward().then((_) {
      _pulseController.repeat(reverse: true);
      _rotateController.repeat(reverse: true);
      _startTypingAnimation();
    });

    _navigateToLogin();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFC8E6C9),
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  void _startTypingAnimation() {
    Future.delayed(const Duration(milliseconds: 200), () {
      _typeNextLetter();
    });
  }

  void _typeNextLetter() {
    if (currentIndex < fullText.length && mounted) {
      setState(() {
        displayedText += fullText[currentIndex];
        currentIndex++;
      });

      Future.delayed(const Duration(milliseconds: 150), () {
        _typeNextLetter();
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(milliseconds: 7000));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryLightGreen = Color(0xFFE8F9EE);
    const Color secondaryMidGreen = Color(0xFFC8E6C9);
    const Color iconColor = Color(0xFF388E3C);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryLightGreen, secondaryMidGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Animated background circles
            _buildBackgroundCircles(),

            // Main content
            Center(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _opacityAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated logo
                      AnimatedBuilder(
                        animation:
                            Listenable.merge([_pulseScaleAnimation, _rotateAnimation]),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseScaleAnimation.value,
                            child: Transform.rotate(
                              angle: _rotateAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: iconColor.withOpacity(0.3),
                                      blurRadius: 30,
                                      offset: const Offset(0, 12),
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: SvgPicture.asset(
                                  'lib/assets/tree_palm.svg',
                                  colorFilter: const ColorFilter.mode(
                                    iconColor,
                                    BlendMode.srcIn,
                                  ),
                                  width: 90,
                                  height: 90,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 40),

                      // Animated app name with typing effect
                      SizedBox(
                        height: 50,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayedText,
                              style: const TextStyle(
                                fontFamily: 'Satisfy',
                                fontSize: 42,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1B5E20),
                                letterSpacing: 1.5,
                              ),
                            ),
                            if (displayedText.length < fullText.length)
                              Container(
                                width: 3,
                                height: 35,
                                margin: const EdgeInsets.only(left: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF388E3C),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: AnimatedOpacity(
                                  opacity: currentIndex % 2 == 0 ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 500),
                                  child: Container(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tagline with fade-in
                      AnimatedOpacity(
                        opacity: displayedText.length == fullText.length ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 800),
                        child: const Text(
                          "Cultivating precision, one tree at a time.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 60),

                      // Loading indicator with custom animation
                      AnimatedOpacity(
                        opacity: displayedText.length == fullText.length ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 600),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: const Color(0xFF66BB6A),
                                strokeWidth: 4,
                                backgroundColor: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Loading...",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black45,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Decorative animated background circles
  Widget _buildBackgroundCircles() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Opacity(
                opacity: 0.1 * _pulseScaleAnimation.value,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: const BoxDecoration(
                    color: Color(0xFF388E3C),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: -80,
          left: -80,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Opacity(
                opacity: 0.08 * (2 - _pulseScaleAnimation.value),
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: const BoxDecoration(
                    color: Color(0xFF66BB6A),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}