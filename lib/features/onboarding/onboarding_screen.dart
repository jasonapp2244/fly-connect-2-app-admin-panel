import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/widgets/shared_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = const [
    _OnboardingData(
      image: 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=800',
      title: 'Embark on a Journey',
      subtitle: 'Connect with like-minded explorers for unforgettable adventures. Your next travel companion is just a click away',
    ),
    _OnboardingData(
      image: 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=800',
      title: 'Craft Your Journey',
      subtitle: 'Build your itinerary collaboratively with fellow travelers. Turn plans into unforgettable experiences together',
    ),
    _OnboardingData(
      image: 'https://images.unsplash.com/photo-1529139574466-a303027614b2?w=800',
      title: 'Seamless Connections',
      subtitle: 'Chat, plan, and explore effortlessly with your travel companions. Your next adventure begins with a simple message',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_seen', true);
      if (mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full screen page view
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _OnboardingPage(data: _pages[index]);
            },
          ),

          // Bottom controls overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
                top: 16,
              ),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentPage ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AppColors.dark
                              : AppColors.dark.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Next button
                  PrimaryButton(
                    label: _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                    onTap: _onNext,
                    backgroundColor: Colors.white,
                    textColor: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        Image.network(
          data.image,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) =>
              progress == null ? child : Container(color: AppColors.dark),
          errorBuilder: (ctx, error, stackTrace) => Container(
            color: AppColors.dark,
            child: const Center(
              child: Icon(Icons.flight_takeoff, color: AppColors.primary, size: 64),
            ),
          ),
        ),
        // Gradient overlay
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.onboardingOverlay,
          ),
        ),
        // Text content
        Positioned(
          bottom: size.height * 0.18,
          left: 24,
          right: 24,
          child: Column(
            children: [
              Text(
                data.title,
                style: AppTextStyles.h2.copyWith(color: AppColors.dark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                data.subtitle,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.dark),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnboardingData {
  final String image;
  final String title;
  final String subtitle;

  const _OnboardingData({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}
