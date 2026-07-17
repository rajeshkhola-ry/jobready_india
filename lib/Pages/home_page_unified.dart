import 'package:flutter/material.dart';

import '../Services/file_picker_service.dart';
import '../Services/file_storage_service.dart';
import '../Services/upload_context_service.dart';

class HomePageUnified extends StatefulWidget {
  const HomePageUnified({super.key});

  @override
  State<HomePageUnified> createState() => _HomePageUnifiedState();
}

class _HomePageUnifiedState extends State<HomePageUnified> {
  static const Color _navy = Color(0xFF0A1F44);
  static const Color _blue = Color(0xFF284BCE);
  static const Color _gold = Color(0xFFFFC72C);

  String _uploadHint = 'PDF, Word, Excel, JPG, PNG, PPT (max 100 MB)';
  bool _isPicking = false;

  final List<_QuickTool> _quickTools = const [
    _QuickTool('PDF to Word', 'Convert PDF into editable Word', Icons.description_rounded, '/convert'),
    _QuickTool('Word to PDF', 'Convert Word document to PDF', Icons.picture_as_pdf_rounded, '/convert'),
    _QuickTool('Image to PDF', 'Convert image files to PDF', Icons.image_rounded, '/convert'),
    _QuickTool('Excel to PDF', 'Convert sheets to PDF', Icons.grid_on_rounded, '/convert'),
    _QuickTool('Merge PDF', 'Combine multiple PDF files', Icons.merge_type_rounded, '/merge'),
    _QuickTool('Split PDF', 'Extract pages from PDF', Icons.call_split_rounded, '/split'),
    _QuickTool('Compress PDF', 'Reduce file size while preserving quality', Icons.compress_rounded, '/compress'),
    _QuickTool('PDF Toolkit', 'More PDF editing tools', Icons.build_circle_rounded, '/pdf-tools'),
  ];

  final List<_WhyChooseItem> _whyChooseItems = const [
    _WhyChooseItem(Icons.lock_rounded, 'Secure & Private', 'Your files are encrypted and auto-deleted.'),
    _WhyChooseItem(Icons.speed_rounded, 'Fast Processing', 'Most actions complete within seconds.'),
    _WhyChooseItem(Icons.auto_awesome_rounded, 'AI Powered', 'Smart OCR and extraction assist.'),
    _WhyChooseItem(Icons.language_rounded, 'Global Ready', 'English-first, worldwide rollout ready.'),
  ];

  Future<void> _pickFromHome() async {
    setState(() {
      _isPicking = true;
    });

    try {
      final selected = await FilePickerService.pickFileData();
      if (selected == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _uploadHint = 'No file selected. Please try again.';
        });
        return;
      }

