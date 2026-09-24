import 'dart:html' as html;
import 'package:flutter/widgets.dart';
import '../glass_dock.dart';

GlassDock makeGlassDock() => WebGlassDock();

/// A `<nav>` appended to `<body>`, outside Flutter's own view element, so
/// taps on it never reach Flutter's pointer handling and Flutter never
/// draws or re-lays-out anything for it. See `glass_dock.dart` for why.
class WebGlassDock implements GlassDock {
  html.Element? _nav;
  html.Element? _lens;
  final List<html.ButtonElement> _tabs = [];
  ValueChanged<int>? _onTap;

  String _itemsKey = '';
  int _selected = -1;
  bool? _visible;
  bool? _compact;
  bool? _dark;
  bool? _rtl;

  @override
  void update({
    required List<GlassDockItem> items,
    required int selected,
    required bool visible,
    required bool compact,
    required bool dark,
    required bool rtl,
    required ValueChanged<int> onTap,
  }) {
    _onTap = onTap;
    final nav = _ensureBuilt();

    final key = items.map((e) => '${e.icon.codePoint}:${e.label}').join('|');
    if (key != _itemsKey) {
      _itemsKey = key;
      _renderTabs(nav, items);
      _selected = -1;
    }
    if (_rtl != rtl) {
      _rtl = rtl;
      nav.dir = rtl ? 'rtl' : 'ltr';
      nav.style.setProperty('--dir', rtl ? '-1' : '1');
    }
    if (_dark != dark) {
      _dark = dark;
      nav.classes.toggle('is-dark', dark);
    }
    if (_compact != compact) {
      _compact = compact;
      nav.classes.toggle('is-compact', compact);
    }
    if (_selected != selected) {
      final moved = _selected >= 0;
      _selected = selected;
      for (var i = 0; i < _tabs.length; i++) {
        final on = i == selected;
        _tabs[i].classes.toggle('is-on', on);
        _tabs[i].setAttribute('aria-selected', '$on');
      }
      nav.style.setProperty('--i', '$selected');
      if (moved) _stretchLens();
    }
    _setVisible(nav, visible);
  }

  @override
  void hide() {
    final nav = _nav;
    if (nav != null) _setVisible(nav, false);
  }

  void _setVisible(html.Element nav, bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    nav.classes.toggle('is-hidden', !visible);
    // `inert` keeps a hidden dock out of the tab order and the
    // accessibility tree, not just out of sight.
    if (visible) {
      nav.attributes.remove('inert');
    } else {
      nav.setAttribute('inert', '');
    }
  }

  html.Element _ensureBuilt() {
    final existing = _nav;
    if (existing != null) return existing;
    html.document.head!.append(html.StyleElement()..text = _css);
    final nav = html.Element.tag('nav')
      ..className = 'ql-dock is-hidden'
      ..setAttribute('role', 'tablist')
      ..setAttribute('inert', '');
    _visible = false;
    final lens = html.DivElement()..className = 'ql-dock__lens';
    nav.append(lens);
    html.document.body!.append(nav);
    _nav = nav;
    _lens = lens;
    return nav;
  }

