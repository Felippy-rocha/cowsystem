import 'dart:convert';

import 'lot_record.dart';
import 'soap_client.dart';

class LotRepository {
  LotRepository({required this.soapClient});

  final SoapClient soapClient;

  Future<List<LotRecord>> fetchLots() async {
    final response = await soapClient.callResult(
      action: 'Importar_Json',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_xmlEscape('SELECT L.CODLOTE, L.LOTE, L.CODSTATUSPRODUCAO, S.STATUSPRODUCAO, L.CODDIETA, D.DESCRICAO AS DIETA, L.DIAS_SECAGEM, L.DIAS_PREPARTO, L.DG, L.ALEITAMENTO, L.TIPOBAIA, L.ATIVO FROM TB_LOTES L LEFT JOIN TB_STATUSPRODUCAO S ON S.CODSTATUSPRODUCAO = L.CODSTATUSPRODUCAO LEFT JOIN TB_DIETA D ON D.CODDIETA = L.CODDIETA WHERE ISNULL(L.ATIVO, 1) = 1 ORDER BY L.LOTE')}</xSql>'
          '<Sufixo>_flutter</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    final value = response.trim();
    if (value.startsWith('#ic#')) {
      final message = value.replaceFirst('#ic#', '').replaceFirst('#fc#', '');
      throw SoapException(message);
    }
    if (!value.startsWith('[')) {
      throw SoapException(value.isEmpty ? 'Resposta vazia do Azure.' : value);
    }
    late final dynamic decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      throw SoapException('Azure retornou JSON invalido: $value');
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(LotRecord.fromJson)
        .toList(growable: false);
  }

  Future<void> insertLot(LotRecord lot) async {
    await soapClient.callResult(
      action: 'ExecSql',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_xmlEscape(_insertSql(lot))}</xSql>'
          '<Login>FVR</Login>'
          '<Senha>${_xmlEscape(const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'))}</Senha>'
          '<Sufixo>_flutter</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
  }

  Future<void> deleteLot(int code) async {
    final response = await soapClient.callResult(
      action: 'ExecSql',
      password: const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'),
      body:
          '<xSql>${_xmlEscape('EXEC SP_TB_LOTES_DELETE @CODLOTE = $code')}</xSql>'
          '<Login>FVR</Login>'
          '<Senha>${_xmlEscape(const String.fromEnvironment('COWSYSTEM_SOAP_PASSWORD'))}</Senha>'
          '<Sufixo>_flutter</Sufixo>'
          '<BancoLocal>false</BancoLocal>',
    );
    if (response.trim() == '-1') {
      throw const SoapException('Nao e possivel excluir um lote vinculado a animais.');
    }
  }

  String _insertSql(LotRecord lot) {
    return 'EXEC SP_TB_LOTES_INSERT_UPDATE '
        '@CODLOTE = ${lot.code}, '
        "@LOTE = '${_sqlEscape(lot.name)}', "
        '@CODSTATUSPRODUCAO = ${lot.productionStatusCode}, '
        '@CODDIETA = ${lot.dietCode}, '
        '@DIAS_SECAGEM = ${lot.dryingDays}, '
        '@DIAS_PREPARTO = ${lot.preCalvingDays}, '
        '@DG = ${lot.pregnancyDiagnosis}, '
        '@ALEITAMENTO = ${lot.milkFeeding}, '
        '@TIPO = ${lot.stallType}';
  }

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _sqlEscape(String value) => value.replaceAll("'", "''");
}
