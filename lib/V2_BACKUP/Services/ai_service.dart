class AiResponse {
  final String title;
  final String answer;
  final List<String> followUps;

  const AiResponse({
    required this.title,
class WritingResponse {
  final String title;
  final String draft;
  final List<String> suggestions;

  const WritingResponse({
    required this.title,
    required this.draft,
    required this.suggestions,
  });
}
    required this.answer,
    required this.followUps,
  });
}

class AiService {
  static AiResponse generateResponse({
    required String questionType,
    required String fileName,
    required String prompt,
  }) {
    final cleanPrompt = prompt.trim();
    final cleanFileName = fileName.trim().isEmpty ? 'the selected document' : fileName.trim();

    switch (questionType) {
      case 'Summarize document':
        return AiResponse(
          title: 'Document summary',
          answer:
              'Here is a concise summary of $cleanFileName: it appears to be a structured business document. The main goal is to keep the key points, dates, names, and action items clear for review. Prompt note: ${cleanPrompt.isEmpty ? 'no custom note added.' : cleanPrompt}',
          followUps: const [
            'List the key dates',
            'Explain this in simple English',
            'Turn this into an email draft',
          ],
        );
      case 'Explain simply':
        return AiResponse(
          title: 'Simple English explanation',
          answer:
              '$cleanFileName can be explained in plain English as a document that needs a quick human-friendly explanation. The best next step is to extract the purpose, action points, and any deadlines before sharing it with others.',
          followUps: const [
            'Summarize the page',
            'Find important dates',
            'Compare with another file',
          ],
        );
      case 'Find dates':
        return AiResponse(
          title: 'Important dates',
          answer:
              'For $cleanFileName, look for dates in headers, deadlines, payment sections, and signature blocks. If the file is scanned or image-based, OCR should be applied before review to improve date detection.',
          followUps: const [
            'Summarize document',
            'Compare two documents',
            'Create email based on document',
          ],
        );
      case 'Compare documents':
        return AiResponse(
          title: 'Comparison guidance',
          answer:
              'To compare documents, line up the purpose, dates, names, numbers, and requested action items. If you upload a second file later, V2 can compare the two document structures side by side.',
          followUps: const [
            'List missing data',
            'Explain simply',
            'Draft an email reply',
          ],
        );
      case 'Create email':
        return AiResponse(
          title: 'Email draft',
          answer:
              'Subject: Follow-up regarding $cleanFileName\n\nHello,\n\nPlease review the attached document and share the next steps when convenient. I have also noted the key items from the latest version.\n\nRegards,',
          followUps: const [
            'Shorten the email',
            'Make it more formal',
            'Turn it into a job application note',
          ],
        );
      default:
        return AiResponse(
          title: 'AI response',
          answer:
              'The assistant is ready. Ask a document question and the local V2 assistant will draft a structured answer for $cleanFileName.',
          followUps: const [
            'Summarize document',
            'Explain simply',
            'Create email',
          ],
        );
    }
  }

  static WritingResponse generateWritingDraft({
    required String mode,
    required String tone,
    required String prompt,
    required String contextNote,
  }) {
    final cleanPrompt = prompt.trim();
    final cleanContext = contextNote.trim();
    final modeLabel = mode.toLowerCase();

    String draft;
    List<String> suggestions;

    switch (modeLabel) {
      case 'email':
        draft = 'Subject: ${tone.toLowerCase()} follow-up\n\nHello,\n\n${cleanPrompt.isEmpty ? 'I am reaching out to share a concise update and request the next steps.' : cleanPrompt}\n\n${cleanContext.isEmpty ? 'Thank you for your time and consideration.' : cleanContext}\n\nRegards,';
        suggestions = const [
          'Keep the subject line short and direct',
          'Use one clear action request',
          'Trim extra detail if the email is for a recruiter',
        ];
        break;
      case 'sop':
        draft = 'Statement of Purpose\n\n${cleanPrompt.isEmpty ? 'I am motivated to apply because the role aligns with my background and long-term goals.' : cleanPrompt}\n\n${cleanContext.isEmpty ? 'I aim to contribute through strong discipline, clear communication, and structured work habits.' : cleanContext}\n\nThis draft is written in a ${tone.toLowerCase()} tone and can be refined with more academic details.';
        suggestions = const [
          'Add specific achievements or projects',
          'Mention the exact program or employer',
          'Keep the opening focused and sincere',
        ];
        break;
      case 'job application':
        draft = 'Application Note\n\n${cleanPrompt.isEmpty ? 'I am applying for the role and would like to highlight relevant experience and reliability.' : cleanPrompt}\n\n${cleanContext.isEmpty ? 'Please review my background and let me know if additional details are needed.' : cleanContext}\n\nThis version keeps the message ${tone.toLowerCase()} and focused on value.';
        suggestions = const [
          'Add the exact job title',
          'Mention the top two matching skills',
          'Include a short closing line',
        ];
        break;
      case 'rewrite':
        draft = '${cleanPrompt.isEmpty ? 'Paste the text you want to improve here.' : cleanPrompt}\n\nRewritten in a ${tone.toLowerCase()} style with clearer structure and smoother flow. ${cleanContext.isEmpty ? '' : cleanContext}';
        suggestions = const [
          'Keep the same meaning while shortening long sentences',
          'Replace weak verbs with stronger ones',
          'Check the final version for names and dates',
        ];
        break;
      case 'cover letter':
      default:
        draft = 'Dear Hiring Manager,\n\n${cleanPrompt.isEmpty ? 'I am excited to apply because the opportunity matches my strengths and goals.' : cleanPrompt}\n\n${cleanContext.isEmpty ? 'I bring strong attention to detail, dependable delivery, and a willingness to learn.' : cleanContext}\n\nThis cover letter is set in a ${tone.toLowerCase()} tone and can be tailored further to the job description.\n\nSincerely,';
        suggestions = const [
          'Add the company name and role title',
          'Insert one measurable achievement',
          'Keep the closing strong and brief',
        ];
        break;
    }

    return WritingResponse(
      title: '$mode - $tone',
      draft: draft,
      suggestions: suggestions,
    );
  }
}