  void _renderTabs(html.Element nav, List<GlassDockItem> items) {
    for (final t in _tabs) {
      t.remove();
    }
    _tabs.clear();
    nav.style.setProperty('--n', '${items.length}');
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final tab = html.ButtonElement()
        ..type = 'button'
        ..className = 'ql-dock__tab'
        ..setAttribute('role', 'tab')
        ..setAttribute('aria-label', item.label)
        ..append(html.SpanElement()
          ..className = 'ql-dock__icon'
          ..setAttribute('aria-hidden', 'true')
          ..text = String.fromCharCode(item.icon.codePoint))
        ..append(html.SpanElement()
          ..className = 'ql-dock__label'
          ..text = item.label);
      final index = i;
      tab.onClick.listen((_) => _onTap?.call(index));
      tab.on['pointerdown'].listen((_) => tab.classes.add('is-pressed'));
      for (final type in const ['pointerup', 'pointercancel', 'pointerleave']) {
        tab.on[type].listen((_) => tab.classes.remove('is-pressed'));
      }
      nav.append(tab);
      _tabs.add(tab);
    }
  }

  /// The "liquid" part of the selection move: the lens briefly stretches
  /// along the direction of travel and settles, instead of just gliding
  /// over as a rigid pill. Independent of the `transform` transition doing
  /// the actual move, since it animates the separate `scale` property.
  void _stretchLens() {
    try {
      _lens?.animate([
        {'scale': '1 1'},
        {'scale': '1.16 0.86', 'offset': 0.35},
        {'scale': '1 1'},
      ], {
        'duration': 460,
        'easing': 'cubic-bezier(.3,.7,.4,1)',
      });
    } on Object {
      // Purely decorative — the move itself still happens via CSS.
    }
  }
}

