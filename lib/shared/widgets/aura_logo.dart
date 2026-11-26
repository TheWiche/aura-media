import 'package:flutter/material.dart';
import '../../core/theme/aura_colors.dart';

/// Dynamic Aura brand mark whose 3D ribbon adopts the active theme accent color
/// while preserving fold depth and keeping the inner play triangle legible.
class AuraLogo extends StatelessWidget {
  final double size;
  final Color? accentColor;

  const AuraLogo({
    super.key,
    this.size = 28,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AuraThemeTokens.of(context);
    final tint = accentColor ?? tokens.primary;
    final playTint = tokens.isDark ? AuraColors.white : const Color(0xFF1E1E24);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/icon/aura_logo_ribbon.png',
            fit: BoxFit.contain,
            color: tint,
            colorBlendMode: BlendMode.modulate,
            gaplessPlayback: true,
          ),
          Image.asset(
            'assets/icon/aura_logo_play.png',
            fit: BoxFit.contain,
            color: playTint,
            colorBlendMode: BlendMode.modulate,
            gaplessPlayback: true,
          ),
        ],
      ),
    );
  }
}
