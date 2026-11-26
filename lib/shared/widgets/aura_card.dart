import 'package:flutter/material.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_dimensions.dart';

class AuraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AuraCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AuraThemeTokens.of(context);
    final radius = borderRadius ?? AuraDimensions.radiusLarge;
    final bg = backgroundColor ?? tokens.card;
    final border = borderColor ??
        (tokens.isDark
            ? tokens.divider.withValues(alpha: 0.75)
            : tokens.divider);

    final inner =
        padding != null ? Padding(padding: padding!, child: child) : child;

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: tokens.isDark
            ? null
            : [
                BoxShadow(
                  color: AuraColors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: inner,
              )
            : inner,
      ),
    );
  }
}
