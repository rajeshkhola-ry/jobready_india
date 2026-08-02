// Stub used by non-web test environments so widget tests can compile without dart:ui_web.
class _PlatformViewRegistry {
  void registerViewFactory(String viewTypeId, Object Function(int viewId) viewFactory) {}
}

class _UiWebFacade {
  final _PlatformViewRegistry platformViewRegistry = _PlatformViewRegistry();
}

final _UiWebFacade _uiWebFacade = _UiWebFacade();

final platformViewRegistry = _uiWebFacade.platformViewRegistry;