/// Paths are relative to the page's `<base href>`: Flutter serves the Material
/// icon font at `assets/fonts/` and app fonts under `assets/assets/fonts/`.
/// The icon font is tree-shaken at build time, which is fine here: it keeps
/// every glyph Dart code references, and these tabs' icons are all referenced
/// in `main_shell.dart`.
///
/// The `.ql-dock` height and bottom offset must match `_dockFootprint` in
/// `main_shell.dart`, which reserves that space on the Flutter side.
const _css = r'''
@font-face{font-family:"QL Nav Icons";src:url("assets/fonts/MaterialIcons-Regular.otf") format("opentype");font-display:block}
@font-face{font-family:"QL Vazir";src:url("assets/assets/fonts/Vazirmatn-SemiBold.ttf") format("truetype");font-weight:600;font-display:swap}
@font-face{font-family:"QL Vazir";src:url("assets/assets/fonts/Vazirmatn-Bold.ttf") format("truetype");font-weight:700;font-display:swap}

.ql-dock{
  --n:6;--i:0;--dir:1;
  --tint:#0E8F6E;
  --ink:rgba(28,28,30,.86);
  --glass:rgba(250,250,252,.42);
  --lens:rgba(118,118,128,.16);
  --rim-hi:rgba(255,255,255,.9);
  --rim-lo:rgba(255,255,255,.35);
  --edge:rgba(0,0,0,.07);
  position:fixed;z-index:2147483000;
  inset-inline-start:max(21px,calc((100vw - 520px) / 2));
  bottom:calc(21px + env(safe-area-inset-bottom,0px));
  width:min(calc(100vw - 42px),520px);height:64px;
  box-sizing:border-box;padding:4px;margin:0;
  display:flex;align-items:stretch;
  border-radius:999px;
  background:var(--glass);
  -webkit-backdrop-filter:blur(12px) saturate(185%);
  backdrop-filter:blur(12px) saturate(185%);
  box-shadow:
    inset 0 1px 0 0 var(--rim-hi),
    inset 0 -1px 0 0 var(--rim-lo),
    inset 0 0 0 .5px var(--edge),
    0 12px 32px -8px rgba(0,0,0,.24),
    0 2px 6px rgba(0,0,0,.06);
  font-family:"QL Vazir",Vazirmatn,-apple-system,system-ui,sans-serif;
  -webkit-tap-highlight-color:transparent;
  -webkit-user-select:none;user-select:none;-webkit-touch-callout:none;
  touch-action:none;
  transition:
    width .45s cubic-bezier(.32,.72,0,1),
    height .45s cubic-bezier(.32,.72,0,1),
    opacity .22s ease,
    translate .32s cubic-bezier(.32,.72,0,1),
    scale .25s ease,
    box-shadow .25s ease,
    visibility 0s;
}
/* Specular sheen: the bright top-left catch-light and softer bottom-right
   bounce that make it read as a curved glass surface, not a flat tint. */
.ql-dock::before{
  content:"";position:absolute;inset:0;border-radius:inherit;pointer-events:none;
  background:
    radial-gradient(90% 130% at 10% -20%,rgba(255,255,255,.6),rgba(255,255,255,0) 45%),
    radial-gradient(70% 120% at 95% 125%,rgba(255,255,255,.28),rgba(255,255,255,0) 50%),
    linear-gradient(180deg,rgba(255,255,255,.16),rgba(255,255,255,0) 60%);
}
.ql-dock__lens{
  position:absolute;top:4px;bottom:4px;inset-inline-start:4px;
  width:calc((100% - 8px) / var(--n));
  border-radius:999px;background:var(--lens);
  box-shadow:inset 0 1px 0 rgba(255,255,255,.65),inset 0 0 0 .5px rgba(255,255,255,.4);
  transform:translateX(calc(var(--i) * 100% * var(--dir)));
  transition:transform .5s cubic-bezier(.34,1.32,.5,1),opacity .2s ease;
  pointer-events:none;
}
.ql-dock__tab{
  position:relative;z-index:1;flex:1 1 0;min-width:0;overflow:hidden;
  display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1px;
  margin:0;padding:0;border:0;background:none;border-radius:999px;
  color:var(--ink);font:inherit;cursor:pointer;outline:none;
  transition:flex-grow .45s cubic-bezier(.32,.72,0,1),opacity .2s ease,color .2s ease;
}
.ql-dock__tab.is-on{color:var(--tint)}
.ql-dock__tab:focus-visible{box-shadow:inset 0 0 0 2px var(--tint)}
.ql-dock__icon{
  font-family:"QL Nav Icons";font-size:25px;line-height:1;
  font-weight:normal;font-style:normal;
  transition:transform .18s ease;
}
.ql-dock__tab.is-pressed .ql-dock__icon{transform:scale(.86)}
.ql-dock__label{
  font-size:10.5px;font-weight:600;line-height:1.3;max-height:14px;
  max-width:100%;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;
  transition:opacity .2s ease,max-height .3s ease;
}
.ql-dock__tab.is-on .ql-dock__label{font-weight:700}

/* iOS 26 minimise-on-scroll: the bar folds into one bubble holding just
   the current tab, anchored to the leading edge. Tapping it expands it. */
.ql-dock.is-compact{width:56px;height:56px}
.ql-dock.is-compact .ql-dock__tab:not(.is-on){flex-grow:0;opacity:0;pointer-events:none}
.ql-dock.is-compact .ql-dock__label{opacity:0;max-height:0}
.ql-dock.is-compact .ql-dock__lens{opacity:0}

.ql-dock.is-hidden{
  opacity:0;translate:0 18px;scale:.94;visibility:hidden;pointer-events:none;
  transition:opacity .18s ease,translate .26s ease,scale .26s ease,visibility 0s linear .26s;
}

@media (hover:hover) and (pointer:fine){
  .ql-dock:not(.is-hidden):hover{
    scale:1.025;
    box-shadow:
      inset 0 1px 0 0 var(--rim-hi),
      inset 0 -1px 0 0 var(--rim-lo),
      inset 0 0 0 .5px var(--edge),
      0 18px 44px -10px rgba(0,0,0,.32),
      0 3px 10px rgba(0,0,0,.08);
  }
}

.ql-dock.is-dark{
  --tint:#34C79C;
  --ink:rgba(255,255,255,.92);
  --glass:rgba(34,34,38,.44);
  --lens:rgba(255,255,255,.14);
  --rim-hi:rgba(255,255,255,.3);
  --rim-lo:rgba(255,255,255,.1);
  --edge:rgba(255,255,255,.1);
}
.ql-dock.is-dark::before{opacity:.35}

@media (prefers-reduced-motion:reduce){
  .ql-dock,.ql-dock *{transition-duration:.01ms!important;animation:none!important}
}
''';
