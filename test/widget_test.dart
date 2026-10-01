// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:cowsystem/agro_pages.dart';
import 'package:cowsystem/animal_roster_grid.dart';
import 'package:cowsystem/animal_roster_filter_sheet.dart';
import 'package:cowsystem/animal_lactation_grid.dart';
import 'package:cowsystem/animal_selection_menu.dart';
import 'package:cowsystem/data/animal_details_repository.dart';
import 'package:cowsystem/data/animal_carency_repository.dart';
import 'package:cowsystem/data/animal_diagnosis_repository.dart';
import 'package:cowsystem/data/animal_insemination_repository.dart';
import 'package:cowsystem/data/animal_birth_repository.dart';
import 'package:cowsystem/data/animal_record.dart';
import 'package:cowsystem/data/client_routing.dart';
import 'package:cowsystem/data/number_format.dart';
import 'package:cowsystem/main.dart';

void main() {
  test('consulta candidatas a parto e indução conforme o B4A', () {
    final query = animalBirthCandidatesQuery(tag: '43');

    expect(query, contains('TB_PRENHEZES'));
    expect(query, contains('TB_PREPARTO WHERE DATASAIDA IS NULL'));
    expect(query, contains("A.STATUSREPRODUCAO = 'INDUCAO'"));
    expect(query, contains("BRINCO) LIKE N'%43%'"));
    expect(query, contains('UNION'));
  });

  test('gera inclusão de parto e preserva campos opcionais de natimorto', () {
    expect(
      animalBirthInsertSql(
        date: '09/05/2026',
        motherCode: 14,
        sexCode: 1,
        calfTag: "B'43",
        calfLotCode: 5,
        motherLotCode: 4,
        breedCode: 2,
        calfWeight: 42.5,
        comment: "PARTO D'ÁGUA",
        birthTypeCode: 1,
      ),
      "EXEC SP_TB_PARTO_INSERT @DATA = '2026-05-09', @CODANIMAL = 14, "
      "@SEXO = 1, @BRINCO = N'B''43', @CODLOTECRIA = 5, "
      "@CODLOTEMAE = 4, @CODRACA = 2, @PESOCRIA = '42.50', "
      "@COMENTARIO = N'PARTO D''ÁGUA', @CODTIPOPARTO = '1';",
    );
    expect(
      () => animalBirthInsertSql(
        date: '31/02/2026',
        motherCode: 14,
        sexCode: 1,
        calfTag: '',
        calfLotCode: 0,
        motherLotCode: 4,
        breedCode: 0,
        calfWeight: 0,
        comment: '',
        birthTypeCode: 3,
      ),
      throwsFormatException,
    );
  });

  test('gera a procedure de indução conforme o formulário B4A', () {
    expect(
      animalInductionSql(
        animalCode: 14,
        date: '09/05/2026',
        destinationLotCode: 4,
        comment: "INDUÇÃO D'ÁGUA",
      ),
      "EXEC SP_TB_INDUCAO_INSERT @CODANIMAL = 14, "
      "@DATA = '2026-05-09', @CODLOTEDESTINO = 4, "
      "@COMENTARIO = N'INDUÇÃO D''ÁGUA';",
    );
  });

  test('filtra inseminações aptas e permite consulta ampliada', () {
    final eligible = inseminationAnimalQuery();
    expect(eligible, contains('dbo.LISTA_ANIMAIS()'));
    expect(eligible, contains('ATIVO = 1'));
    expect(eligible, contains("STATUSREPRODUCAO NOT IN ('PRENHA', 'PEV')"));
    expect(eligible, contains('DOADORA IN (2, 3)'));
    expect(eligible, contains('DATEDIFF(day'));

    final all = inseminationAnimalQuery(
      tag: "D'43",
      includeAll: true,
      offset: 50,
      limit: 25,
    );
    expect(all, contains("BRINCO = N'D''43'"));
    expect(all, isNot(contains('ATIVO = 1')));
    expect(all, contains('OFFSET 50 ROWS FETCH NEXT 25 ROWS ONLY'));
  });

  test('gera inclusão de inseminação conforme procedure B4A', () {
    expect(
      inseminationInsertSql(
        animalCode: 43,
        date: '08/05/2026',
        employeeCode: 9,
        bullCode: 2,
        typeCode: 1,
        comment: "PRIMEIRA IA D'ÁGUA",
        donorCode: 0,
      ),
      "EXEC SP_TB_INSEMINACAO_INSERT_1 @CODANIMAL = 43, "
      "@DATA = '2026-05-08', @CODFUNCIONARIO = 9, @CODTOURO = 2, "
      "@CODTIPOIA = 1, @COMENTARIO = N'PRIMEIRA IA D''ÁGUA', "
      '@CODDOADORA = 0;',
    );
    expect(
      () => inseminationInsertSql(
        animalCode: 43,
        date: '31/02/2026',
        employeeCode: 9,
        bullCode: 2,
        typeCode: 1,
        comment: '',
        donorCode: 0,
      ),
      throwsFormatException,
    );
  });

  test('aplica resultados de diagnóstico permitidos pelo B4A', () {
    expect(diagnosisResultIds('PEV', 'INSEMINADA'), [4, 5]);
    expect(diagnosisResultIds('VAZIA', 'VAZIA'), [2, 4, 5]);
    expect(diagnosisResultIds('AVALIAÇÃO', 'VAZIA'), [6]);
    expect(diagnosisResultIds('TOQUE', 'TETF'), [2, 4, 5, 6]);
    expect(diagnosisResultIds('TOQUE', 'PRENHA'), [1, 2, 3]);
  });

  test('gera comandos de diagnóstico compatíveis com o B4A', () {
    expect(
      diagnosisCreateSessionSql('07/05/2026', 9),
      "EXEC SP_TB_TOQUE_INSERT @DATA = '2026-05-07', @CODFUNCIONARIO = 9;",
    );
    expect(
      diagnosisAddAnimalSql(4, 43),
      'EXEC SP_TB_TOQUE_INSERT_INDIVIDUAL @CODTOQUE = 4, @CODANIMAL = 43;',
    );
    expect(
      diagnosisSaveResultSql(12, '2026-05-07', 2, "VACA D'ÁGUA"),
      "EXEC SP_TB_TOQUE_CADASTRAR @ID_TOQUE_DETALHES = 12, "
      "@DATATOQUE = '2026-05-07', @RESULTADOTOQUE = 2, "
      "@COMENTARIO = N'VACA D''ÁGUA';",
    );
    expect(
      diagnosisUndoResultSql(12),
      'EXEC SP_TB_TOQUE_DESFAZER @ID_TOQUE_DETALHES = 12;',
    );
    expect(
      diagnosisDeleteDetailSql(12),
      'DELETE FROM TB_TOQUE_DETALHES WHERE ID = 12;',
    );
    expect(
      () => diagnosisCreateSessionSql('31/02/2026', 9),
      throwsFormatException,
    );
  });

  test('monta a consulta paginada de carências com filtros escapados', () {
    final query = animalCarencyQuery(
      tag: "A'43",
      type: "LEITE",
      offset: 200,
      limit: 50,
    );

    expect(query, contains('dbo.LISTA_ANIMAIS_CARENCIA()'));
    expect(query, contains("BRINCO = N'A''43'"));
    expect(query, contains("TIPO = N'LEITE'"));
    expect(query, contains('ORDER BY TRY_CONVERT(date, DATA_SAIDA, 103)'));
    expect(query, contains('OFFSET 200 ROWS FETCH NEXT 50 ROWS ONLY'));
    expect(() => animalCarencyQuery(offset: -1), throwsArgumentError);
  });

  test('mapeia animal e locais de carência da função B4A', () {
    final record = AnimalCarencyRecord.fromJson({
      'CODANIMAL': 43,
      'BRINCO': '43',
      'STATUSREPRODUCAO': 'VAZIA',
      'DATANASCIMENTO': '2022-05-03',
      'STATUSPRODUCAO': 'EM LEITE',
      'ULTIMOPARTO': '2025-01-10',
      'LOTE': 'ALTA',
      'RACA': 'GIROLANDO',
      'DEL': 110,
      'ATIVO': 1,
      'ADESCARTAR': 0,
      'CODLACTACAO': '2025011001',
      'TIPO': 'ANTIBIÓTICO',
      'DATA_SAIDA': '15/10/2026',
      'TT': 0,
      'TE': 1,
      'TD': 0,
      'DE': 0,
      'DD': 1,
    });

    expect(record.animal.tag, '43');
    expect(record.animal.lotName, 'ALTA');
    expect(record.animal.daysInMilk, 110);
    expect(record.type, 'ANTIBIÓTICO');
    expect(record.exitDate, '15/10/2026');
    expect(record.treatmentUdder, 1);
    expect(record.discardRight, 1);
  });

  test('configura tabelas auxiliares pelo contrato B4A', () {
    final config = simpleTableCatalogConfig(
      title: 'Doenças',
      table: 'TB_DOENCAS',
      idColumn: 'CODDOENCA',
      descriptionColumn: 'DOENCA',
    );

    expect(
      config.query,
      'SELECT CODDOENCA, DOENCA FROM TB_DOENCAS ORDER BY DOENCA',
    );
    expect(
      config.saveSql(-1, {'DOENCA': "MASTITE D'ÁGUA"}),
      "EXEC SP_TB_TABELAS_INSERT_UPDATE TB_DOENCAS, -1, N'MASTITE D''ÁGUA';",
    );
    expect(config.deleteSql(4), "EXEC SP_TB_TABELAS_DELETE 'TB_DOENCAS', 4;");
  });

  test('configura fornecedores com todos os campos do contrato B4A', () {
    final config = suppliersConfig();

    expect(config.table, 'TB_FORNECEDORES');
    expect(config.uniqueColumn, 'FORNECEDOR');
    expect(config.fields.map((field) => field.key), [
      'FORNECEDOR',
      'TIPO',
      'ENDERECOWEB',
      'USUARIO',
      'CONTATO',
      'TELEFONE',
      'CELULAR',
      'TIPOINSUMO',
    ]);
    expect(config.fields[1].options, ['INTERNET', 'LOCAL']);
    expect(config.fields.last.optionsQuery, contains('TB_TIPOINSUMOS'));
    expect(
      config.saveSql(-1, {'FORNECEDOR': "D'Água"}),
      "EXEC SP_TB_FORNECEDORES_INSERT_UPDATE -1, N'D''Água', N'', N'', N'', N'', N'', N'', N'';",
    );
  });

  test('configura tipos de IA conforme a tabela do B4A', () {
    final config = inseminationTypesConfig();

    expect(
      config.query,
      'SELECT CODTIPOIA, TIPOIA FROM TB_TIPOIA ORDER BY TIPOIA',
    );
    expect(
      config.saveSql(3, {'TIPOIA': 'CONVENCIONAL'}),
      "EXEC SP_TB_TABELAS_INSERT_UPDATE TB_TIPOIA, 3, N'CONVENCIONAL';",
    );
    expect(config.deleteSql(3), "EXEC SP_TB_TABELAS_DELETE 'TB_TIPOIA', 3;");
  });

  test('configura raças com a relação de grau de sangue do B4A', () {
    final config = breedsConfig();

    expect(config.query, contains('INNER JOIN TB_GRAUSANGUE'));
    expect(config.fields[1].optionsValueColumn, 'IDGRAUSANGUE');
    expect(config.fields[1].optionsLabelColumn, 'FRACAO');
    expect(config.fields.last.showInForm, isFalse);
    expect(
      config.saveSql(-1, {'RACA': 'GIROLANDO', 'IDGRAUSANGUE': '3'}),
      "EXEC SP_TB_RACA_INSERT_UPDATE -1, N'GIROLANDO', 3;",
    );
    expect(config.deleteSql(7), 'EXEC SP_TB_RACA_DELETE 7;');
  });

  test('formata números no padrão brasileiro', () {
    expect(formatBrazilianNumber(9406.2), '9.406,2');
    expect(formatBrazilianNumber(55396.6), '55.396,6');
    expect(formatBrazilianNumber(1234, decimalDigits: 0), '1.234');
  });

  test('mapeia os campos da lista SQL de animais', () {
    final animal = AnimalRecord.fromJson({
      'CODANIMAL': 43,
      'BRINCO': '43',
      'STATUSREPRODUCAO': 'VAZIA',
      'DATANASCIMENTO': '2018-07-20T00:00:00',
      'STATUSPRODUCAO': 'EM LEITE',
      'CODLACTACAOATUAL': '2026041306',
      'NUMIA': 0,
      'DATAIA': null,
      'PREVISAOPARTO': null,
      'LOTE': 'ALTA LACTAÇÃO',
      'RACA': 'GIROLANDO 7/8',
      'DP': 0,
      'DEL': 170,
      'ATIVO': 1,
      'ADESCARTAR': 1,
      'CODLOTE': 3,
    });

    expect(animal.tag, '43');
    expect(animal.animalCode, 43);
    expect(animal.lotCode, 3);
    expect(animal.lotName, 'ALTA LACTAÇÃO');
    expect(animal.displayLot, 'ALTA LACTAÇÃO');
    expect(animal.breed, 'GIROLANDO 7/8');
    expect(animal.lactationCode, '2026041306');
    expect(animal.daysInMilk, 170);
    expect(animal.discardCode, 1);
  });

  test('aplica as categorias de status do filtro B4A', () {
    AnimalRecord animal({
      int activeCode = 1,
      int donorCode = 2,
      int discardCode = 0,
    }) => AnimalRecord(
      tag: '43',
      donor: '$donorCode',
      breed: 'GIROLANDO',
      reproductiveStatus: 'VAZIA',
      activeCode: activeCode,
      donorCode: donorCode,
      discardCode: discardCode,
    );

    expect(animal().matchesRegistrationStatus('ATIVO'), isTrue);
    expect(animal(activeCode: 2).matchesRegistrationStatus('INATIVO'), isTrue);
    expect(
      animal(donorCode: 1).matchesRegistrationStatus('DOADORA EXTERNA'),
      isTrue,
    );
    expect(
      animal(donorCode: 3).matchesRegistrationStatus('DOADORA INTERNA'),
      isTrue,
    );
    expect(
      animal(
        donorCode: 3,
        discardCode: 1,
      ).matchesRegistrationStatus('A DESCARTAR'),
      isTrue,
    );
    expect(animal(donorCode: 1).matchesRegistrationStatus('ATIVO'), isFalse);
  });

  test('menu limita ações em multisseleção e condiciona serviços', () {
    AnimalRecord animal({
      String reproductive = 'VAZIA',
      String production = 'EM LEITE',
      int pregnancyDays = 0,
    }) => AnimalRecord(
      tag: '43',
      donor: '2',
      breed: 'GIROLANDO',
      reproductiveStatus: reproductive,
      productionStatus: production,
      pregnancyDays: pregnancyDays,
    );

    final multiOptions = animalSelectionMenuOptions([
      animal(),
      animal(reproductive: 'PRENHA'),
    ]);
    expect(
      multiOptions.map((option) => option.action),
      containsAll([
        AnimalSelectionAction.changeLot,
        AnimalSelectionAction.addInsemination,
        AnimalSelectionAction.consultInseminations,
      ]),
    );
    expect(
      multiOptions.any(
        (option) => option.action == AnimalSelectionAction.editAnimal,
      ),
      isFalse,
    );

    final pregnantOptions = animalSelectionMenuOptions([
      animal(
        reproductive: 'PRENHA',
        production: 'PRE-PARTO',
        pregnancyDays: 240,
      ),
    ]);
    expect(
      pregnantOptions
          .singleWhere(
            (option) => option.action == AnimalSelectionAction.registerBirth,
          )
          .enabled,
      isTrue,
    );
  });

  test('menu da Lista oferece ações de um único animal', () {
    const animal = AnimalRecord(
      animalCode: 43,
      tag: '43',
      donor: '2',
      breed: 'GIROLANDO',
      reproductiveStatus: 'VAZIA',
      productionStatus: 'EM LEITE',
    );
    final options = animalSelectionMenuOptions([animal]);

    expect(
      options.map((option) => option.action),
      containsAll([
        AnimalSelectionAction.editAnimal,
        AnimalSelectionAction.discardAnimal,
        AnimalSelectionAction.animalInformation,
      ]),
    );
    expect(options.length, greaterThan(3));
  });

  testWidgets('grade de lactações agrega todas ou as selecionadas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimalLactationGrid(
            lactations: const [
              AnimalClosedLactation(
                code: '20200101',
                daysInMilk: 100,
                total305: 1000,
                average305: 10,
                totalMilk: 5000,
              ),
              AnimalClosedLactation(
                code: '20210101',
                daysInMilk: 200,
                total305: 2000,
                average305: 20,
                totalMilk: 6000,
              ),
              AnimalClosedLactation(
                code: '20220101',
                daysInMilk: 300,
                total305: 3000,
                average305: 30,
                totalMilk: 7000,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('3 total'), findsOneWidget);
    expect(find.text('6.000,0'), findsNWidgets(2));
    expect(find.text('20,0'), findsNWidgets(2));
    expect(find.text('18.000,0'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('20200101'));
    await tester.tap(find.text('20210101'));
    await tester.pumpAndSettle();

    expect(find.text('2 lactações selecionadas'), findsOneWidget);
    expect(find.text('3.000,0'), findsNWidgets(2));
    expect(find.text('15,0'), findsOneWidget);
    expect(find.text('11.000,0'), findsOneWidget);

    await tester.tap(find.text('20210101'));
    await tester.pumpAndSettle();

    expect(find.text('1 lactação selecionada'), findsOneWidget);
    expect(find.text('1.000,0'), findsNWidgets(2));
    expect(find.text('10,0'), findsNWidgets(2));
    expect(find.text('5.000,0'), findsNWidgets(2));

    await tester.tap(find.text('20200101'));
    await tester.pumpAndSettle();

    expect(find.text('1 lactação selecionada'), findsNothing);
    expect(find.text('6.000,0'), findsNWidgets(2));
    expect(find.text('20,0'), findsNWidgets(2));
    expect(find.text('18.000,0'), findsOneWidget);
  });

  testWidgets('grade agrega todos ou somente as linhas selecionadas', (
    WidgetTester tester,
  ) async {
    final animals = [
      const AnimalRecord(
        animalCode: 1,
        tag: '43',
        donor: '2',
        breed: 'GIROLANDO',
        reproductiveStatus: 'VAZIA',
        daysInMilk: 100,
      ),
      const AnimalRecord(
        animalCode: 2,
        tag: '72',
        donor: '2',
        breed: 'GIROLANDO',
        reproductiveStatus: 'PRENHA',
        daysInMilk: 200,
      ),
    ];
    final selected = <int>{};

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: AnimalRosterGrid(
              animals: animals,
              selectedAnimalCodes: selected,
              onAnimalTap: (animal) => setState(() {
                if (!selected.add(animal.animalCode)) {
                  selected.remove(animal.animalCode);
                }
              }),
            ),
          ),
        ),
      ),
    );

    expect(find.text('2'), findsOneWidget);
    expect(find.text('150,0'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('43')).dy,
      lessThan(tester.getTopLeft(find.text('72')).dy),
    );

    await tester.tap(find.text('Reprodução'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('72')).dy,
      lessThan(tester.getTopLeft(find.text('43')).dy),
    );

    await tester.tap(find.text('Reprodução'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('43')).dy,
      lessThan(tester.getTopLeft(find.text('72')).dy),
    );

    await tester.tap(find.text('43'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('100,0'), findsOneWidget);
  });

  testWidgets('abre a seleção de lotes em uma lista pesquisável', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showAnimalRosterFilters(
                  context: context,
                  initial: const AnimalRosterFilters(
                    reproductive: {},
                    production: {},
                    lots: {},
                    breeds: {},
                    registrationStatus: 'ATIVO',
                  ),
                  reproductiveOptions: const ['PRENHA', 'VAZIA'],
                  productionOptions: const ['EM LEITE', 'SECA'],
                  lotOptions: const ['1 - ALTA LACTAÇÃO', '2 - PÓS-PARTO'],
                  breedOptions: const ['GIROLANDO 7/8'],
                ),
                child: const Text('Abrir filtros'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir filtros'));
    await tester.pumpAndSettle();

    expect(find.text('Status reprodução'), findsOneWidget);
    expect(find.text('Status produção'), findsOneWidget);
    expect(find.text('Lotes'), findsOneWidget);
    expect(find.text('Raça'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('ATIVO'), findsOneWidget);

    await tester.tap(find.text('Lotes'));
    await tester.pumpAndSettle();
    expect(find.text('1 - ALTA LACTAÇÃO'), findsOneWidget);
    expect(find.text('2 - PÓS-PARTO'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('1 selecionados'), findsOneWidget);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('1 - ALTA LACTAÇÃO'), findsOneWidget);

    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    expect(find.byType(RadioListTile<String>), findsNWidgets(5));
    await tester.tap(find.text('INATIVO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('INATIVO'), findsOneWidget);
  });

  testWidgets('exibe o dashboard principal', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('CowSystem'), findsOneWidget);
    expect(find.text('Visao geral da fazenda'), findsOneWidget);
    expect(find.text('Controle leiteiro'), findsOneWidget);
    expect(find.text('Cadastros'), findsOneWidget);
  });

  testWidgets('exibe os dados do usuario retornados pelo Azure', (
    WidgetTester tester,
  ) async {
    ClientRoutingSession.username = 'Usuario de teste';
    ClientRoutingSession.company = 'Fazenda de teste';
    ClientRoutingSession.profileDescription = 'Administrador';
    ClientRoutingSession.deviceId = 'device-test';
    ClientRoutingSession.appVersion = '1.0';
    ClientRoutingSession.canGrantPermissions = true;
    addTearDown(() {
      ClientRoutingSession.username = '';
      ClientRoutingSession.company = '';
      ClientRoutingSession.profileDescription = '';
      ClientRoutingSession.deviceId = '';
      ClientRoutingSession.appVersion = '';
      ClientRoutingSession.canGrantPermissions = false;
    });

    await tester.pumpWidget(const MaterialApp(home: UserProfilePage()));

    expect(find.text('Usuario de teste'), findsWidgets);
    expect(find.text('Fazenda de teste'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Gerenciar perfis e permissões'), findsOneWidget);
  });
}
