import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_travel_assistant/core/services/concierge_visibility_store.dart';
import 'package:ai_travel_assistant/features/ai_travel_assistant/routes/ai_travel_assistant_routes.dart';
import 'package:ai_travel_assistant/features/concierge_demo/presentation/pages/scenario_chat_page.dart';
import 'package:ai_travel_assistant/features/concierge_demo/presentation/widgets/concierge_moments_list.dart';
import 'package:ai_travel_assistant/features/settings/presentation/pages/more_page.dart';

const _veloNavy = Color(0xFF082340);
const _veloOrange = Color(0xFFFF8D28);
const _veloAccentRed = Color(0xFFFF5C44);

/// Home/landing screen for the host app: a hero destination banner, a
/// "VeloSky" loyalty promo stack, and a floating chat launcher that opens
/// the AI Travel Assistant.
class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  static const _heroImageUrl = 'assets/images/LandingPage_BG.png';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conciergeVisible = ref.watch(conciergeVisibilityStoreProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const _HeroSection(imageUrl: LandingPage._heroImageUrl),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          const _GreetingHeader(name: 'Joe'),
                          const SizedBox(height: 16),
                          const _VeloSkyPassCard(),
                          const SizedBox(height: 16),
                          const _VeloMilesOfferCard(),
                          const SizedBox(height: 16),
                          const _PromoCarousel(),
                          const SizedBox(height: 24),
                          if (conciergeVisible)
                            ConciergeMomentsList(
                              onSelected: (scenario) =>
                                  Navigator.of(context).push(
                                ScenarioChatPage.route(scenario),
                              ),
                            )
                          else
                            const _ConciergeHiddenNotice(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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

class _ConciergeHiddenNotice extends StatelessWidget {
  const _ConciergeHiddenNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Concierge moments are hidden. Turn them back on from the More tab.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey.shade600),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 330,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
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
          Positioned(
            top: 60,
            right: 16,
            child: Container(
              width: 96,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD8EAFF).withOpacity(0.75),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeroIconButton(assetPath: 'assets/icons/chat_icon.png'),
                  SizedBox(width: 16),
                  _HeroIconButton(
                      assetPath: 'assets/icons/notifications_icon.png'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({this.icon, this.assetPath});

  final IconData? icon;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.00),
        shape: BoxShape.circle,
      ),
      child: assetPath != null
          ? Image.asset(
              assetPath!,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            )
          : Icon(icon, size: 20, color: _veloNavy),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Hi, $name',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
    );
  }
}

class _VeloSkyPassCard extends StatelessWidget {
  const _VeloSkyPassCard();

