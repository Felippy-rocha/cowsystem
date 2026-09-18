class AnimalRecord {
  const AnimalRecord({
    required this.tag,
    required this.donor,
    required this.breed,
    required this.reproductiveStatus,
    this.electronicTag = '',
    this.lot = '',
    this.birthDate = '',
    this.productionStatus = '',
    this.origin = '',
    this.betaCasein = '',
    this.active = true,
  });

  final String tag;
  final String electronicTag;
  final String donor;
  final String lot;
  final String birthDate;
  final String breed;
  final String reproductiveStatus;
  final String productionStatus;
  final String origin;
  final String betaCasein;
  final bool active;

  factory AnimalRecord.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] ?? '').toString();
    final activeValue = json['ATIVO'];
    final donorValue = json['DOADORA'];
    return AnimalRecord(
      tag: text('BRINCO'),
      electronicTag: text('BRINCOELETRONICO'),
      donor: donorValue is num && donorValue == 1 ? 'Sim' : text('DOADORA'),
      lot: text('CODLOTE'),
      birthDate: text('DATANASCIMENTO'),
      breed: text('RACA'),
      reproductiveStatus: text('STATUSREPRODUCAO'),
      productionStatus: text('STATUSPRODUCAO'),
      origin: text('ORIGEM'),
      betaCasein: text('BETACASEINA'),
      active: activeValue == true || activeValue.toString() == '1',
    );
  }

  Map<String, dynamic> toJson() => {
    'BRINCO': tag,
    'BRINCOELETRONICO': electronicTag,
    'DOADORA': donor,
    'LOTE': lot,
    'DATANASCIMENTO': birthDate,
    'RACA': breed,
    'STATUSREPRODUCAO': reproductiveStatus,
    'STATUSPRODUCAO': productionStatus,
    'ORIGEM': origin,
    'BETACASEINA': betaCasein,
    'ATIVO': active ? 1 : 0,
  };
}
