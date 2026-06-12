import 'package:flutter/material.dart';
import 'package:silversole/core/utils/useful_extension.dart';

/// Text painted with the brand blue→cyan gradient (DESIGN.md hero highlight).
///
/// Defaults to `displaySmall`; pass [style] to match the surrounding text.
class BrandGradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const BrandGradientText(this.text, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: context.tokens.brandGradient,
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    final baseStyle = (style ?? context.tt.displaySmall) ?? const TextStyle();
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        textAlign: textAlign,
        // Color is replaced by the shader; white keeps full gradient opacity.
        style: baseStyle.copyWith(color: Colors.white),
      ),
    );
  }
}
