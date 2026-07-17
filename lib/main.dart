import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'Widgets/feature_tile.dart';
import 'Widgets/pricing_card.dart';
import 'Widgets/pdf_tool_card.dart';
import 'Services/public_brand_config.dart';
import 'Pages/home_page_v2.dart';
import 'Pages/convert_tool_page.dart';
import 'Pages/compression_tool_page.dart';
import 'Pages/merge_tool_page.dart';
import 'Pages/split_tool_page.dart';
import 'Pages/extract_tool_page.dart';
import 'Pages/pdf_tools_page.dart';
import 'Pages/pdf_edit_page.dart';
// ===============================
// GLOBAL RESUME DATA MODEL
// ===============================

class ResumeData {
  static String fullName = "RAJESH YADAV";
  static String jobTitle = "Cargo Revenue Accounting Specialist";
  static String email = "";
  static String phone = "";
  static String city = "";
  static String summary = "";
  static String experience = "";
  static String education = "";

  static List<String> skills = [
    "Cargo Accounting",
    "Revenue Accounting",
    "SAP",
    "Excel",
  ];
}

final ValueNotifier<String?> _fatalErrorMessage = ValueNotifier<String?>(null);

void _recordFatalError(Object error, StackTrace? stackTrace) {
  final trace = stackTrace == null ? '' : '\n\n$stackTrace';
  _fatalErrorMessage.value = '$error$trace';
}

void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _recordFatalError(details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _recordFatalError(error, stack);
    return true;
  };

  runZonedGuarded(
    () => runApp(const JobReadyApp()),
    (error, stack) {
      _recordFatalError(error, stack);
    },
  );
}

String _normalizeRouteName(String? rawRoute) {
  var route = (rawRoute ?? '/').trim();
  if (route.isEmpty) {
    return '/';
  }

  final hashIndex = route.indexOf('#');
  if (hashIndex >= 0 && hashIndex + 1 < route.length) {
    route = route.substring(hashIndex + 1);
  }

  final queryIndex = route.indexOf('?');
  if (queryIndex >= 0) {
    route = route.substring(0, queryIndex);
  }

  if (!route.startsWith('/')) {
    route = '/$route';
  }

  return route.isEmpty ? '/' : route;
}

String _resolveInitialRouteFromUrl() {
  final fromHash = Uri.base.fragment.trim();
  if (fromHash.isNotEmpty) {
    return _normalizeRouteName(fromHash);
  }

  final fromPath = Uri.base.path.trim();
  if (fromPath.isNotEmpty) {
    return _normalizeRouteName(fromPath);
  }

  return '/home';
}

class JobReadyApp extends StatelessWidget {
const JobReadyApp({super.key});

static final String _initialRoute = _resolveInitialRouteFromUrl();

Widget _buildFatalErrorFallback(String message) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'JOBREADY startup error',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'The app could not complete initialization. Please refresh and retry.',
                style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Route<dynamic> _buildRoute(String name) {
  switch (name) {
    case '/':
    case '/home':
      return MaterialPageRoute(builder: (_) => const HomePageV2(), settings: const RouteSettings(name: '/home'));
    case '/compress':
      return MaterialPageRoute(builder: (_) => const CompressionToolPage(), settings: const RouteSettings(name: '/compress'));
    case '/convert':
      return MaterialPageRoute(builder: (_) => const ConvertToolPage(), settings: const RouteSettings(name: '/convert'));
    case '/merge':
      return MaterialPageRoute(builder: (_) => const MergeToolPage(), settings: const RouteSettings(name: '/merge'));
    case '/split':
      return MaterialPageRoute(builder: (_) => const SplitToolPage(), settings: const RouteSettings(name: '/split'));
    case '/extract':
      return MaterialPageRoute(builder: (_) => const ExtractToolPage(), settings: const RouteSettings(name: '/extract'));
    case '/pdf-tools':
      return MaterialPageRoute(builder: (_) => const PdfToolsPage(), settings: const RouteSettings(name: '/pdf-tools'));
    case '/pdf-edit':
      return MaterialPageRoute(builder: (_) => const PdfEditPage(), settings: const RouteSettings(name: '/pdf-edit'));
    default:
      return MaterialPageRoute(builder: (_) => const HomePageV2(), settings: const RouteSettings(name: '/home'));
  }
}

@override
Widget build(BuildContext context) {
  return ValueListenableBuilder<String?>(
    valueListenable: _fatalErrorMessage,
    builder: (context, errorMessage, _) {
      if (errorMessage != null && errorMessage.trim().isNotEmpty) {
        return _buildFatalErrorFallback(errorMessage);
      }

      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'JOBREADY',
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1F2937),
            foregroundColor: Colors.white,
          ),
          useMaterial3: true,
        ),
        initialRoute: _initialRoute,
        onGenerateRoute: (settings) {
          final normalized = _normalizeRouteName(settings.name);
          return _buildRoute(normalized);
        },
        onUnknownRoute: (_) => _buildRoute('/home'),
      );
    },
  );
}
}

