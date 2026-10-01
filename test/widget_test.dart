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
import 'package:cowsystem/data/animal_record.dart';
import 'package:cowsystem/data/client_routing.dart';
import 'package:cowsystem/data/number_format.dart';
import 'package:cowsystem/main.dart';

void main() {
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
