// Stable backend program keys with alphabetically ordered display labels.
const teamCategories = <String, String>{
  'agriculture': 'Agriculture',
  'art_design': 'Art & design',
  'automotive': 'Automotive',
  'business': 'Business',
  'club': 'Club or community',
  'construction': 'Construction',
  'custom': 'Custom category',
  'education': 'Education or school',
  'electronics': 'Electronics',
  'engineering': 'Engineering',
  'hospitality': 'Events & hospitality',
  'manufacturing': 'Factory & manufacturing',
  'fll': 'FIRST LEGO League',
  'frc': 'FIRST Robotics Competition',
  'ftc': 'FIRST Tech Challenge',
  'healthcare': 'Healthcare',
  'household': 'Household',
  'laboratory': 'Laboratory',
  'logistics': 'Logistics & warehouse',
  'makerspace': 'Makerspace or workshop',
  'nonprofit': 'Nonprofit',
  'office': 'Office',
  'other': 'Other',
  'research': 'Research',
  'retail': 'Retail',
  'robotics': 'Robotics',
  'sports': 'Sports & recreation',
  'studio': 'Studio & media',
  'vex': 'VEX Robotics',
};

String teamCategoryLabel(String? program, [String? customCategory]) {
  if (program == 'custom' && (customCategory?.trim().isNotEmpty ?? false)) {
    return customCategory!.trim();
  }
  return teamCategories[program] ?? 'Team';
}
