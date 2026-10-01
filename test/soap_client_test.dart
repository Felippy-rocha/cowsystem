import 'package:flutter_test/flutter_test.dart';

import 'package:cowsystem/data/client_routing.dart';
import 'package:cowsystem/data/animal_weight_repository.dart';
import 'package:cowsystem/data/soap_client.dart';

void main() {
  test('mapeia a pesagem com os campos de acompanhamento do B4A', () {
    final record = AnimalWeightRecord.fromJson({
      'CODPESO': 15,
      'CODANIMAL': 43,
      'BRINCO': '43',
      'DATANASCIMENTO': '2024-01-10',
      'DIAS': 300,
      'PESOIDEAL': 180.5,
      'PESO': 175.0,
      'PESONASCIMENTO': 35.0,
      'LOTE': 'RECRIA',
      'CODTAREFA': 8,
    });

    expect(record.weightCode, 15);
    expect(record.tag, '43');
    expect(record.daysOld, 300);
    expect(record.idealWeight, 180.5);
    expect(record.weight, 175);
    expect(record.birthWeight, 35);
    expect(record.lot, 'RECRIA');
    expect(record.taskCode, 8);
  });

  test('gera comandos de pesagem compatíveis com o B4A', () {
    expect(weightSqlDate('07/05/2026'), "'2026-05-07'");
    expect(
      animalWeightCreateSessionSql('2026-05-07'),
      "EXEC SP_TB_PESOS_ANIMAIS_INSERT '2026-05-07';",
    );
    expect(
      animalWeightAddSql('07/05/2026', "O'Brien"),
      "EXEC SP_TB_PESOS_ANIMAIS_INSERT_INDIVIDUAL '2026-05-07', N'O''Brien';",
    );
    expect(
      animalWeightUpdateSql(23, 84.5),
      'EXEC SP_TB_PESOS_ANIMAIS_UPDATE 23, 84.50;',
    );
    expect(animalWeightDeleteSql(23), 'EXEC SP_TB_PESOS_ANIMAIS_DELETE 23;');
    expect(() => weightSqlDate('31/02/2026'), throwsFormatException);
  });

  test('monta envelope SOAP com XML escapado', () {
    final client = SoapClient(
      endpoint: 'https://example.invalid/servico.asmx',
      username: 'FVR & teste',
      deviceId: 'device <1>',
    );

    final envelope = client.buildEnvelope(
      action: 'Importar',
      body: '<xSql>A & B</xSql>',
      password: "senha'123",
    );

    expect(envelope, contains('<Usuario>FVR &amp; teste</Usuario>'));
    expect(envelope, contains('<Dispositivo>device &lt;1&gt;</Dispositivo>'));
    expect(envelope, contains('<Senha>senha&apos;123</Senha>'));
    expect(envelope, contains('<Importar xmlns="http://tempuri.org/">'));

    client.close();
  });

  test('usa por padrao o id resolvido no roteamento do dispositivo', () {
    ClientRoutingSession.deviceId = 'android-id-dinamico';
    final client = SoapClient();

    final envelope = client.buildEnvelope(
      action: 'Importar',
      body: '',
      password: '',
    );

    expect(
      envelope,
      contains('<Dispositivo>android-id-dinamico</Dispositivo>'),
    );
    client.close();
    ClientRoutingSession.deviceId = '';
  });
}