class HomePage extends StatelessWidget {
const HomePage({super.key});

void showMessage(BuildContext context, String title) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('$title feature coming soon'),
),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
  backgroundColor: const Color(0xFF1F2937),
  centerTitle: true,

    title: const Text(
    'JOBREADY',
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.5,
    ),
  ),
),
body: SingleChildScrollView(
padding: const EdgeInsets.all(15),
child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,
children: [


        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF003A70),
                Color(0xFFFFC72C),
              ],
            ),
          ),
          child: const Column(
            children: [

              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  'G',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),

              SizedBox(height: 18),

              Text(
                'JOBREADY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),

              SizedBox(height: 10),

              Text(
                'Smart Document & Career Toolkit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),

              SizedBox(height: 14),

              Text(
                "Tell us what you need.\nWe'll do the rest.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                '🚀 What would you like to do today?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),

              SizedBox(height: 24),

              Container(
height: 600,
child: GridView.count(
crossAxisCount: 2,
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
crossAxisSpacing: 12,
mainAxisSpacing: 12,
childAspectRatio: 2.5,
children: [
InkWell(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PdfToolsPage(),
      ),
    );
  },
  child: Card(
    elevation: 10,
    color: const Color(0xFFFFF0F0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: const [
    SizedBox(height: 4),
Icon(Icons.picture_as_pdf, size: 35, color: Colors.red),
SizedBox(height: 2),
Text(
'PDF Tools',
style: TextStyle(fontWeight: FontWeight.bold),
),
Text('Convert & Edit'),
],
),
),
),

  InkWell(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PhotoToolsPage(),
      ),
    );
  },
  child: Card(
    elevation: 10,
    color: const Color(0xFFF0FFF4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        SizedBox(height: 4),
        Icon(
          Icons.photo,
          size: 35,
          color: Colors.green,
        ),
        SizedBox(height: 2),
        Text(
          'Photo Tools',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text('Resize & Repair'),
      ],
    ),
  ),
),

  InkWell(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DocumentsPage(),
      ),
    );
  },
  child: Card(
    elevation: 10,
    color: const Color(0xFFF0F8FF),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        SizedBox(height: 4),
        Icon(Icons.folder,
            size: 35,
            color: Colors.blue),
        SizedBox(height: 2),
        Text(
          'Documents',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text('Organize Files'),
      ],
    ),
  ),
),

  InkWell(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CareerToolsPage(),
      ),
    );
  },
  child: Card(
    elevation: 10,
    color: const Color(0xFFFFF8E8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        SizedBox(height: 4),
        Icon(Icons.work,
            size: 35,
            color: Colors.orange),
        SizedBox(height: 2),
        Text(
          'Career Tools',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text('Resume & Jobs'),
      ],
    ),
  ),
),
],

),
),

            ],
          ),
        ),

        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: () {},
          child: const Padding(
            padding: EdgeInsets.all(15),
            child: Text(
              'Launch Tools',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),

        const SizedBox(height: 25),

const Text(
'PDF Tools',
style: TextStyle(
fontSize: 24,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 10),

FeatureTile(
icon: Icons.picture_as_pdf,
title: 'PDF to Word',
onTap: () => showMessage(context, 'PDF to Word'),
),

FeatureTile(
icon: Icons.description,
title: 'Word to PDF',
onTap: () => showMessage(context, 'Word to PDF'),
),

FeatureTile(
icon: Icons.image,
title: 'Image to PDF',
onTap: () => showMessage(context, 'Image to PDF'),
),

PdfToolCard(
  icon: Icons.merge_type,
  title: 'Merge PDF',
  subtitle: 'Combine multiple PDF files',
  onTap: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Merge PDF feature coming soon'),
      ),
    );
  },
),

