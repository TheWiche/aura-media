import 'package:flutter/material.dart';

class AuraDimensions {
  AuraDimensions._();

  // Border radius
  static const radiusSmall = BorderRadius.all(Radius.circular(10));
  static const radiusMedium = BorderRadius.all(Radius.circular(14));
  static const radiusLarge = BorderRadius.all(Radius.circular(18));
  static const radiusExtraLarge = BorderRadius.all(Radius.circular(24));
  static const radiusFull = BorderRadius.all(Radius.circular(100));

  // Spacing (multiples of 4)
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;

  // Components
  static const double buttonHeight = 54;
  static const double inputHeight = 54;
  static const double navigationHeight = 76;
  static const double iconSize = 24;
  static const double smallIconSize = 20;

  // Elevation
  static const double cardElevation = 1;
  static const double modalElevation = 8;
}
