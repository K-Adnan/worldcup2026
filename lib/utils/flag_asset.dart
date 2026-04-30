String flagAssetForTeam(String teamName) {
  const aliases = <String, String>{
    'USA': 'United States',
    'Turkey': 'Türkiye',
    'Curacao': 'Curaçao',
    'Bosnia-Herzegovina': 'Bosnia',
    'Bosnia & Herzegovina': 'Bosnia',
    'Bosnia and Herzegovina': 'Bosnia',
    'Czechia': 'Czech Republic',
    'Congo DR': 'DR Congo',
  };

  final normalized = aliases[teamName] ?? teamName;
  final slug = normalized
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('é', 'e')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  return 'assets/flags/$slug.png';
}

String roundFlagAssetForTeam(String teamName) {
  const aliases = <String, String>{
    'USA': 'United States',
    'Turkey': 'Türkiye',
    'Curacao': 'Curaçao',
    'Czechia': 'Czech Republic',
    'Congo DR': 'DR Congo',
  };

  final normalized = aliases[teamName] ?? teamName;
  final slug = normalized
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('é', 'e')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  return 'assets/flags_round/$slug.svg';
}
