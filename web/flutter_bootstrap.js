{{flutter_js}}
{{flutter_build_config}}

function showFatalOverlay(errorText) {
	const body = document.body;
	if (!body) {
		return;
	}

	const existing = document.getElementById('jr-fatal-overlay');
	if (existing) {
		existing.querySelector('pre').textContent = String(errorText);
		return;
	}

	const banner = document.createElement('div');
	banner.id = 'jr-fatal-overlay';
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
		'<div style="max-width:760px;text-align:left;line-height:1.5;">',
		'<h2 style="margin:0 0 10px;font-size:20px;">GET JOB READY runtime error</h2>',
		'<p style="margin:0 0 10px;">A web runtime error occurred. Please share this error text.</p>',
		'<pre style="margin:0;padding:12px;background:#f3f4f6;border-radius:8px;overflow:auto;white-space:pre-wrap;"></pre>',
		'</div>',
	].join('');

	banner.querySelector('pre').textContent = String(errorText);
	body.appendChild(banner);
}

window.addEventListener('error', function (event) {
	const text = event && event.error
		? event.error.stack || event.error.message || String(event.error)
		: event.message || 'Unknown window error';
	console.error('Window error:', text);
	showFatalOverlay(text);
});

window.addEventListener('unhandledrejection', function (event) {
	const reason = event && event.reason
		? event.reason.stack || event.reason.message || String(event.reason)
		: 'Unknown unhandled rejection';
	console.error('Unhandled rejection:', reason);
	showFatalOverlay(reason);
});

_flutter.loader.load({
	config: {
		renderer: "canvaskit",
		canvasKitBaseUrl: "canvaskit/",
		canvasKitVariant: "full",
		canvasKitForceCpuOnly: true,
		canvasKitMaximumSurfaces: 1,
	},
	onEntrypointLoaded: async function (engineInitializer) {
		try {
			const appRunner = await engineInitializer.initializeEngine();
			await appRunner.runApp();
		} catch (error) {
			console.error('Flutter bootstrap failed:', error);
			showFatalOverlay(error && (error.stack || error.message) ? (error.stack || error.message) : String(error));
		}
	},
});
