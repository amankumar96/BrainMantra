import 'package:flutter/material.dart';

/// One continuous finger-drag on the scratch notepad — a sequence of
/// points sampled from pan events. A notepad page is a list of these.
/// Deliberately in-memory only (see `NotepadButton`'s doc comment) —
/// never persisted, since the notepad is scratch space, not a saved
/// document.
class NotepadStroke {
  NotepadStroke(this.points);

  final List<Offset> points;
}