PdfToolCard(
  icon: Icons.content_cut,
  title: 'Split PDF',
  subtitle: 'Extract pages from PDF files',
  onTap: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Split PDF feature coming soon'),
      ),
    );
  },
),

PdfToolCard(
  icon: Icons.compress,
  title: 'Compress PDF',
  subtitle: 'Reduce PDF file size',
  onTap: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compress PDF feature coming soon'),
      ),
    );
  },
),

const SizedBox(height: 25),

const Text(
'Why Choose JOBREADY?',
style: TextStyle(
fontSize: 24,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 10),

const Card(
child: Padding(
padding: EdgeInsets.all(15),
child: Column(
children: [
ListTile(
leading: Icon(Icons.speed),
title: Text('Fast Processing'),
),
ListTile(
leading: Icon(Icons.security),
title: Text('Secure Files'),
),
ListTile(
leading: Icon(Icons.public),
title: Text('Global Access'),
),
ListTile(
leading: Icon(Icons.phone_android),
title: Text('Mobile & Desktop Friendly'),
),
],
),
),
),

const SizedBox(height: 25),

const Text(
'Pricing Plans',
style: TextStyle(
fontSize: 24,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 10),

const PricingCard(
  title: 'Weekly Pass',
  price: '\$0.99',
  color: Colors.green,
),

const PricingCard(
  title: 'Pro Monthly',
  price: '\$2.99',
  color: Colors.blue,
),

const PricingCard(
  title: 'Lifetime Pro',
  price: '\$24.99',
  color: Colors.orange,
),

const SizedBox(height: 25),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  const Text(
                    'Contact Us',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Website: ${PublicBrandConfig.websiteDomain}'),
                  const Text('WhatsApp: +91 98991 15572'),
                  Text('Email: ${PublicBrandConfig.supportEmail}'),
                ],
              ),
            ),

const SizedBox(height: 25),

const Divider(),

Center(
child: Column(
children: [
const Text(
'JOBREADY',
style: TextStyle(
fontWeight: FontWeight.bold,
),
),
const Text('Smart Document & Career Toolkit'),
Text(PublicBrandConfig.websiteDomain),
const SizedBox(height: 5),
const Text('© 2026 JOBREADY'),
],
),
),

const SizedBox(height: 20),
],
),
),
);
}

}





