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
  static const Color _navy = Color(0xFF1F2937);
  static const Color _surface = Color(0xFFF5F7FF);
  static const Color _blue = Color(0xFF1F4E79);
  static const Color _blueDark = Color(0xFF003A70);
  static const Color _blueSoft = Color(0xFFE8F1FA);
  static const Color _textMuted = Color(0xFF5B6B8A);

  bool _isPicking = false;
  String _uploadHint = 'PDF, Word, Excel, JPG, PNG, PPT and more (Max. 100 MB)';

  final List<_SidebarItem> _sidebarItems = const [
    _SidebarItem('Home', Icons.home_rounded, '/home', true),
    _SidebarItem('My Files', Icons.folder_open_rounded, '/home-v2', false),
    _SidebarItem('Recent Files', Icons.access_time_rounded, '/home-v2', false),
    _SidebarItem('Favorite Tools', Icons.star_border_rounded, '/home-v2', false),
    _SidebarItem('Cloud Storage', Icons.cloud_outlined, '/home-v2', false),
    _SidebarItem('History', Icons.history_rounded, '/home-v2', false),
    _SidebarItem('Settings', Icons.settings_outlined, '/home-v2', false),
  ];

  final List<_ToolCardModel> _toolCards = const [
    _ToolCardModel('PDF to Word', 'Convert PDF into editable Word', Icons.description_rounded, Color(0xFFEAF1FF), '/convert'),
    _ToolCardModel('Word to PDF', 'Convert Word documents to PDF', Icons.picture_as_pdf_rounded, Color(0xFFFFEEF0), '/convert'),
    _ToolCardModel('Image to PDF', 'Convert images (JPG, PNG) to PDF', Icons.image_rounded, Color(0xFFEDE8FF), '/convert'),
    _ToolCardModel('Excel to PDF', 'Convert Excel sheets to PDF', Icons.grid_on_rounded, Color(0xFFE8FFF3), '/convert'),
    _ToolCardModel('PPT to PDF', 'Convert PowerPoint presentations', Icons.slideshow_rounded, Color(0xFFFFF3E6), '/convert'),
    _ToolCardModel('Merge PDF', 'Combine multiple PDF files', Icons.merge_type_rounded, Color(0xFFE8F1FA), '/merge'),
    _ToolCardModel('Split PDF', 'Extract pages from PDF files', Icons.call_split_rounded, Color(0xFFF0ECFF), '/split'),
    _ToolCardModel('Compress PDF', 'Reduce PDF file size without quality loss', Icons.compress_rounded, Color(0xFFFFEEF7), '/compress'),
  ];

  final List<_WhyItem> _whyItems = const [
    _WhyItem(Icons.lock_rounded, _blue, 'Secure & Private', 'Your files are encrypted and automatically deleted.'),
    _WhyItem(Icons.speed_rounded, Colors.amber, 'Super Fast', 'Lightning fast conversions in seconds.'),
    _WhyItem(Icons.auto_awesome_rounded, Colors.deepPurple, 'AI Powered', 'Smart OCR, AI summaries, and insights.'),
    _WhyItem(Icons.public_rounded, Colors.green, 'Works Everywhere', 'Use on web, Windows, Android and iOS.'),
    _WhyItem(Icons.privacy_tip_rounded, _blueDark, 'Privacy First', 'We never store or share your files.'),
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
        const SnackBar(content: Text('File uploaded. Pick any tool card to continue.')),
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
    if (route == '/home') {
      return;
    }
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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1080;

    return Scaffold(
      backgroundColor: _surface,
      drawer: isDesktop ? null : Drawer(child: _buildSidebar()),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              foregroundColor: _navy,
              title: const Text(
                'GET JOB READY',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 250, child: _buildSidebar()),
          Expanded(child: _buildMainBody(isDesktop)),
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
          colors: [_blueDark, _blue],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFFFC72C),
                    child: Icon(Icons.work_outline_rounded, color: _blueDark, size: 18),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'GET JOB READY',
                    style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'The Fastest Document Toolkit',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ..._sidebarItems.map(_buildSidebarItem),
              const SizedBox(height: 12),
              _buildUpgradeCard(),
              const SizedBox(height: 12),
              _buildCloudCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(_SidebarItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openRoute(item.route),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: item.active ? _blue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                item.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFC72C), size: 18),
              SizedBox(width: 6),
              Text(
                'Upgrade to Premium',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Unlimited conversions\nAdvanced tools\nPriority support',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Upgrade Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudCard() {
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
          Text('2.4 GB of 10 GB used', style: TextStyle(color: Colors.white70, fontSize: 12)),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            child: LinearProgressIndicator(
              value: 0.24,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC72C)),
            ),
          ),
          SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('24%', style: TextStyle(color: Colors.white70, fontSize: 11)),
          )
        ],
      ),
    );
  }

  Widget _buildMainBody(bool isDesktop) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(isDesktop ? 22 : 12, 12, isDesktop ? 22 : 12, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildUploader(),
            const SizedBox(height: 14),
            _buildToolsHeader(),
            const SizedBox(height: 10),
            _buildToolGrid(isDesktop),
            const SizedBox(height: 12),
            _buildLowerPanels(isDesktop),
            const SizedBox(height: 10),
            _buildTrustStrip(),
            const SizedBox(height: 8),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x11083366), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome User!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: _navy),
                ),
                SizedBox(height: 2),
                Text(
                  'Convert, edit and manage your documents with ease.',
                  style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _blueSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Special Offer\n50% OFF Premium',
              textAlign: TextAlign.center,
              style: TextStyle(color: _blue, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          _buildIconButton(Icons.notifications_none_rounded, badge: '3'),
          const SizedBox(width: 8),
          _buildIconButton(Icons.account_circle_rounded),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {String? badge}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _blueSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _blue),
        ),
        if (badge != null)
          Positioned(
            right: -3,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUploader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD2DDFF), width: 1.2),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: const [
              _FormatIcon(Icons.picture_as_pdf_rounded, Color(0xFFFFDCE0), Color(0xFFE11D48)),
              _FormatIcon(Icons.image_rounded, Color(0xFFE5EEFF), _blue),
              _FormatIcon(Icons.cloud_upload_rounded, Color(0xFFE8FFF2), Color(0xFF059669)),
              _FormatIcon(Icons.grid_on_rounded, Color(0xFFE8FFF3), Color(0xFF15803D)),
              _FormatIcon(Icons.description_rounded, Color(0xFFEAF0FF), _blue),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Drop your file here or click to browse',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _navy),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _uploadHint,
            style: const TextStyle(color: _textMuted, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isPicking ? null : _pickFromHome,
            icon: const Icon(Icons.folder_open_rounded),
            label: Text(_isPicking ? 'Selecting...' : 'Choose File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 16),
              SizedBox(width: 6),
              Text('Your files are 100% secure and private.', style: TextStyle(color: _textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolsHeader() {
    return const Row(
      children: [
        Text(
          'What do you want to do?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _navy),
        ),
        Spacer(),
        Text('View All Tools', style: TextStyle(color: _blue, fontWeight: FontWeight.w700)),
        SizedBox(width: 4),
        Icon(Icons.arrow_forward_rounded, color: _blue, size: 18),
      ],
    );
  }

  Widget _buildToolGrid(bool isDesktop) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = isDesktop ? 4 : (width >= 760 ? 3 : 2);

    return GridView.builder(
      itemCount: _toolCards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: isDesktop ? 2.1 : 1.32,
      ),
      itemBuilder: (context, index) {
        final item = _toolCards[index];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openRoute(item.route),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDCE6FF)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: item.iconBg, borderRadius: BorderRadius.circular(10)),
                  child: Icon(item.icon, color: _navy, size: 21),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, color: _navy)),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _textMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLowerPanels(bool isDesktop) {
    if (!isDesktop) {
      return Column(
        children: [
          _buildOfferCard(),
          const SizedBox(height: 10),
          _buildPlanCard(),
          const SizedBox(height: 10),
          _buildWhyCard(),
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
        Expanded(child: _buildWhyCard()),
      ],
    );
  }

  Widget _buildOfferCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE6FF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: Colors.red, size: 18),
              SizedBox(width: 6),
              Text('Offers & Coupons', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _navy)),
            ],
          ),
          SizedBox(height: 10),
          Center(child: Icon(Icons.card_giftcard_rounded, size: 62, color: Color(0xFFF59E0B))),
          SizedBox(height: 8),
          Text('First Conversion FREE!', style: TextStyle(color: _navy, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('Use code: WELCOME50', style: TextStyle(color: _blue, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('Get 50% OFF on Premium plans', style: TextStyle(color: _textMuted)),
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
        border: Border.all(color: const Color(0xFFDCE6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.diamond_rounded, color: _blue, size: 18),
              SizedBox(width: 6),
              Text('Choose Your Plan', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _navy)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildPlanTile('Free Plan', '₹0', '/ forever', 'Get Started', false)),
              const SizedBox(width: 8),
              Expanded(child: _buildPlanTile('Premium Monthly', '₹99', '/ month', 'Subscribe Now', true)),
              const SizedBox(width: 8),
              Expanded(child: _buildPlanTile('Lifetime Plan', '₹1999', '/ one-time', 'Get Lifetime', false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanTile(String title, String price, String suffix, String cta, bool featured) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: featured ? _blueSoft : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: featured ? _blue : const Color(0xFFD1DBF8), width: featured ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(999)),
              child: const Text('Most Popular', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: price,
                  style: const TextStyle(color: _navy, fontSize: 26, fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: suffix,
                  style: const TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('✓ Basic tools', style: TextStyle(fontSize: 12, color: _textMuted)),
          const Text('✓ Secure processing', style: TextStyle(fontSize: 12, color: _textMuted)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: featured ? _blue : Colors.white,
                foregroundColor: featured ? Colors.white : _blue,
                side: featured ? BorderSide.none : const BorderSide(color: _blue),
                minimumSize: const Size.fromHeight(34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: Text(cta),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 6),
              Text('Why Choose GET JOB READY?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _navy)),
            ],
          ),
          const SizedBox(height: 10),
          ..._whyItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 11, backgroundColor: item.color.withOpacity(0.15), child: Icon(item.icon, size: 13, color: item.color)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(color: _navy, fontWeight: FontWeight.w700)),
                        Text(item.subtitle, style: const TextStyle(fontSize: 12, color: _textMuted)),
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

  Widget _buildTrustStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE6FF)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF64748B), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text('Trusted by thousands of users worldwide', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700)),
          ),
          Text('⭐ ⭐ ⭐ ⭐ ⭐  4.8/5', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blueDark, _blue],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GET JOB READY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('The fastest document toolkit for global users', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Tools', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('Pricing', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Help Center', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('Terms', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _SocialDot(Icons.facebook, _blue),
              SizedBox(width: 8),
              _SocialDot(Icons.flutter_dash_rounded, _blueDark),
              SizedBox(width: 8),
              _SocialDot(Icons.play_circle_fill_rounded, Color(0xFFDC2626)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final String title;
  final IconData icon;
  final String route;
  final bool active;

  const _SidebarItem(this.title, this.icon, this.route, this.active);
}

class _ToolCardModel {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final String route;

  const _ToolCardModel(this.title, this.subtitle, this.icon, this.iconBg, this.route);
}

class _WhyItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _WhyItem(this.icon, this.color, this.title, this.subtitle);
}

class _FormatIcon extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;

  const _FormatIcon(this.icon, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: fg, size: 21),
    );
  }
}

class _SocialDot extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SocialDot(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 13,
      backgroundColor: color,
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}
