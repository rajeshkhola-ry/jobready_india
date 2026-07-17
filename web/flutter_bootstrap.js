{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
	config: {
		canvasKitBaseUrl: "canvaskit/",
	},
	onEntrypointLoaded: async function (engineInitializer) {
		try {
			const appRunner = await engineInitializer.initializeEngine();
			await appRunner.runApp();
		} catch (error) {
			console.error('Flutter bootstrap failed:', error);

			const body = document.body;
			if (body) {
				const banner = document.createElement('div');
				banner.style.cssText = [
					'position:fixed',
					'inset:0',
					'display:flex',
					'align-items:center',
					'justify-content:center',
					'padding:24px',
					'background:#ffffff',
					'color:#111827',
					'font-family:Segoe UI,Arial,sans-serif',
					'z-index:2147483647',
				].join(';');

				banner.innerHTML = [
					'<div style="max-width:720px;text-align:left;line-height:1.5;">',
					'<h2 style="margin:0 0 10px;font-size:20px;">JOBREADY startup error</h2>',
					'<p style="margin:0 0 10px;">The app failed to initialize. Please hard refresh and try again.</p>',
					'<pre style="margin:0;padding:12px;background:#f3f4f6;border-radius:8px;overflow:auto;white-space:pre-wrap;">' + String(error) + '</pre>',
					'</div>',
				].join('');

				body.appendChild(banner);
			}
		}
	},
});
