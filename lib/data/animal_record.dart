class AnimalRecord {
  const AnimalRecord({
    required this.tag,
    required this.donor,
    required this.breed,
    required this.reproductiveStatus,
    this.animalCode = 0,
    this.electronicTag = '',
    this.lot = '',
    this.lotName = '',
    this.lotCode = 0,
    this.birthDate = '',
    this.productionStatus = '',
    this.lactationCode = '',
    this.inseminationCount = 0,
    this.lastInseminationDate = '',
    this.pregnancyDays = 0,
    this.expectedCalvingDate = '',
    this.lastCalvingDate = '',
    this.daysInMilk = 0,
    this.activeCode = 1,
    this.donorCode = 0,
    this.discardCode = 0,
    this.origin = '',
    this.betaCasein = '',
    this.active = true,
  });

  final String tag;
  final int animalCode;
  final String electronicTag;
  final String donor;
  final String lot;
  final String lotName;
  final int lotCode;
  final String birthDate;
  final String breed;
  final String reproductiveStatus;
  final String productionStatus;
  final String lactationCode;
  final int inseminationCount;
  final String lastInseminationDate;
  final int pregnancyDays;
  final String expectedCalvingDate;
  final String lastCalvingDate;
  final int daysInMilk;
  final int activeCode;
  final int donorCode;
  final int discardCode;
  final String origin;
  final String betaCasein;
  final bool active;

  String get displayLot => lotName.isEmpty ? lot : lotName;

  bool matchesRegistrationStatus(String status) {
    switch (status.toUpperCase()) {
      case 'ATIVO':
        return activeCode == 1 && (donorCode == 2 || donorCode == 3);
      case 'INATIVO':
        return activeCode == 2;
      case 'DOADORA EXTERNA':
        return donorCode == 1;
      case 'A DESCARTAR':
        return discardCode == 1 &&
            activeCode == 1 &&
            (donorCode == 2 || donorCode == 3);
      case 'DOADORA INTERNA':
        return donorCode == 3;
      default:
        return true;
    }
  }

  factory AnimalRecord.fromJson(Map<String, dynamic> json) {
    String text(String key) => (json[key] ?? '').toString();
    int number(String key) => int.tryParse(text(key)) ?? 0;
    final activeValue = json['ATIVO'];
    final donorValue = json['DOADORA'];
    return AnimalRecord(
      animalCode: number('CODANIMAL'),
      tag: text('BRINCO'),
      electronicTag: text('BRINCOELETRONICO'),
      donor: donorValue is num && donorValue == 1 ? 'Sim' : text('DOADORA'),
      lot: text('CODLOTE'),
      lotName: text('LOTE'),
      lotCode: number('CODLOTE'),
      birthDate: text('DATANASCIMENTO'),
      breed: text('RACA'),
      reproductiveStatus: text('STATUSREPRODUCAO'),
      productionStatus: text('STATUSPRODUCAO'),
      lactationCode: text('CODLACTACAOATUAL'),
      inseminationCount: number('NUMIA'),
      lastInseminationDate: text('DATAIA'),
      pregnancyDays: number('DP'),
      expectedCalvingDate: text('PREVISAOPARTO'),
      lastCalvingDate: text('ULTIMOPARTO'),
      daysInMilk: number('DEL'),
      activeCode: number('ATIVO'),
      donorCode: number('DOADORA'),
      discardCode: number('ADESCARTAR'),
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
