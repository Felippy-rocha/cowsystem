import 'package:flutter_test/flutter_test.dart';

import 'package:cowsystem/data/client_routing.dart';
import 'package:cowsystem/data/soap_client.dart';

void main() {
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
