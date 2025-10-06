import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

// Created a global logger instance
final Logger _logger = Logger();

class AnimatedHeader extends StatefulWidget {
  final String title;
  final String subtitle;
  final String logoAssetPath;
  final Size screenSize;
  final bool isLandscape;

  const AnimatedHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.logoAssetPath = 'assets/logos/blyft_logo.png',
    required this.screenSize,
    this.isLandscape = false,
  });

  @override
  State<AnimatedHeader> createState() => _AnimatedHeaderState();
}

class _AnimatedHeaderState extends State<AnimatedHeader> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _pulseController;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _logger.i('initState called - ANIMATED_HEADER');

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _pulseController.repeat(reverse: true);

    // Start entrance animations
    Future.delayed(const Duration(milliseconds: 160), () {
      _logger.d('Starting fade animation - ANIMATED_HEADER');
      _fadeController.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _logger.d('Starting slide animation - ANIMATED_HEADER');
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _logger.i('dispose called - ANIMATED_HEADER');
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.i('Build method started - ANIMATED_HEADER');

    final headerH = widget.isLandscape ? widget.screenSize.height * 0.8 : widget.screenSize.height * 0.28;

    _logger.d('Header height calculated: $headerH, isLandscape: ${widget.isLandscape} - ANIMATED_HEADER');

    return SizedBox(
      height: headerH,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) {
                    return Transform.scale(
                      scale: _pulseAnim.value,
                      child: GestureDetector(
                        onTap: () {
                          _logger.i('Logo tapped - ANIMATED_HEADER');
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF3D4DFF).withAlpha((0.2 * 255).toInt()),
                                const Color(0xFF29C0FF).withAlpha((0.1 * 255).toInt()),
                              ],
                            ),
                            border: Border.all(color: const Color(0xFF3D4DFF).withAlpha((0.3 * 255).toInt()), width: 1),
                          ),
                          child: Image.asset(
                            widget.logoAssetPath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) {
                              _logger.w('Logo failed to load, showing fallback icon - ANIMATED_HEADER');
                              return const Center(child: Icon(Icons.flash_on_rounded, color: Colors.white, size: 36));
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    _logger.i('Title tapped: ${widget.title} - ANIMATED_HEADER');
                  },
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    _logger.i('Subtitle tapped: ${widget.subtitle} - ANIMATED_HEADER');
                  },
                  child: Text(
                    widget.subtitle,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF9AA8BF), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