      UploadContextService.setLastPickedFile(selected);
      await FileStorageService.storeFile(
        name: selected.name,
        bytes: selected.bytes,
        mimeType: 'application/octet-stream',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _uploadHint = 'Loaded: ${selected.name} (${_formatBytes(selected.size)})';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File uploaded. Choose a tool to continue.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _uploadHint = 'Unable to read file. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  void _openRoute(String route) {
    Navigator.of(context).pushNamed(route);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar()),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: _navy,
              elevation: 0,
              title: const Text(
                'JOBREADY',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: 250,
              child: _buildSidebar(),
            ),
          Expanded(
            child: _buildMainContent(isDesktop),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1F44), Color(0xFF142E67)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _gold,
                    child: Icon(Icons.work_outline_rounded, color: _navy, size: 18),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'JOBREADY',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildNavItem('Home', Icons.home_rounded, true, () => _openRoute('/home')),
              _buildNavItem('Convert', Icons.swap_horiz_rounded, false, () => _openRoute('/convert')),
              _buildNavItem('Compress', Icons.compress_rounded, false, () => _openRoute('/compress')),
              _buildNavItem('Merge', Icons.merge_type_rounded, false, () => _openRoute('/merge')),
              _buildNavItem('Split', Icons.call_split_rounded, false, () => _openRoute('/split')),
              _buildNavItem('PDF Tools', Icons.build_circle_rounded, false, () => _openRoute('/pdf-tools')),
              _buildNavItem('History', Icons.history_rounded, false, () => _openRoute('/home-v2')),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upgrade to Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text(
                      'Unlimited conversions and priority support for your launch team.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStorageCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Cloud Storage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 8),
          Text('2.4 GB / 10 GB used', style: TextStyle(color: Colors.white70, fontSize: 12)),
          SizedBox(height: 8),
          LinearProgressIndicator(
            value: 0.24,
            minHeight: 8,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC72C)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String title, IconData icon, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active ? _blue : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDesktop) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(isDesktop ? 22 : 14, 16, isDesktop ? 22 : 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopHeader(),
            const SizedBox(height: 14),
            _buildUploadPanel(),
            const SizedBox(height: 20),
            _buildSectionHeader('What do you want to do?', actionText: 'View All Tools'),
            const SizedBox(height: 10),
            _buildToolsGrid(isDesktop),
            const SizedBox(height: 16),
            _buildBottomPanels(isDesktop),
            const SizedBox(height: 12),
            _buildTrustStrip(),
            const SizedBox(height: 10),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x110B1F44), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, Rajesh!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _navy),
                ),
                SizedBox(height: 4),
                Text(
                  'Convert, edit, and manage your documents with confidence.',
                  style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Special Offer\n50% OFF Premium',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, color: _blue),
            ),
          ),
          const SizedBox(width: 10),
          _buildHeaderAction(Icons.notifications_none_rounded, badge: '3'),
          const SizedBox(width: 8),
          _buildHeaderAction(Icons.account_circle_rounded),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, {String? badge}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _blue),
        ),
        if (badge != null)
          Positioned(
            right: -2,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUploadPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD3DEFF), width: 1.4),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.cloud_upload_rounded, color: _blue, size: 42),
          ),
          const SizedBox(height: 8),
          const Text(
            'Drop your file here or click to browse',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 6),
          Text(
            _uploadHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isPicking ? null : _pickFromHome,
            icon: const Icon(Icons.folder_open_rounded),
            label: Text(_isPicking ? 'Selecting...' : 'Choose File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 16),
              SizedBox(width: 6),
              Text(
                'Your files are 100% secure and private.',
                style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? actionText}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _navy),
        ),
        const Spacer(),
        if (actionText != null)
          Text(
            actionText,
            style: const TextStyle(color: _blue, fontWeight: FontWeight.w700),
          ),
      ],
    );
  }

  Widget _buildToolsGrid(bool isDesktop) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = isDesktop ? 4 : (width >= 720 ? 3 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _quickTools.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: isDesktop ? 1.55 : 1.2,
      ),
      itemBuilder: (context, index) {
        final tool = _quickTools[index];
        return InkWell(
          onTap: () => _openRoute(tool.route),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDE5FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(tool.icon, color: _blue, size: 19),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tool.title,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: _navy),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tool.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomPanels(bool isDesktop) {
    if (!isDesktop) {
      return Column(
        children: [
          _buildOfferCard(),
          const SizedBox(height: 10),
          _buildPlanCard(),
          const SizedBox(height: 10),
          _buildWhyChooseCard(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildOfferCard()),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: _buildPlanCard()),
        const SizedBox(width: 10),
        Expanded(child: _buildWhyChooseCard()),
      ],
    );
  }

  Widget _buildOfferCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5FF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Offers & Coupons', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          SizedBox(height: 10),
          Text('First conversion free', style: TextStyle(color: _navy, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('First conversion free with code: WELCOME50', style: TextStyle(color: Color(0xFF4B5563))),
          SizedBox(height: 8),
          Text('Get 50% off on Premium monthly plans.', style: TextStyle(color: Color(0xFF4B5563))),
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose Your Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMiniPlan('Free Plan', '₹0', 'Basic tools')),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniPlan('Premium', '₹99/mo', 'Unlimited conversions', highlighted: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniPlan('Lifetime', '₹1999', 'One-time payment')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlan(String title, String price, String subtitle, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFEFF2FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlighted ? _blue : const Color(0xFFD6DFFA), width: highlighted ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
        ],
      ),
    );
  }

  Widget _buildWhyChooseCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Why Choose JOBREADY?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 10),
          ..._whyChooseItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, color: _blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, color: _navy)),
                        Text(item.subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F44),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text('JOBREADY • The fastest document toolkit for global users', style: TextStyle(color: Colors.white70)),
          Text('Trusted by users worldwide • 4.8/5', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildTrustStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE5FF)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_rounded, color: Color(0xFF64748B), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Trusted by thousands of users worldwide',
              style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700),
            ),
          ),
          Text('⭐ ⭐ ⭐ ⭐ ⭐  4.8/5', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _QuickTool {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  const _QuickTool(this.title, this.subtitle, this.icon, this.route);
}

class _WhyChooseItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const _WhyChooseItem(this.icon, this.title, this.subtitle);
}
