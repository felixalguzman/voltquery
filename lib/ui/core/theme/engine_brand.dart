import 'package:flutter/widgets.dart';
import 'package:simple_icons/simple_icons.dart';

import '../../../domain/models/engine.dart';

/// Engine → brand glyph (simple_icons) + brand colour. One source for the
/// connections list rows and the new-connection dialog.
(IconData, Color) engineBrand(Engine engine) => switch (engine) {
      Engine.sqlite => (SimpleIcons.sqlite, const Color(0xFF56B6E0)),
      Engine.postgres => (SimpleIcons.postgresql, const Color(0xFF6699E6)),
      Engine.mysql => (SimpleIcons.mariadb, const Color(0xFF00A9CE)),
    };
