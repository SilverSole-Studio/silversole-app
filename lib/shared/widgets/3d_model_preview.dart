// ignore_for_file: file_names — intentionally named 3d_model_preview.dart.
import 'package:flutter/material.dart';

/// Skeleton for the (future) real-time rotating 3D sole model.
///
/// For now it just renders the product image at a large size so the layout
/// reserves the space; later this widget will host an interactive 3D viewer
/// that the user can rotate. Sized as a fraction of the screen height
/// ([heightFactor], ~70% by default) so the "model" dominates the view.
class Model3DPreview extends StatelessWidget {
  const Model3DPreview({super.key, this.heightFactor = 0.4});

  /// Fraction of the screen height this preview occupies.
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * heightFactor;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.asset(
        'assets/images/silversole_full.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
