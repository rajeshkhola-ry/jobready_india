import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:universal_html/html.dart' as html;

import '../Services/file_picker_service.dart';
import '../Services/poster_banner_studio_service.dart';

class PosterBannerStudioPage extends StatefulWidget {
  const PosterBannerStudioPage({super.key});

  @override
  State<PosterBannerStudioPage> createState() => _PosterBannerStudioPageState();
}

class _PosterBannerStudioPageState extends State<PosterBannerStudioPage> {
  final GlobalKey _canvasKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _fontSizeController = TextEditingController(text: '24');
  final List<String> _fontFamilies = <String>['Trebuchet MS', 'Georgia', 'Courier New', 'Verdana'];
  final Size _canvasSize = const Size(340, 420);

  late PosterStudioTemplate _selectedTemplate;
  late List<PosterLayerDraft> _layers;
  String _selectedCategory = 'All';
  int _selectedLayerIndex = 0;
  bool _busy = false;
  Uint8List? _uploadedImageBytes;
  String _selectedFontFamily = 'Trebuchet MS';

  @override
  void initState() {
    super.initState();
    _selectedTemplate = PosterBannerStudioService.templates.first;
    _layers = _cloneLayers(_selectedTemplate.layers);
    _syncControllers();
  }

  @override
  void dispose() {
    _textController.dispose();
    _fontSizeController.dispose();
    super.dispose();
  }

  List<PosterLayerDraft> _cloneLayers(List<PosterLayerDraft> source) {
    return source
        .map(
          (layer) => PosterLayerDraft(
            type: layer.type,
            label: layer.label,
            position: layer.position,
            size: layer.size,
            rotation: layer.rotation,
            text: layer.text,
            fontSize: layer.fontSize,
            fontWeight: layer.fontWeight,
            fillColor: layer.fillColor,
            textColor: layer.textColor,
            iconData: layer.iconData,
            shapeType: layer.shapeType,
            borderRadius: layer.borderRadius,
          ),
        )
        .toList();
  }

  PosterLayerDraft get _selectedLayer => _layers[_selectedLayerIndex];

  void _syncControllers() {
    final layer = _selectedLayer;
    _textController.text = layer.text;
    _fontSizeController.text = layer.fontSize.toStringAsFixed(0);
  }

