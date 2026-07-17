{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
	config: {
		canvasKitVariant: "full",
	},
	onEntrypointLoaded: async function (engineInitializer) {
		const appRunner = await engineInitializer.initializeEngine();
		await appRunner.runApp();
	},
});
