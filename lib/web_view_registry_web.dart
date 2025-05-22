import 'dart:ui' as ui;
import 'dart:html' as html;

// ignore_for_file: undefined_prefixed_name

void registerViewFactory(String viewId, dynamic Function(int) cb) {
  ui.platformViewRegistry.registerViewFactory(viewId, cb);
}