  void _applyTemplate(PosterStudioTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _layers = _cloneLayers(template.layers);
      _selectedLayerIndex = 0;
      _uploadedImageBytes = null;
      _selectedFontFamily = 'Trebuchet MS';
      _syncControllers();
    });
  }

  void _updateLayer(PosterLayerDraft updated) {
    setState(() {
      _layers[_selectedLayerIndex] = updated;
      _syncControllers();
    });
  }

  void _nudgeLayer(double dx, double dy) {
    final current = _selectedLayer;
    final next = Offset(
      (current.position.dx + dx).clamp(0, _canvasSize.width - current.size.width),
      (current.position.dy + dy).clamp(0, _canvasSize.height - current.size.height),
    );
    _updateLayer(
      PosterLayerDraft(
        type: current.type,
        label: current.label,
        position: next,
        size: current.size,
        rotation: current.rotation,
        text: current.text,
        fontSize: current.fontSize,
        fontWeight: current.fontWeight,
        fillColor: current.fillColor,
        textColor: current.textColor,
        iconData: current.iconData,
        shapeType: current.shapeType,
        borderRadius: current.borderRadius,
      ),
    );
  }

  void _addLayer(PosterLayerType type) {
    final layer = PosterLayerDraft(
      type: type,
      label: _defaultLayerLabel(type, _layers.length + 1),
      position: Offset(28 + (_layers.length % 3) * 18, 34 + (_layers.length % 4) * 18),
      size: _defaultLayerSize(type),
      text: _defaultLayerText(type),
      fontSize: type == PosterLayerType.text ? 22 : 16,
      fontWeight: FontWeight.w700,
      fillColor: _defaultFillColor(type),
      textColor: type == PosterLayerType.shape ? Colors.transparent : const Color(0xFF0F172A),
      iconData: type == PosterLayerType.icon ? Icons.star_rounded : null,
      shapeType: type == PosterLayerType.badge ? PosterShapeType.pill : PosterShapeType.rectangle,
      borderRadius: type == PosterLayerType.badge ? 999 : 18,
    );

    setState(() {
      _layers.add(layer);
      _selectedLayerIndex = _layers.length - 1;
      _syncControllers();
    });
  }

  String _defaultLayerLabel(PosterLayerType type, int index) {
    switch (type) {
      case PosterLayerType.text:
        return 'Text $index';
      case PosterLayerType.shape:
        return 'Shape $index';
      case PosterLayerType.image:
        return 'Image $index';
      case PosterLayerType.icon:
        return 'Icon $index';
      case PosterLayerType.badge:
        return 'Badge $index';
    }
  }

  Size _defaultLayerSize(PosterLayerType type) {
    switch (type) {
      case PosterLayerType.text:
        return const Size(220, 84);
      case PosterLayerType.shape:
        return const Size(120, 80);
      case PosterLayerType.image:
        return const Size(120, 120);
      case PosterLayerType.icon:
        return const Size(86, 86);
      case PosterLayerType.badge:
        return const Size(160, 42);
    }
  }

  String _defaultLayerText(PosterLayerType type) {
    switch (type) {
      case PosterLayerType.text:
        return 'New headline';
      case PosterLayerType.shape:
        return '';
      case PosterLayerType.image:
        return '';
      case PosterLayerType.icon:
        return 'ICON';
      case PosterLayerType.badge:
        return 'NEW BADGE';
    }
  }

  Color _defaultFillColor(PosterLayerType type) {
    switch (type) {
      case PosterLayerType.text:
        return Colors.transparent;
      case PosterLayerType.shape:
        return const Color(0x33FFFFFF);
      case PosterLayerType.image:
        return const Color(0x667AA2C8);
      case PosterLayerType.icon:
        return const Color(0xFFFFC857);
      case PosterLayerType.badge:
        return const Color(0xFFFFF1C2);
    }
  }

  Future<void> _pickImage() async {
    final file = await FilePickerService.pickFileData(allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'webp']);
    if (file == null) {
      if (!mounted) {
        return;
      }
      final report = FilePickerService.lastSelectionReport;
      if (!report.cancelled && report.buildSummaryMessage().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(report.buildSummaryMessage())));
      }
      return;
    }

    setState(() {
      _uploadedImageBytes = file.bytes;
    });

    final imageLayerIndex = _layers.indexWhere((layer) => layer.type == PosterLayerType.image);
    if (imageLayerIndex >= 0) {
      setState(() {
        _selectedLayerIndex = imageLayerIndex;
        _syncControllers();
      });
    } else {
      _addLayer(PosterLayerType.image);
    }
  }

  Future<Uint8List> _capturePngBytes({double pixelRatio = 3}) async {
    final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Canvas boundary unavailable');
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Unable to encode PNG bytes');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _downloadRaster({required String extension}) async {
    setState(() => _busy = true);
    try {
      final pngBytes = await _capturePngBytes();
      Uint8List outputBytes = pngBytes;
      String mime = 'image/png';
      if (extension == 'webp') {
        final webpBytes = await _convertPngToWebpInBrowser(pngBytes);
        if (webpBytes == null || webpBytes.isEmpty) {
          throw StateError('Unable to convert poster to WebP');
        }
        outputBytes = webpBytes;
        mime = 'image/webp';
      }
      _downloadBytes('${_selectedTemplate.id}_studio.$extension', outputBytes, mime: mime);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded ${extension.toUpperCase()} export.')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _busy = true);
    try {
      final bytes = await PosterBannerStudioService.buildPosterPdf(
        canvasSize: _canvasSize,
        gradientColors: _selectedTemplate.gradientColors,
        layers: _layers,
        uploadedImageBytes: _uploadedImageBytes,
      );
      _downloadBytes('${_selectedTemplate.id}_print_ready.pdf', bytes, mime: 'application/pdf');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloaded print-ready PDF export.')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _downloadBytes(String fileName, Uint8List bytes, {required String mime}) {
    final blob = html.Blob(<dynamic>[bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  Future<Uint8List?> _convertPngToWebpInBrowser(Uint8List pngBytes) async {
    final sourceBlob = html.Blob(<dynamic>[pngBytes], 'image/png');
    final sourceUrl = html.Url.createObjectUrlFromBlob(sourceBlob);
    final image = html.ImageElement(src: sourceUrl);

    await image.onLoad.first;
    html.Url.revokeObjectUrl(sourceUrl);

    final width = image.width ?? 0;
    final height = image.height ?? 0;
    if (width <= 0 || height <= 0) {
      return null;
    }

    final canvas = html.CanvasElement(width: width, height: height);
    final context = canvas.context2D;
    context.drawImage(image, 0, 0);

    final webpBlob = await canvas.toBlob('image/webp', 0.96);
    if (webpBlob == null) {
      return null;
    }

    final completer = Completer<Uint8List?>();
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(result.asUint8List());
        return;
      }
      completer.complete(null);
    });
    reader.readAsArrayBuffer(webpBlob);

    return completer.future;
  }

  List<PosterStudioTemplate> get _visibleTemplates {
    if (_selectedCategory == 'All') {
      return PosterBannerStudioService.templates;
    }
    return PosterBannerStudioService.templates.where((template) => template.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>['All', ...PosterBannerStudioService.categories];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Poster & Banner Studio'),
        backgroundColor: const Color(0xFF123A63),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFF6F8FC), Color(0xFFEAF3FB), Color(0xFFFDFEFF)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1180;
            final leftPanel = _buildTemplatePanel(categories);
            final centerPanel = _buildCanvasPanel();
            final rightPanel = _buildInspectorPanel();

            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 280, child: leftPanel),
                    const SizedBox(width: 16),
                    Expanded(child: centerPanel),
                    const SizedBox(width: 16),
                    SizedBox(width: 320, child: rightPanel),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  leftPanel,
                  const SizedBox(height: 16),
                  centerPanel,
                  const SizedBox(height: 16),
                  rightPanel,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTemplatePanel(List<String> categories) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Studio Templates',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF102A43)),
            ),
            const SizedBox(height: 8),
            const Text('Local presets for hiring posts, festive greetings, business promotions, and public notices.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories
                  .map(
                    (category) => ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (_) => setState(() => _selectedCategory = category),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            ..._visibleTemplates.map(
              (template) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _applyTemplate(template),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedTemplate.id == template.id ? const Color(0xFF123A63) : const Color(0xFFD5E3F0),
                        width: _selectedTemplate.id == template.id ? 2 : 1,
                      ),
                      gradient: LinearGradient(colors: template.gradientColors),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: const Color(0xFF123A63).withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(template.category, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(template.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(template.description, style: const TextStyle(color: Colors.white, height: 1.35)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Canvas Workspace',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF102A43)),
                      ),
                      SizedBox(height: 4),
                      Text('Interactive layer stack for text, shapes, images, icons, and badges.'),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(onPressed: _busy ? null : _pickImage, icon: const Icon(Icons.image_outlined), label: const Text('Upload Image')),
                    OutlinedButton.icon(onPressed: _busy ? null : () => _addLayer(PosterLayerType.text), icon: const Icon(Icons.text_fields_rounded), label: const Text('Add Text')),
                    OutlinedButton.icon(onPressed: _busy ? null : () => _addLayer(PosterLayerType.badge), icon: const Icon(Icons.sell_outlined), label: const Text('Add Badge')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: RepaintBoundary(
                key: _canvasKey,
                child: Container(
                  width: _canvasSize.width,
                  height: _canvasSize.height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(colors: _selectedTemplate.gradientColors),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 16)),
                    ],
                  ),
                  child: Stack(
                    children: <Widget>[
                      if (_uploadedImageBytes != null)
                        Positioned(
                          right: 18,
                          bottom: 20,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Opacity(
                              opacity: 0.92,
                              child: Image.memory(
                                _uploadedImageBytes!,
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ...List<Widget>.generate(_layers.length, (index) {
                        final layer = _layers[index];
                        return Positioned(
                          left: layer.position.dx,
                          top: layer.position.dy,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedLayerIndex = index;
                              _syncControllers();
                            }),
                            onPanUpdate: (details) {
                              final next = Offset(
                                (_layers[index].position.dx + details.delta.dx).clamp(0, _canvasSize.width - layer.size.width),
                                (_layers[index].position.dy + details.delta.dy).clamp(0, _canvasSize.height - layer.size.height),
                              );
                              setState(() {
                                _layers[index] = PosterLayerDraft(
                                  type: layer.type,
                                  label: layer.label,
                                  position: next,
                                  size: layer.size,
                                  rotation: layer.rotation,
                                  text: layer.text,
                                  fontSize: layer.fontSize,
                                  fontWeight: layer.fontWeight,
                                  fillColor: layer.fillColor,
                                  textColor: layer.textColor,
                                  iconData: layer.iconData,
                                  shapeType: layer.shapeType,
                                  borderRadius: layer.borderRadius,
                                );
                              });
                            },
                            child: Transform.rotate(
                              angle: layer.rotation,
                              child: _buildCanvasLayer(layer, selected: index == _selectedLayerIndex),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _downloadRaster(extension: 'png'),
                  icon: const Icon(Icons.image),
                  label: const Text('Export PNG'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _downloadRaster(extension: 'webp'),
                  icon: const Icon(Icons.layers_outlined),
                  label: const Text('Export WebP'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _downloadPdf,
                  icon: _busy
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export Print PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasLayer(PosterLayerDraft layer, {required bool selected}) {
    final outline = selected ? Border.all(color: Colors.white, width: 1.5) : null;
    switch (layer.type) {
      case PosterLayerType.text:
        return Container(
          width: layer.size.width,
          height: layer.size.height,
          decoration: BoxDecoration(border: outline),
          child: Text(
            layer.text,
            style: TextStyle(
              color: layer.textColor,
              fontSize: layer.fontSize,
              fontWeight: layer.fontWeight,
              fontFamily: _selectedFontFamily,
              height: 1.05,
            ),
          ),
        );
      case PosterLayerType.shape:
      case PosterLayerType.badge:
        return Container(
          width: layer.size.width,
          height: layer.size.height,
          decoration: BoxDecoration(
            color: layer.fillColor,
            borderRadius: BorderRadius.circular(layer.borderRadius),
            border: outline,
          ),
          alignment: Alignment.center,
          child: Text(
            layer.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: layer.textColor,
              fontSize: layer.fontSize,
              fontWeight: layer.fontWeight,
              fontFamily: _selectedFontFamily,
            ),
          ),
        );
      case PosterLayerType.icon:
        return Container(
          width: layer.size.width,
          height: layer.size.height,
          decoration: BoxDecoration(
            color: layer.fillColor,
            borderRadius: BorderRadius.circular(layer.borderRadius),
            border: outline,
          ),
          child: Icon(layer.iconData ?? Icons.star_rounded, color: layer.textColor, size: math.min(layer.size.width, layer.size.height) * 0.56),
        );
      case PosterLayerType.image:
        return Container(
          width: layer.size.width,
          height: layer.size.height,
          decoration: BoxDecoration(
            color: layer.fillColor,
            borderRadius: BorderRadius.circular(layer.borderRadius),
            border: outline,
          ),
          clipBehavior: Clip.antiAlias,
          child: _uploadedImageBytes == null
              ? const Center(child: Text('Upload image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))
              : Image.memory(_uploadedImageBytes!, fit: BoxFit.cover),
        );
    }
  }

  Widget _buildInspectorPanel() {
    final layer = _selectedLayer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Layer Manager',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF102A43)),
            ),
            const SizedBox(height: 8),
            const Text('Select a layer, edit styling, then nudge or rotate it in real time.'),
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              child: ReorderableListView.builder(
                itemCount: _layers.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _layers.removeAt(oldIndex);
                    _layers.insert(newIndex, item);
                    _selectedLayerIndex = newIndex;
                    _syncControllers();
                  });
                },
                itemBuilder: (context, index) {
                  final item = _layers[index];
                  final active = index == _selectedLayerIndex;
                  return ListTile(
                    key: ValueKey('${item.label}_$index'),
                    selected: active,
                    selectedTileColor: const Color(0xFFEAF3FB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(item.type.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _layers.length <= 1
                          ? null
                          : () {
                              setState(() {
                                _layers.removeAt(index);
                                _selectedLayerIndex = (_selectedLayerIndex.clamp(0, _layers.length - 1)).toInt();
                                _syncControllers();
                              });
                            },
                    ),
                    onTap: () => setState(() {
                      _selectedLayerIndex = index;
                      _syncControllers();
                    }),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Layer Text'),
              onChanged: (value) {
                _updateLayer(
                  PosterLayerDraft(
                    type: layer.type,
                    label: layer.label,
                    position: layer.position,
                    size: layer.size,
                    rotation: layer.rotation,
                    text: value,
                    fontSize: layer.fontSize,
                    fontWeight: layer.fontWeight,
                    fillColor: layer.fillColor,
                    textColor: layer.textColor,
                    iconData: layer.iconData,
                    shapeType: layer.shapeType,
                    borderRadius: layer.borderRadius,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedFontFamily,
              decoration: const InputDecoration(labelText: 'Font Family'),
              items: _fontFamilies.map((font) => DropdownMenuItem<String>(value: font, child: Text(font))).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedFontFamily = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fontSizeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Font Size'),
              onChanged: (value) {
                final parsed = double.tryParse(value);
                if (parsed == null) {
                  return;
                }
                _updateLayer(
                  PosterLayerDraft(
                    type: layer.type,
                    label: layer.label,
                    position: layer.position,
                    size: layer.size,
                    rotation: layer.rotation,
                    text: layer.text,
                    fontSize: parsed.clamp(10, 72),
                    fontWeight: layer.fontWeight,
                    fillColor: layer.fillColor,
                    textColor: layer.textColor,
                    iconData: layer.iconData,
                    shapeType: layer.shapeType,
                    borderRadius: layer.borderRadius,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const Text('Text Color', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _buildColorRow(
              current: layer.textColor,
              onSelected: (color) {
                _updateLayer(
                  PosterLayerDraft(
                    type: layer.type,
                    label: layer.label,
                    position: layer.position,
                    size: layer.size,
                    rotation: layer.rotation,
                    text: layer.text,
                    fontSize: layer.fontSize,
                    fontWeight: layer.fontWeight,
                    fillColor: layer.fillColor,
                    textColor: color,
                    iconData: layer.iconData,
                    shapeType: layer.shapeType,
                    borderRadius: layer.borderRadius,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const Text('Fill Color', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _buildColorRow(
              current: layer.fillColor,
              onSelected: (color) {
                _updateLayer(
                  PosterLayerDraft(
                    type: layer.type,
                    label: layer.label,
                    position: layer.position,
                    size: layer.size,
                    rotation: layer.rotation,
                    text: layer.text,
                    fontSize: layer.fontSize,
                    fontWeight: layer.fontWeight,
                    fillColor: color,
                    textColor: layer.textColor,
                    iconData: layer.iconData,
                    shapeType: layer.shapeType,
                    borderRadius: layer.borderRadius,
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            const Text('Overlay Position', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _nudgeButton(Icons.arrow_upward, () => _nudgeLayer(0, -6)),
                _nudgeButton(Icons.arrow_downward, () => _nudgeLayer(0, 6)),
                _nudgeButton(Icons.arrow_back, () => _nudgeLayer(-6, 0)),
                _nudgeButton(Icons.arrow_forward, () => _nudgeLayer(6, 0)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Rotation: ${(_selectedLayer.rotation * 57.3).round()}°', style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(
              value: _selectedLayer.rotation,
              min: -0.8,
              max: 0.8,
              onChanged: (value) {
                _updateLayer(
                  PosterLayerDraft(
                    type: layer.type,
                    label: layer.label,
                    position: layer.position,
                    size: layer.size,
                    rotation: value,
                    text: layer.text,
                    fontSize: layer.fontSize,
                    fontWeight: layer.fontWeight,
                    fillColor: layer.fillColor,
                    textColor: layer.textColor,
                    iconData: layer.iconData,
                    shapeType: layer.shapeType,
                    borderRadius: layer.borderRadius,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _nudgeButton(IconData icon, VoidCallback onTap) {
    return OutlinedButton(onPressed: onTap, child: Icon(icon));
  }

  Widget _buildColorRow({required Color current, required ValueChanged<Color> onSelected}) {
    final swatches = <Color>[
      Colors.white,
      Colors.black,
      const Color(0xFF123A63),
      const Color(0xFF0F766E),
      const Color(0xFFFFC857),
      const Color(0xFFD94841),
      const Color(0xFF7C3AED),
      const Color(0xFFE2F3FF),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: swatches
          .map(
            (color) => GestureDetector(
              onTap: () => onSelected(color),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: current == color ? const Color(0xFF123A63) : const Color(0xFFD7E3F1), width: current == color ? 2 : 1),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