class PhotoToolsPage extends StatelessWidget {
  const PhotoToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFF1F2937),

  iconTheme: const IconThemeData(
    color: Color(0xFFFFC72C),
  ),

  title: const Text(
    'Photo Tools',
    style: TextStyle(
      color: Color(0xFFFFC72C),
      fontWeight: FontWeight.bold,
    ),
  ),
),
      body: Padding(
  padding: const EdgeInsets.all(20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [

      ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resize Image feature coming soon'),
            ),
          );
        },
        child: const Text('Resize Image'),
      ),

      const SizedBox(height: 10),

      ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compress Image feature coming soon'),
            ),
          );
        },
        child: const Text('Compress Image'),
      ),

      const SizedBox(height: 10),

      ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image to PDF feature coming soon'),
            ),
          );
        },
        child: const Text('Image to PDF'),
      ),

      const SizedBox(height: 10),

      ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Restore Photo feature coming soon'),
            ),
          );
        },
        child: const Text('Restore Photo'),
      ),

      const SizedBox(height: 10),

      ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Remove Background feature coming soon'),
            ),
          );
        },
        child: const Text('Remove Background'),
      ),
    ],
  ),
),
    );
  }
}
void showMessage(BuildContext context, String title) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(title),
    ),
  );
}
class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFF1F2937),

  iconTheme: const IconThemeData(
    color: Color(0xFFFFC72C),
  ),

  title: const Text(
    'Documents',
    style: TextStyle(
      color: Color(0xFFFFC72C),
      fontWeight: FontWeight.bold,
    ),
  ),
),
      body: Padding(
  padding: const EdgeInsets.all(20),
  child: Column(
    children: [

      PdfToolCard(
  icon: Icons.description,
  title: 'Word to PDF',
  subtitle: 'Convert Word documents into PDF',
  onTap: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Word to PDF feature coming soon'),
      ),
    );
  },
),
      FeatureTile(
        icon: Icons.text_snippet,
        title: 'TXT Viewer',
        onTap: () => showMessage(
          context,
          'TXT Viewer Coming Soon',
        ),
      ),

      FeatureTile(
        icon: Icons.note,
        title: 'Notes',
        onTap: () => showMessage(
          context,
          'Notes Coming Soon',
        ),
      ),

      FeatureTile(
        icon: Icons.folder,
        title: 'File Manager',
        onTap: () => showMessage(
          context,
          'File Manager Coming Soon',
        ),
      ),

      FeatureTile(
        icon: Icons.history,
        title: 'Recent Files',
        onTap: () => showMessage(
          context,
          'Recent Files Coming Soon',
        ),
      ),

      FeatureTile(
        icon: Icons.upload_file,
        title: 'Export Documents',
        onTap: () => showMessage(
          context,
          'Export Documents Coming Soon',
        ),
      ),

    ],
  ),
),
);
}
}
 class CareerToolsPage extends StatelessWidget {

  const CareerToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFF1F2937),

  iconTheme: const IconThemeData(
    color: Color(0xFFFFC72C),
  ),

  title: const Text(
    'Career Tools',
    style: TextStyle(
      color: Color(0xFFFFC72C),
      fontWeight: FontWeight.bold,
    ),
  ),
),
      body: Padding(
  padding: const EdgeInsets.all(20),
  child: Column(
    children: [

      FeatureTile(
  icon: Icons.description,
  title: 'Resume Builder',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ResumeBuilderPage(),
      ),
    );
  },
),

FeatureTile(
  icon: Icons.article,
  title: 'CV Templates',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CvTemplatesPage(),
      ),
    );
  },
),
      FeatureTile(
        icon: Icons.edit_document,
        title: 'Cover Letter',
        onTap: () => showMessage(
          context,
          'Cover Letter Coming Soon',
        ),
      ),

      FeatureTile(
        icon: Icons.search,
        title: 'Job Search',
        onTap: () => showMessage(
          context,
          'Job Search Coming Soon',
        ),
      ),

      FeatureTile(
        icon: Icons.question_answer,
        title: 'Interview Questions',
        onTap: () => showMessage(
          context,
          'Interview Questions Coming Soon',
        ),
      ),

      FeatureTile(
        icon: Icons.people,
        title: 'LinkedIn Helper',
        onTap: () => showMessage(
          context,
          'LinkedIn Helper Coming Soon',
        ),
      ),

    ],
  ),
),
    );
  }
}
// ======================================
// JOBREADY Global Resume Data
// ======================================

String globalName = '';
String globalEmail = '';
String globalPhone = '';
String globalObjective = '';
String globalExperience = '';
String globalEducation = '';
String globalSkills = '';
  class ResumeBuilderPage extends StatefulWidget {
  const ResumeBuilderPage({super.key});

  @override
  State<ResumeBuilderPage> createState() =>
      _ResumeBuilderPageState();
}

class _ResumeBuilderPageState
    extends State<ResumeBuilderPage> {

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final objectiveController =
    TextEditingController();

final experienceController =
    TextEditingController();

final educationController =
    TextEditingController();

final skillsController =
    TextEditingController();

  String resumeOutput = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFF1F2937),

  iconTheme: const IconThemeData(
    color: Color(0xFFFFC72C),
  ),

  title: const Text(
    'Resume Builder',
    style: TextStyle(
      color: Color(0xFFFFC72C),
      fontWeight: FontWeight.bold,
    ),
  ),
),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
const SizedBox(height: 12),

