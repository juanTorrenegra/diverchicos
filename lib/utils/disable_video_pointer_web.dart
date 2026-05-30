import 'package:web/web.dart' as web;

/// Lets Flutter widgets receive drags/taps over a paused intro video on web.
void disableVideoPointerEvents() {
  final videos = web.document.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    final node = videos.item(i);
    if (node is web.HTMLVideoElement) {
      node.style.pointerEvents = 'none';
      _disablePointerOnPlatformViewAncestors(node);
    }
  }
}

/// Clears pointer-event overrides applied by [disableVideoPointerEvents].
/// Call when tearing down a game layer so the menu stays interactive.
void restoreAppPointerEvents() {
  final videos = web.document.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    final node = videos.item(i);
    if (node is web.HTMLElement) {
      node.style.pointerEvents = '';
    }
  }

  final slots = web.document.querySelectorAll('[id^="flutter-view-"]');
  for (var i = 0; i < slots.length; i++) {
    final slot = slots.item(i);
    if (slot is web.HTMLElement) {
      slot.style.pointerEvents = '';
    }
  }
}

void _disablePointerOnPlatformViewAncestors(web.HTMLVideoElement video) {
  var parent = video.parentElement;
  var depth = 0;
  while (parent != null && depth < 12) {
    final tag = parent.tagName;
    if (tag == 'FLUTTER-VIEW' || tag == 'BODY') break;
    if (parent is web.HTMLElement) {
      parent.style.pointerEvents = 'none';
    }
    parent = parent.parentElement;
    depth++;
  }
}
