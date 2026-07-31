import 'dart:convert';

import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

class AiCoverLetterService {
  static String buildCoverLetter({
    required String fullName,
    required String email,
    required String phone,
    required String experience,
    required String skills,
    required String projects,
    required String targetRole,
    required String summary,
    required String jd,
    required bool mncStandard,
    required String selectedTier,
  }) {
    final role = targetRole.trim().isEmpty ? 'the target role' : targetRole.trim();
    final shortJd = jd.trim().isEmpty ? 'the role requirements and business context' : jd.trim();
    final tone = mncStandard ? 'MNC-standard structure and professional tone' : 'clear and practical business tone';

    return '''Dear Hiring Manager,

I am excited to apply for the $role position. With a strong foundation in $summary and hands-on experience aligned to $shortJd, I am confident in my ability to contribute meaningfully to your team.

My background reflects a strong command of $skills, and my professional experience in $experience demonstrates a results-oriented approach to delivery. I have also built impact through $projects, which has strengthened my ability to collaborate, solve problems, and deliver consistent outcomes in fast-moving environments.

I am particularly interested in this opportunity because it aligns well with my experience level ($selectedTier) and my interest in contributing with $tone. I would welcome the opportunity to discuss how my profile can support your team’s objectives and help drive value from day one.

Thank you for your time and consideration. I look forward to the possibility of speaking with you further.

Sincerely,
$fullName
$email
$phone''';
  }

  static String buildInterviewQuestions({
    required String targetRole,
    required String jd,
    required String experience,
    required String skills,
    required String summary,
  }) {
    final role = targetRole.trim().isEmpty ? 'the target role' : targetRole.trim();
    final jdText = jd.trim().isEmpty ? 'the role requirements' : jd.trim();
    final skillList = skills.trim().isEmpty ? 'your core strengths' : skills.trim();

    if (jd.trim().isNotEmpty) {
      return '''1. Based on the JD, how would you describe your fit for $role and the specific requirements in "$jdText"?
2. Tell us about a project where you used $skillList to deliver a high-impact outcome.
3. How would you adapt your approach when the expectations in the JD shift midway through a delivery cycle?
4. Describe a time when you had to learn a new tool or process quickly to meet a business requirement.
5. How do you prioritize competing deliverables when stakeholders expect fast results and strong quality?
6. What metrics or evidence would you share to prove your impact for this role?
7. How would you communicate progress and blockers effectively in an MNC-style environment?
8. What questions would you ask the team to better understand the scope described in the JD?''';
    }

    return '''1. Tell us about your background and experience that makes you a strong candidate for $role.
2. How does your experience in $experience support your fit for this position?
3. Which of your skills from $skillList are most relevant to this job?
4. Describe a time when you used your strengths to solve a business or team problem.
5. How do you approach learning new tools or processes quickly when joining a new role?
6. How would you present your achievements and value to a hiring manager based on $summary?
7. What makes you a good cultural fit for a fast-paced, professional environment?
8. What questions would you ask about the role and team before joining?''';
  }

  static void openWhatsApp(String message) {
    final encoded = Uri.encodeComponent(message);
    html.window.open('https://wa.me/?text=$encoded', '_blank');
  }

  static void openEmail(String subject, String body) {
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);
    html.window.open('mailto:?subject=$encodedSubject&body=$encodedBody', '_blank');
  }

  static void openGoogleDrive() {
    html.window.open('https://drive.google.com/drive/my-drive', '_blank');
  }

  static void openOneDrive() {
    html.window.open('https://onedrive.live.com/', '_blank');
  }

  static Future<void> shareText(String text, {String subject = 'AI Resume Builder export'}) async {
    await Share.share(text, subject: subject);
  }

  static void downloadTextFile(String content, String fileName) {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'text/plain;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
    anchor.remove();
  }
}
