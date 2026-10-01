class LotRecord {
  const LotRecord({
    required this.name,
    this.code = 0,
    this.productionStatusCode = 0,
    this.productionStatus = '',
    this.dietCode = 0,
    this.diet = '',
    this.dryingDays = 0,
    this.preCalvingDays = 0,
    this.pregnancyDiagnosis = 0,
    this.milkFeeding = 0,
    int stallType = 0,
    int? feedingLocation,
    this.active = true,
  }) : stallType = feedingLocation ?? stallType;

  final int code;
  final String name;
  final int productionStatusCode;
  final String productionStatus;
  final int dietCode;
  final String diet;
  final int dryingDays;
  final int preCalvingDays;
  final int pregnancyDiagnosis;
  final int milkFeeding;
  final int stallType;
  final bool active;

  int get feedingLocation => stallType;

  factory LotRecord.fromJson(Map<String, dynamic> json) {
    int number(String key) => int.tryParse('${json[key] ?? 0}') ?? 0;
    final activeValue = json['ATIVO'];
    return LotRecord(
      code: number('CODLOTE'),
      name: '${json['LOTE'] ?? ''}',
      productionStatusCode: number('CODSTATUSPRODUCAO'),
      productionStatus: '${json['STATUSPRODUCAO'] ?? ''}',
      dietCode: number('CODDIETA'),
      diet: '${json['DIETA'] ?? ''}',
      dryingDays: number('DIAS_SECAGEM'),
      preCalvingDays: number('DIAS_PREPARTO'),
      pregnancyDiagnosis: number('DG'),
      milkFeeding: number('ALEITAMENTO'),
      stallType: number('TIPOBAIA'),
      active: activeValue == true || activeValue.toString() == '1',
    );
  }
}
