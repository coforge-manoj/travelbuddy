import 'package:flutter/material.dart';

import 'package:ai_travel_assistant/features/ai_travel_assistant/routes/ai_travel_assistant_routes.dart';

/// Home/landing screen for the host app: a hero destination banner with a
/// traveler summary card overlaid on it, quick navigation tabs, and a
/// floating chat launcher that opens the AI Travel Assistant.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const _heroImageUrl = 'assets/images/LandingPage_BG.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroSection(imageUrl: LandingPage._heroImageUrl),
              Expanded(child: SizedBox.shrink()),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 24,
            child: _ChatLauncherButton(
              onPressed: () => Navigator.of(context).push(
                AiTravelAssistantEntryPoint.route(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _HomeBottomNavBar(),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 330,
          width: double.infinity,
          child: Image.asset(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF90B4D6), Color(0xFF2E8C7F)],
                ),
              ),
            ),
          ),
        ),
        const _TravelerSummaryCard(),
      ],
    );
  }
}

class _TravelerSummaryCard extends StatelessWidget {
  const _TravelerSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: SizedBox(
        width: 416,
        height: 150,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: const Color(0xFF3C4E5F),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.flight, color: Colors.white70),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Joe Traveler',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  letterSpacing: 0.15,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AAdvantage Executive Platinum®',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '#TB48213',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: const Color(0xFF283747),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_airport_outlined, color: Colors.white70, size: 12),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AAdvantage® miles: 400,000',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.stars_outlined, color: Colors.white70, size: 12),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Loyalty Points: 215,000',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatLauncherButton extends StatelessWidget {
  const _ChatLauncherButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        heroTag: 'ai-assistant-launcher',
        backgroundColor: const Color(0xFF0883F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onPressed: onPressed,
        child: Image.asset(
          'assets/icons/chatbot_icon.png',
          width: 24,
          height: 24,
        ),
      ),
    );
  }
}

class _HomeBottomNavBar extends StatelessWidget {
  const _HomeBottomNavBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            offset: Offset(0, -3),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: const SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(child: _NavItem(iconPath: 'assets/icons/home_icon.png', label: 'Home', selected: true)),
              Expanded(child: _NavItem(iconPath: 'assets/icons/book_icon.png', label: 'Book')),
              Expanded(child: _NavItem(iconPath: 'assets/icons/trips_icon.png', label: 'Trips')),
              Expanded(child: _NavItem(iconPath: 'assets/icons/aadvantage_icon.png', label: 'AAdvantage®')),
              Expanded(child: _NavItem(iconPath: 'assets/icons/more_icon.png', label: 'More')),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.iconPath, required this.label, this.selected = false});

  final String iconPath;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade600;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          iconPath,
          width: 22,
          height: 22,
          color: color,
          colorBlendMode: BlendMode.srcIn,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
