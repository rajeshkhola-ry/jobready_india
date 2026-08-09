{{flutter_js}}
{{flutter_build_config}}

(function () {
  var entrypointVersion = 'grj-shared-sso-20260809';
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
