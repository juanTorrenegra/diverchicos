import 'package:web/web.dart' as web;

/// Elements whose `pointer-events` style was changed by [disableVideoPointerEvents].
final List<web.HTMLElement> _pointerCaptureOverrides = <web.HTMLElement>[];

void _setPointerEventsNone(web.HTMLElement element) {
  if (element.style.pointerEvents == 'none') return;
  _pointerCaptureOverrides.add(element);
  element.style.pointerEvents = 'none';
}

/// Lets Flutter widgets receive drags/taps over a paused intro video on web.
void disableVideoPointerEvents() {
  final videos = web.document.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    final node = videos.item(i);
    if (node is web.HTMLVideoElement) {
      _setPointerEventsNone(node);
      _disablePointerOnPlatformViewAncestors(node);
    }
  }
}

/// Clears pointer-event overrides applied by [disableVideoPointerEvents].
/// Call when tearing down a game layer so the menu stays interactive.
void restoreAppPointerEvents() {
  for (final element in _pointerCaptureOverrides) {
    element.style.pointerEvents = '';
  }
  _pointerCaptureOverrides.clear();

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
      _setPointerEventsNone(parent);
    }
    parent = parent.parentElement;
    depth++;
  }
}