  static const _bullets = [
    (
      iconPath: 'assets/icons/Icons_1.png',
      label: 'Stress-free flight management.'
    ),
    (iconPath: 'assets/icons/Icons_2.png', label: 'Earn free flights.'),
    (iconPath: 'assets/icons/Icons_3.png', label: 'Members-only discounts.'),
    (iconPath: 'assets/icons/Icons_4.png', label: 'Priority Group 6 boarding.'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.center,
            end: Alignment.centerRight,
            colors: [Colors.white, Color(0xFFADD3FF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 10,
              bottom: 100,
              child: Opacity(
                opacity: 1,
                child: Image.asset(
                  'assets/icons/App_logo.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _veloNavy,
                          ),
                      children: const [
                        TextSpan(
                            text: 'Fly Smarter with ',
                            style: TextStyle(color: _veloNavy)),
                        TextSpan(
                            text: 'Velo', style: TextStyle(color: _veloNavy)),
                        TextSpan(
                            text: 'Sky',
                            style: TextStyle(color: _veloAccentRed)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final bullet in _bullets) ...[
                    _VeloSkyBulletRow(
                        iconPath: bullet.iconPath, label: bullet.label),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _veloOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Claim Your VeloSky Pass',
                        style: TextStyle(fontWeight: FontWeight.w600),
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
}

class _VeloSkyBulletRow extends StatelessWidget {
  const _VeloSkyBulletRow({required this.iconPath, required this.label});

  final String iconPath;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _veloNavy.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: Image.asset(
                iconPath,
                width: 14,
                height: 14,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.image_not_supported_outlined,
                    size: 15,
                    color: _veloNavy),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF1E1E1E),
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _VeloMilesOfferCard extends StatelessWidget {
  const _VeloMilesOfferCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: _veloNavy,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 18,
                            height: 1.25,
                            letterSpacing: 0.0,
                          ),
                      children: const [
                        TextSpan(text: 'Earn 80,000 Velo'),
                        TextSpan(
                            text: 'Miles',
                            style: TextStyle(
                              color: _veloAccentRed,
                              fontWeight: FontWeight.w700,
                            )),
                        TextSpan(text: '\nfor a limited time'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Unlock exclusive member rewards, priority boarding, and free flight benefits on eligible bookings.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          height: 1.3,
                          letterSpacing: 0.0,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Learn more',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6EA8FF),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward,
                          size: 16, color: Color(0xFF6EA8FF)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            const Center(
              child: _MembershipCardGraphic(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipCardGraphic extends StatelessWidget {
  const _MembershipCardGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 121,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/images/MemberShipCard.png',
          width: 100,
          height: 121,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 100,
            height: 121,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }
}

class _PromoCarousel extends StatelessWidget {
  const _PromoCarousel();

  static const _cards = [
    (
      title: 'Turn everyday spending into unforgettable journeys',
      body:
          'Earn up to 20,000 VeloMiles and unlock exclusive travel rewards. Limited-time offer.',
      imagePath: 'assets/images/Promo1.png',
      colors: [Color(0xFF6B5643), Color(0xFF2E2A26)],
    ),
    (
      title: 'Your next adventure is closer than you think',
      body:
          'Earn VeloMiles toward unforgettable vacations with every trip you book.',
      imagePath: 'assets/images/Promo2.png',
      colors: [Color(0xFF3E5C76), Color(0xFF1B2A3A)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _cards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final card = _cards[index];
          return _PromoCard(
            title: card.title,
            body: card.body,
            imagePath: card.imagePath,
            colors: card.colors,
          );
        },
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.title,
    required this.body,
    required this.imagePath,
    required this.colors,
  });

  final String title;
  final String body;
  final String imagePath;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 332,
        height: 295,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(1.0),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      colors.first.withOpacity(0.01),
                      colors.last.withOpacity(0.45),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, height: 1.3),
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
}

class _ChatLauncherButton extends StatelessWidget {
  const _ChatLauncherButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: FloatingActionButton(
        heroTag: 'ai-assistant-launcher',
        backgroundColor: const Color(0xFF0883F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onPressed: onPressed,
        child: Image.asset(
          'assets/icons/chatbot_icon.png',
          width: 36,
          height: 36,
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
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              const Expanded(
                child: _NavItem(
                    iconPath: 'assets/icons/home_icon.png',
                    label: 'Home',
                    selected: true),
              ),
              const Expanded(
                  child: _NavItem(
                      iconPath: 'assets/icons/book_icon.png', label: 'Book')),
              const Expanded(
                  child: _NavItem(
                      iconPath: 'assets/icons/trips_icon.png', label: 'Trips')),
              const Expanded(
                child: _NavItem(
                    icon: Icons.auto_awesome_outlined, label: 'VeloSky'),
              ),
              Expanded(
                child: _NavItem(
                  iconPath: 'assets/icons/more_icon.png',
                  label: 'More',
                  onTap: () => Navigator.of(context).push(MorePage.route()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {this.iconPath,
      this.icon,
      required this.label,
      this.selected = false,
      this.onTap})
      : assert(iconPath != null || icon != null,
            'Provide either iconPath or icon');

  final String? iconPath;
  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade600;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (iconPath != null)
            Image.asset(
              iconPath!,
              width: 22,
              height: 22,
              color: color,
              colorBlendMode: BlendMode.srcIn,
            )
          else
            Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
