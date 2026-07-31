class CompanyInsightsService {
  static String fetchCompanyInsights(String companyName) {
    final normalized = companyName.trim();
    if (normalized.isEmpty) {
      return 'Enter a company name to fetch intelligence.';
    }

    final sample = <String, String>{
      'overallRating': '4.3/5',
      'workCulture': 'Collaborative, growth-oriented, strong learning culture',
      'salaryRange': '₹18–30 LPA for mid-level roles',
      'pros': 'Great mentorship, strong brand reputation, hybrid work flexibility',
      'cons': 'Rapid delivery pressure, competitive internal mobility',
    };

    final lower = normalized.toLowerCase();
    final companyLabel = lower.isEmpty ? 'company' : normalized;

    return '''Company: $companyLabel\n\n'
'Overall Rating: ${sample['overallRating']}\n'
'Work Culture / Atmosphere: ${sample['workCulture']}\n'
'Average Salary Range: ${sample['salaryRange']}\n'
'Pros: ${sample['pros']}\n'
'Cons: ${sample['cons']}''';
  }
}
