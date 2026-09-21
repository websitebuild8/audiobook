import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// A bounded glass surface; adaptive quality and system accessibility are
/// handled by the app's LiquidGlassWidgets scope.
class AppGlass extends StatelessWidget {
  const AppGlass({super.key, required this.child, this.radius = 28, this.tint});
  final Widget child;
  final double radius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      shape: LiquidRoundedRectangle(borderRadius: radius),
      quality: GlassQuality.standard,
      useOwnLayer: true,
      settings: LiquidGlassSettings(
        glassColor:
            tint ?? (dark ? const Color(0xB3173B36) : const Color(0xB3F1FAF5)),
        bodyMode: GlassBodyMode.clear,
        thickness: 12,
        blur: 8,
      ),
      child: child,
    );
  }
}