TextField(
  controller: objectiveController,
  decoration: const InputDecoration(
    labelText: 'Career Objective',
    border: OutlineInputBorder(),
  ),
),
            const SizedBox(height: 12),

            TextField(
              controller: experienceController,
              decoration: const InputDecoration(
                labelText: 'Experience',
                border: OutlineInputBorder(),
              ),
            ),
const SizedBox(height: 12),

TextField(
  controller: educationController,
  decoration: const InputDecoration(
    labelText: 'Education',
    border: OutlineInputBorder(),
  ),
),
            const SizedBox(height: 12),

            TextField(
              controller: skillsController,
              decoration: const InputDecoration(
                labelText: 'Skills',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {

  globalName = nameController.text;
  globalEmail = emailController.text;
  globalPhone = phoneController.text;
  globalObjective = objectiveController.text;
  globalExperience = experienceController.text;
  globalEducation = educationController.text;
  globalSkills = skillsController.text;


                setState(() {
                 resumeOutput =
'''
${nameController.text.toUpperCase()}

━━━━━━━━━━━━━━━━━━

EMAIL
${emailController.text}

PHONE
${phoneController.text}

CAREER OBJECTIVE
${objectiveController.text}

EXPERIENCE
${experienceController.text}

EDUCATION
${educationController.text}

SKILLS
${skillsController.text}
''';
                });

              },
              child: const Text(
                'Generate Resume',
              ),
            ),

            const SizedBox(height: 20),
ElevatedButton.icon(
  onPressed: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'PDF Export Coming Soon',
        ),
      ),
    );
  },
  icon: const Icon(Icons.picture_as_pdf),
  label: const Text('Export PDF'),
),

