{{flutter_js}}
{{flutter_build_config}}

(function () {
  // Replaced at deploy time (see tool/deploy_web.sh) with a fresh value derived
  // from the git commit + timestamp, so main.dart.js's cache-busting query
  // string actually changes on every deploy instead of staying pinned to
  // whatever fixed string someone last hardcoded here.
  var entrypointVersion = '__GRJ_BUILD_VERSION__';
  var builds = (_flutter.buildConfig && _flutter.buildConfig.builds) || [];

  builds.forEach(function (build) {
    if (build.mainJsPath) {
      var separator = build.mainJsPath.indexOf('?') === -1 ? '?' : '&';
      build.mainJsPath = build.mainJsPath + separator + 'v=' + entrypointVersion;
    }
  });

  // MOUNT INTO #grj-app, NOT OVER THE WHOLE PAGE (7 Oct 2026).
  //
  // Without hostElement the app takes the entire document and paints over everything in it.
  // That is why the page content had to be hidden off-screen to reach crawlers at all - and
  // hiding text off-screen is a technique Google names in its spam policy, with ranking lower
  // or not appearing at all as the stated consequence.
  //
  // #grj-app is 100vh, so the tool still owns the whole first screen and looks no different.
  // What changes is that the page below it is now real, visible, readable content instead of
  // a 1x1 box nobody could see.
  //
  // The fallback matters: if that element is ever missing, booting with hostElement undefined
  // would leave the user with a blank page. Falling back to the old whole-document mount means
  // the worst case is the layout we had yesterday, not a dead site.
  var grjHost = document.getElementById('grj-app');

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      var engineConfig = {
        renderer: 'canvaskit',
        useColorEmoji: false,
      };
      if (grjHost) {
        engineConfig.hostElement = grjHost;
      }
      var appRunner = await engineInitializer.initializeEngine(engineConfig);
      await appRunner.runApp();
    },
  });
})();
