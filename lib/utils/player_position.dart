String abbreviatePlayerPosition(String position) {
  final normalized = position.trim().toLowerCase().replaceAll('-', ' ');
  const map = <String, String>{
    'goalkeeper': 'GK',
    'centre back': 'CB',
    'left back': 'LB',
    'right back': 'RB',
    'defensive midfielder': 'DM',
    'defensive midfield': 'DM',
    'central midfielder': 'CM',
    'central midfield': 'CM',
    'attacking midfielder': 'AM',
    'attacking midfield': 'AM',
    'striker': 'ST',
    'second striker': 'SS',
    'centre forward': 'CF',
    'centre-forward': 'CF',
    'left wing': 'LW',
    'left winger': 'LW',
    'right wing': 'RW',
    'right winger': 'RW',
  };
  return map[normalized] ?? position;
}
