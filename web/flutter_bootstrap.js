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

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      var appRunner = await engineInitializer.initializeEngine({
        renderer: 'canvaskit',
        useColorEmoji: false,
      });
      await appRunner.runApp();
    },
  });
})();