const SizedBox(height: 20),
            if (resumeOutput.isNotEmpty)

              Card(
  elevation: 6,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    resumeOutput,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
class CvTemplatesPage extends StatelessWidget {
  const CvTemplatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFF1F2937),

  iconTheme: const IconThemeData(
    color: Color(0xFFFFC72C),
  ),

  title: const Text(
    'CV Templates',
    style: TextStyle(
      color: Color(0xFFFFC72C),
      fontWeight: FontWeight.bold,
    ),
  ),
),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            FeatureTile(
  icon: Icons.business_center,
  title: 'Professional CV',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const ProfessionalCvPage(),
      ),
    );
  },
),

           FeatureTile(
  icon: Icons.auto_awesome,
  title: 'Modern CV',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const ModernCvPage(),
      ),
    );
  },
),

            FeatureTile(
  icon: Icons.workspace_premium,
  title: 'Executive CV',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const ExecutiveCvPage(),
      ),
    );
  },
),

            FeatureTile(
  icon: Icons.school,
  title: 'Student CV',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentCvPage(),
      ),
    );
  },
),

            FeatureTile(
  icon: Icons.flight,
  title: 'Airline CV',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const AirlineCvPage(),
      ),
    );
  },
),

          ],
        ),
      ),
    );
  }
}
class ProfessionalCvPage extends StatelessWidget {
  const ProfessionalCvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFF1F2937),

  iconTheme: const IconThemeData(
    color: Color(0xFFFFC72C),
  ),

  title: const Text(
    'Professional CV',
    style: TextStyle(
      color: Color(0xFFFFC72C),
      fontWeight: FontWeight.bold,
    ),
  ),
),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                Text(
  globalName.isEmpty
      ? 'RAJESH YADAV'
      : globalName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  'Cargo Revenue Accounting Specialist',
                ),

                Divider(height: 30),

                Text(
                  'PROFILE',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(height: 8),

                Text(
  globalObjective.isEmpty
      ? 'Experienced airline cargo accounting professional with strong knowledge of revenue accounting and cargo operations.'
      : globalObjective,
),

                SizedBox(height: 20),

                Text(
                  'EXPERIENCE',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(height: 8),

                Text(
  globalExperience.isEmpty
      ? '18 Years Airline Cargo Accounting Experience'
      : globalExperience,
),

                SizedBox(height: 20),

                Text(
                  'SKILLS',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(height: 8),

                Text(
  globalSkills.isEmpty
      ? '• Cargo Accounting\n'
        '• Revenue Accounting\n'
        '• Excel\n'
        '• Data Analysis'
      : globalSkills,
),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class ModernCvPage extends StatelessWidget {
  const ModernCvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFF1F2937),

  iconTheme: const IconThemeData(
    color: Color(0xFFFFC72C),
  ),

  title: const Text(
    'Modern CV',
    style: TextStyle(
      color: Color(0xFFFFC72C),
      fontWeight: FontWeight.bold,
    ),
  ),
),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black12,
              ),
            ],
          ),
          child: Column(
            children: [

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFF003A70),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: Column(
                  children: [

                    CircleAvatar(
                      radius: 42,
                      child: Icon(
                        Icons.person,
                        size: 45,
                      ),
                    ),

                    SizedBox(height: 12),

                    Text(
  globalName.isEmpty
      ? 'RAJESH YADAV'
      : globalName.toUpperCase(),
  style: const TextStyle(
    color: Colors.white,
    fontSize: 28,
    fontWeight: FontWeight.bold,
  ),
),

                    SizedBox(height: 6),

                    Text(
                        globalExperience.isEmpty
      ? 'Airline Cargo Professional'
      : globalExperience,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    Text(
                      'ABOUT ME',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    SizedBox(height: 10),

                    Text(
globalObjective.isEmpty
    ? 'Experienced cargo accounting specialist with 18 years of airline experience.'
    : globalObjective,
),

                    SizedBox(height: 20),

                    Text(
                      'CORE SKILLS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    SizedBox(height: 10),

                    Wrap(
  spacing: 10,
  runSpacing: 10,
  children: (globalSkills.isEmpty
          ? [
              'Cargo',
              'Accounting',
              'Excel',
              'SAP',
              'Revenue',
            ]
          : globalSkills.split(','))
      .map(
        (skill) => Chip(
          label: Text(skill.trim()),
        ),
      )
      .toList(),
),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class ExecutiveCvPage extends StatelessWidget {
  const ExecutiveCvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFF1F2937),

  iconTheme: const IconThemeData(
    color: Color(0xFFFFC72C),
  ),

  title: const Text(
    'Executive CV',
    style: TextStyle(
      color: Color(0xFFFFC72C),
      fontWeight: FontWeight.bold,
    ),
  ),
),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Card(
          elevation: 8,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          child: Column(
            children: [

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),

                decoration: const BoxDecoration(
                  color: Color(0xFF263238),

                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),

                child: Column(
                  children: [

                    Icon(
                      Icons.workspace_premium,
                      color: Colors.amber,
                      size: 60,
                    ),

                    SizedBox(height: 16),

                    Text(
  globalName.isEmpty
      ? 'RAJESH YADAV'
      : globalName.toUpperCase(),
  style: const TextStyle(
    color: Colors.white,
    fontSize: 30,
    fontWeight: FontWeight.bold,
  ),
),

                    SizedBox(height: 8),

                    Text(
  globalExperience.isEmpty
      ? 'Senior Cargo Revenue Manager'
      : globalExperience,
  style: const TextStyle(
    color: Colors.white70,
    fontSize: 18,
  ),
),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.all(24),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    Text(
                      'EXECUTIVE SUMMARY',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 10),

                    Text(
  globalObjective.isEmpty
      ? 'Experienced airline professional with strong leadership, revenue accounting expertise and strategic decision-making skills.'
      : globalObjective,
),

                    SizedBox(height: 20),

                    Divider(),

                    SizedBox(height: 10),

                    Text(
                      'CORE COMPETENCIES',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 12),

                    ...(globalSkills.isEmpty
        ? [
            'Revenue Accounting',
            'Leadership',
            'Financial Analysis',
            'Team Management',
            'SAP / Excel',
          ]
        : globalSkills.split(','))
    .map(
      (skill) => ListTile(
        leading: const Icon(Icons.check_circle),
        title: Text(skill.trim()),
      ),
    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class StudentCvPage extends StatelessWidget {
  const StudentCvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFF1F2937),

  iconTheme: const IconThemeData(
    color: Color(0xFFFFC72C),
  ),

  title: const Text(
    'Student CV',
    style: TextStyle(
      color: Color(0xFFFFC72C),
      fontWeight: FontWeight.bold,
    ),
  ),
),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: const Column(
                  children: [

                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.school,
                        size: 45,
                        color: Color(0xFF1565C0),
                      ),
                    ),

                    SizedBox(height: 15),

                    Text(
                      'RAHUL SHARMA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'B.Com Graduate',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      'CAREER OBJECTIVE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Motivated and enthusiastic graduate seeking an opportunity to begin a successful professional career while continuously learning new skills.',
                    ),

                    const SizedBox(height: 25),

                    const Divider(),

                    const SizedBox(height: 15),

                    const Text(
                      'EDUCATION',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 12),

                    ListTile(
                      leading: const Icon(Icons.school),
                      title: const Text("Bachelor of Commerce"),
                      subtitle: const Text("University of Delhi"),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text("2025"),
                      ),
                    ),

                    const Divider(),

                    const SizedBox(height: 15),

                    const Text(
                      'KEY SKILLS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [

                        Chip(label: Text("MS Office")),
                        Chip(label: Text("Excel")),
                        Chip(label: Text("Communication")),
                        Chip(label: Text("Accounting")),
                        Chip(label: Text("Teamwork")),
                        Chip(label: Text("Problem Solving")),

                      ],
                    ),

                    const SizedBox(height: 25),

                    const Divider(),

                    const SizedBox(height: 15),

                    const Text(
                      'CERTIFICATIONS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const ListTile(
                      leading: Icon(Icons.workspace_premium),
                      title: Text("Advanced Excel"),
                    ),

                    const ListTile(
                      leading: Icon(Icons.workspace_premium),
                      title: Text("Tally ERP"),
                    ),

                    const ListTile(
                      leading: Icon(Icons.workspace_premium),
                      title: Text("Business Communication"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class AirlineCvPage extends StatelessWidget {
  const AirlineCvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFF1F2937),

  iconTheme: const IconThemeData(
    color: Color(0xFFFFC72C),
  ),

  title: const Text(
    'Airline CV',
    style: TextStyle(
      color: Color(0xFFFFC72C),
      fontWeight: FontWeight.bold,
    ),
  ),
),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Card(
          elevation: 8,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          child: Column(
            children: [

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),

                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF003A70),
                      Color(0xFF0055A5),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),

                child: const Column(
                  children: [

                    CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.flight_takeoff,
                        size: 42,
                        color: Color(0xFF003A70),
                      ),
                    ),

                    SizedBox(height: 15),

                    Text(
                      'RAJESH YADAV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 8),

                    Text(
                      'Cargo Revenue Accounting Specialist',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    const Text(
                      'PROFILE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Experienced airline cargo accounting professional with 18 years of expertise in cargo revenue accounting, airline finance, audit support, SAP and operational reporting.',
                    ),

                    const SizedBox(height: 25),

                    const Divider(),

                    const SizedBox(height: 15),

                    const Text(
                      'CORE SKILLS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: const [

                        Chip(label: Text('Cargo Accounting')),
                        Chip(label: Text('Revenue Accounting')),
                        Chip(label: Text('SAP')),
                        Chip(label: Text('Excel')),
                        Chip(label: Text('Airline Finance')),
                        Chip(label: Text('Audit')),
                      ],
                    ),

                    const SizedBox(height: 25),

                    const Divider(),

                    const SizedBox(height: 15),

                    const Text(
                      'EXPERIENCE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const ListTile(
                      leading: Icon(Icons.flight),
                      title: Text(
                        '18 Years Airline Cargo Accounting',
                      ),
                      subtitle: Text(
                        'International Airline Industry',
                      ),
                    ),

                    const ListTile(
                      leading: Icon(Icons.analytics),
                      title: Text(
                        'Revenue Accounting',
                      ),
                    ),

                    const ListTile(
                      leading: Icon(Icons.paid),
                      title: Text(
                        'Cargo Finance & Billing',
                      ),
                    ),

                    const ListTile(
                      leading: Icon(Icons.bar_chart),
                      title: Text(
                        'MIS Reporting & Analysis',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
