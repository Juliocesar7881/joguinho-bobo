import 'package:flutter/material.dart';

import '../domain/models.dart';

String wordLengthRouteName(GameMode mode) => '/${mode.id}/word-lengths';

Route<T> fastRoute<T>(Widget child, {String? name}) {
  return PageRouteBuilder<T>(
    settings: name == null ? null : RouteSettings(name: name),
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, animation, _) => child,
    transitionsBuilder: (_, animation, _, page) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: page,
    ),
  );
}
