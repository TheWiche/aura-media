import 'package:flutter/material.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_dimensions.dart';

class AuraProgress extends StatelessWidget {
  final double? value;
  final Color? color;
  final double height;

  const AuraProgress({
    super.key,
    this.value,
    this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AuraThemeTokens.of(context);

    return ClipRRect(
      borderRadius: AuraDimensions.radiusFull,
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: tokens.progressTrack,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? tokens.primary),
      ),
    );
  }
}
