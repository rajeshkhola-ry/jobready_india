{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
	config: {
		canvasKitBaseUrl: "canvaskit/",
		canvasKitVariant: "full",
		canvasKitForceCpuOnly: true,
	},
	onEntrypointLoaded: async function (engineInitializer) {
		const appRunner = await engineInitializer.initializeEngine();
		await appRunner.runApp();
	},
});
