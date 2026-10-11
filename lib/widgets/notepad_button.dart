import 'package:flutter/material.dart';

import '../models/app_language.dart';
import '../models/notepad_stroke.dart';
import '../utils/constants.dart';
import 'notepad_painter.dart';

/// A small icon button that opens a 5-page scratch-drawing notepad for
/// rough work. Opens as a bottom sheet covering half the screen (not
/// full-screen) so the question stays visible above it while the player
/// works — the whole point is doing rough work while still seeing the
/// problem.
///
/// Owns its own open/closed state and all 5 pages' stroke data
/// internally, so it drops into `game_screen.dart`'s layout as a single
/// leaf widget without requiring the surrounding screen to become
/// stateful just for this. Scratch space only: strokes live purely in
/// this State object's memory for the lifetime of this one GameScreen
/// session (Play/Daily Challenge/Age-Group Test alike) — never written
/// to StorageService, never read back, and discarded once the session
/// ends (a fresh NotepadButton is created for the next one).
class NotepadButton extends StatefulWidget {
  const NotepadButton({super.key, required this.language});

  final AppLanguage language;

  @override
  State<NotepadButton> createState() => NotepadButtonState();
}

class NotepadButtonState extends State<NotepadButton> {
  static const int pageCount = 5;

  // Mutated in place rather than replaced, so strokes drawn before the
  // sheet is closed are still there if the player reopens it within the
  // same session (the sheet itself is torn down/rebuilt each open, this
  // list is not).
  final List<List<NotepadStroke>> _pages =
      List.generate(pageCount, (_) => <NotepadStroke>[]);
  int _currentPage = 0;

  void _open() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // The sheet's own default drag-to-dismiss gesture would otherwise
      // compete with (and win over) the canvas's own pan-to-draw gesture
      // for any downward stroke — dismissal already has an explicit
      // close "✕" button, so this isn't needed and only gets in the way
      // of drawing.
      enableDrag: false,
      // Half the screen, not full — the question stays visible above.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      builder: (context) => _NotepadSheet(
        language: widget.language,
        pages: _pages,
        initialPage: _currentPage,
        onPageChanged: (i) => _currentPage = i,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Shrunk well below IconButton's default 48dp Material tap target —
    // the Play screen is already tightly packed (banner ad + marks bar +
    // timer + question + options all compete for space), so this small
    // trigger icon shouldn't cost a visually heavy row of its own.
    return IconButton(
      tooltip: _t(widget.language, 'Scratch notepad', 'स्क्रैच नोटपैड'),
      icon: const Icon(Icons.edit_note),
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: _open,
    );
  }
}

class _NotepadSheet extends StatefulWidget {
  const _NotepadSheet({
    required this.language,
    required this.pages,
    required this.initialPage,
    required this.onPageChanged,
  });

  final AppLanguage language;
  final List<List<NotepadStroke>> pages;
  final int initialPage;
  final ValueChanged<int> onPageChanged;

  @override
  State<_NotepadSheet> createState() => _NotepadSheetState();
}

class _NotepadSheetState extends State<_NotepadSheet> {
  late int _pageIndex = widget.initialPage;
  late final PageController _pageController =
      PageController(initialPage: _pageIndex);
  NotepadStroke? _activeStroke;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _activeStroke = NotepadStroke([details.localPosition]);
      widget.pages[_pageIndex].add(_activeStroke!);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _activeStroke!.points.add(details.localPosition));
  }

  void _onPanEnd(DragEndDetails details) => _activeStroke = null;

  void _clearPage() => setState(() => widget.pages[_pageIndex].clear());

  @override
  Widget build(BuildContext context) {
    final language = widget.language;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Text(
                  _t(language, 'Scratch Notepad', 'स्क्रैच नोटपैड'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${_pageIndex + 1}/${widget.pages.length}',
                  style: const TextStyle(color: AppColors.neutral),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _t(language, 'Clear page', 'पेज साफ़ करें'),
                  icon: const Icon(Icons.layers_clear_outlined),
                  onPressed: _clearPage,
                ),
                // The close "✕", pinned to this row's own top-right
                // corner by simply being the last element in it.
                IconButton(
                  tooltip: _t(language, 'Close', 'बंद करें'),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.silver),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              // Swipe-to-flip would otherwise compete with the drawing
              // gesture below in the same gesture arena — a horizontal
              // pan could get claimed by the page-swipe recognizer
              // mid-stroke instead of the canvas. Page navigation is
              // already fully covered by the explicit prev/next arrows
              // below, so disabling swipe here makes drawing reliably
              // win every time instead of competing for it.
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.pages.length,
              onPageChanged: (i) {
                setState(() => _pageIndex = i);
                widget.onPageChanged(i);
              },
              itemBuilder: (context, i) => GestureDetector(
                // Keyed per page so tests can target a specific page's
                // drawing surface directly, rather than relying on
                // find.byType(CustomPaint).first (ambiguous — other
                // CustomPaints exist elsewhere in the widget tree, e.g.
                // from Material ripple effects).
                key: ValueKey('notepad-canvas-$i'),
                // A bare CustomPaint with no child doesn't claim any
                // hit-testable area of its own, so GestureDetector's
                // default HitTestBehavior.deferToChild would silently
                // never receive a pan here — opaque makes the whole
                // canvas area respond, not just wherever ink already is.
                behavior: HitTestBehavior.opaque,
                onPanStart: i == _pageIndex ? _onPanStart : null,
                onPanUpdate: i == _pageIndex ? _onPanUpdate : null,
                onPanEnd: i == _pageIndex ? _onPanEnd : null,
                child: ClipRect(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: NotepadPainter(widget.pages[i]),
                  ),
                ),
              ),
            ),
          ),
          // An explicit, discoverable way to move through all 5 pages —
          // not swipe-only — so a player can spread rough work across
          // more than one page without relying on a blind gesture.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: _t(language, 'Previous page', 'पिछला पेज'),
                  icon: const Icon(Icons.chevron_left),
                  onPressed:
                      _pageIndex > 0 ? () => _goToPage(_pageIndex - 1) : null,
                ),
                for (var i = 0; i < widget.pages.length; i++)
                  _PageDot(selected: i == _pageIndex),
                IconButton(
                  tooltip: _t(language, 'Next page', 'अगला पेज'),
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _pageIndex < widget.pages.length - 1
                      ? () => _goToPage(_pageIndex + 1)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDot extends StatelessWidget {
  const _PageDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : AppColors.silver,
      ),
    );
  }
}

/// Picks [en] or [hi] depending on [language] — same tiny helper every
/// other screen/widget in this app duplicates locally rather than
/// sharing, per the house convention (see e.g. game_screen.dart's own
/// `_t`).
String _t(AppLanguage language, String en, String hi) =>
    language == AppLanguage.english ? en : hi;
