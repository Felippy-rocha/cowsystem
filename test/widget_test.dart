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
import 'package:cowsystem/data/animal_body_condition_repository.dart';
import 'package:cowsystem/data/animal_abortion_repository.dart';
import 'package:cowsystem/data/animal_comment_repository.dart';
import 'package:cowsystem/data/animal_treatment_repository.dart';
import 'package:cowsystem/data/animal_hoof_trimming_repository.dart';
import 'package:cowsystem/data/animal_bst_application_repository.dart';
import 'package:cowsystem/data/animal_bst_repository.dart';
import 'package:cowsystem/data/dry_matter_history_repository.dart';
import 'package:cowsystem/data/animal_protocol_repository.dart';
import 'package:cowsystem/data/feeding_repository.dart';
import 'package:cowsystem/data/animal_cycles_repository.dart';
import 'package:cowsystem/data/medication_inventory_repository.dart';
import 'package:cowsystem/data/touch_session_repository.dart';
import 'package:cowsystem/data/herd_summary_repository.dart';
import 'package:cowsystem/data/milk_summary_repository.dart';
import 'package:cowsystem/data/consumption_analysis_repository.dart';
import 'package:cowsystem/data/prevision_touch_repository.dart';
import 'package:cowsystem/data/diet_repository.dart';
import 'package:cowsystem/data/general_supply_inventory_repository.dart';
import 'package:cowsystem/data/animal_insemination_repository.dart';
import 'package:cowsystem/data/animal_birth_repository.dart';
import 'package:cowsystem/data/animal_dry_off_repository.dart';
import 'package:cowsystem/data/animal_precalving_repository.dart';
import 'package:cowsystem/data/animal_repository.dart';
import 'package:cowsystem/data/animal_discard_repository.dart';
import 'package:cowsystem/data/animal_record.dart';
import 'package:cowsystem/data/client_routing.dart';
import 'package:cowsystem/data/number_format.dart';
import 'package:cowsystem/main.dart';

void main() {
  test('gera previsão de toque pela data escolhida', () {
    expect(
      previsionTouchGenerateSql('24/05/2026'),
      "EXEC SP_TB_PREVISAO_TOQUE_INSERT @DATA = '2026-05-24';",
    );
    expect(
      () => previsionTouchGenerateSql('31/02/2026'),
      throwsFormatException,
    );
  });

  test('gera análise de consumo mensal e diária', () {
    expect(
      consumptionAnalysisMonthlySql(dietCode: 4, period: '05/2026', lotCode: 8),
      "EXEC SP_TB_ANALISE_CONSUMO_MENSAL_LOTE 4, N'05/2026', 8;",
    );
    expect(
      consumptionAnalysisDailySql(dietCode: 4, date: '24/05/2026'),
      "EXEC SP_TB_ANALISE_CONSUMO_DIARIO 4, '2026-05-24';",
    );
    expect(
      () => consumptionAnalysisDailySql(dietCode: 4, date: '31/02/2026'),
      throwsFormatException,
    );
  });

  test('gera resumo de leite mensal pelo período', () {
    expect(
      milkSummaryGenerateSql('05/2026'),
      "EXEC SP_TB_RESUMO_LEITE_MENSAL_INSERT @PERIODO = N'05/2026';",
    );
    expect(() => milkSummaryGenerateSql(''), throwsArgumentError);
  });

  test('gera resumo do rebanho com a descrição do relatório', () {
    expect(
      herdSummaryGenerateSql('LACTANTES'),
      "EXEC SP_REL_RESUMO_REBANHO N'LACTANTES';",
    );
    expect(
      herdSummaryGenerateSql("LACTANTES D'ÁGUA"),
      "EXEC SP_REL_RESUMO_REBANHO N'LACTANTES D''ÁGUA';",
    );
  });

  test('gera procedures de salvar dieta e ingrediente', () {
    expect(
      dietSaveSql(
        code: 12,
        description: "DIETA D'ÁGUA",
        date: '24/05/2026',
        formulator: 'DR. JOÃO',
        active: 1,
        dryMatterDate: '23/05/2026',
        realDryMatter: 34.5,
        quantityPerDay: 50,
      ),
      "EXEC SP_TB_DIETA_INSERT 12, N'DIETA D''ÁGUA', '2026-05-24', "
      "N'DR. JOÃO', 1, '2026-05-23', '34.50', 50;",
    );
    expect(
      dietIngredientSaveSql(
        dietCode: 4,
        ingredientCode: 2,
        quantity: 12.5,
        price: 1.2,
        order: 1,
        cropYear: '2025',
        realDryMatter: 34.5,
        dryMatterQuantity: 6.5,
      ),
      "EXEC SP_TB_DIETA_INGREDIENTES_INSERT -1, 4, 2, '12.50', '1.20', "
      "1, N'2025', '34.50', '6.50';",
    );
    expect(
      () => dietSaveSql(
        code: 12,
        description: '',
        date: '24/05/2026',
        formulator: 'DR.',
        active: 1,
        dryMatterDate: '23/05/2026',
        realDryMatter: 1,
        quantityPerDay: 1,
      ),
      throwsArgumentError,
    );
  });

  test('gera procedures de criação e inclusão de animal no toque', () {
    expect(
      touchSessionCreateSql(date: '24/05/2026', employeeCode: 3),
      "EXEC SP_TB_TOQUE_INSERT @DATA = '2026-05-24', @CODFUNCIONARIO = 3;",
    );
    expect(
      touchAnimalInsertSql(touchCode: 8, animalCode: 43),
      'EXEC SP_TB_TOQUE_INSERT_INDIVIDUAL @CODTOQUE = 8, @CODANIMAL = 43;',
    );
    expect(
      () => touchSessionCreateSql(date: '31/02/2026', employeeCode: 3),
      throwsFormatException,
    );
  });

  test('gera procedure de associação RFID com escape', () {
    expect(
      animalChipAssociationSql(43, "RF'ID01"),
      "EXEC SP_TB_ANIMAIS_INCLUIR_CHIP 43, 'RF''ID01';",
    );
    expect(() => animalChipAssociationSql(0, 'RFID01'), throwsArgumentError);
  });

  test('gera procedures de criação e conferência de insumos gerais', () {
    expect(
      generalSupplyInventoryCreateSql(6),
      'EXEC SP_TB_INVENTARIO_INSUMOSGERAIS_CRIAR 6;',
    );
    expect(
      generalSupplyInventoryConfirmSql(
        id: 31,
        description: "ADUBO D'ÁGUA",
        description2: 'Saco 25 kg',
        description3: '',
        type: 'FERTILIZANTE',
        minimumStock: 4,
        stock: 6.5,
      ),
      "EXEC SP_TB_INVENTARIO_INSUMOSGERAIS_CONFERIR 31, "
      "N'ADUBO D''ÁGUA', N'Saco 25 kg', N'', N'FERTILIZANTE', 4.00, 6.50;",
    );
    expect(() => generalSupplyInventoryCreateSql(0), throwsArgumentError);
  });

  test('gera procedures de abertura e conferência do inventário', () {
    expect(
      medicationInventoryCreateSql(),
      'EXEC SP_TB_INVENTARIO_MEDICAMENTOS_CRIAR;',
    );
    expect(
      medicationInventoryConfirmSql(
        id: 12,
        medication: "ANTIBIÓTICO D'ÁGUA",
        option1: '10 ml',
        option2: '',
        option3: 'IM',
        minimumStock: 5,
        stock: 7.5,
      ),
      "EXEC SP_TB_INVENTARIO_MEDICAMENTOS_CONFERIR 12, "
      "N'ANTIBIÓTICO D''ÁGUA', N'10 ml', N'', N'IM', 5.00, 7.50;",
    );
    expect(
      () => medicationInventoryConfirmSql(
        id: 0,
        medication: 'Produto',
        option1: '',
        option2: '',
        option3: '',
        minimumStock: 1,
        stock: 1,
      ),
      throwsArgumentError,
    );
  });

  test('gera recálculo de ciclo reprodutivo com código válido', () {
    expect(cycleCalculateSql(37), 'EXEC SP_TB_CICLOS_CALCULAR 37;');
    expect(() => cycleCalculateSql(0), throwsArgumentError);
  });

  test('gera SQL de trato e descarga dentro dos contratos B4A', () {
    expect(
      feedingCreateSql(
        dietCode: 4,
        date: '23/05/2026',
        employeeCode: 2,
        assistantCode: 3,
        animalCount: 50,
      ),
      "EXEC SP_TB_TRATO_INSERT2 -1, 4, '2026-05-23', 2, 3, 50;",
    );
    expect(
      feedingDischargeSql(
        date: '23/05/2026',
        feedingCode: 5,
        lotCode: 8,
        total: 120.5,
      ),
      "EXEC SP_TB_CONSUMO_INSERT -1, '2026-05-23', 5, 8, 120.50;",
    );
    expect(
      feedingDischargeUpdateSql(
        dischargeCode: 9,
        date: '23/05/2026',
        feedingCode: 5,
        lotCode: 10,
        total: 60,
      ),
      "EXEC SP_TB_CONSUMO_UPDATE 9, '2026-05-23', 5, 10, 60.00;",
    );
    expect(
      () => feedingDischargeSql(
        date: '31/02/2026',
        feedingCode: 5,
        lotCode: 8,
        total: 1,
      ),
      throwsFormatException,
    );
  });

  test('gera SQL do protocolo e das ações de tarefa conforme B4A', () {
    expect(
      protocolApplicationSql(
        date: '22/05/2026',
        time: '08:30',
        protocolCode: 4,
        animalCode: 43,
        completed: false,
      ),
      "EXEC SP_TB_TAREFAS_INSERT_PROTOCOLO '22/05/2026 08:30', "
      "'08:30', 4, 43, 0;",
    );
    expect(
      protocolTaskActionSql('CONCLUIR', 9),
      'EXEC SP_TB_TAREFAS_CONCLUIR 9;',
    );
    expect(
      protocolTaskActionSql('DESFAZER_CONCLUIR', 9),
      'EXEC SP_TB_TAREFAS_DESFAZER_CONCLUIR 9;',
    );
    expect(
      protocolTaskUpdateSql(
        taskCode: 9,
        taskTypeCode: 2,
        date: '23/05/2026',
        time: '09:15',
        animalCode: 43,
        description: "REVISÃO D'ÁGUA",
        execution: 'PROTOCOLO',
      ),
      "EXEC SP_TB_TAREFAS_INSERT_UPDATE 9, 2, '2026-05-23', "
      "N'09:15', 43, N'REVISÃO D''ÁGUA', N'PROTOCOLO';",
    );
    expect(
      protocolStepInsertSql(
        originCode: 31,
        taskTypeCode: 2,
        date: '23/05/2026',
        time: '09:15',
        animalCode: 43,
        description: 'Revisar protocolo',
        execution: 'PROTOCOLO',
        protocolCode: 4,
      ),
      "EXEC SP_TB_TAREFAS_INSERT 31, 2, '2026-05-23', N'09:15', "
      "43, N'Revisar protocolo', N'PROTOCOLO', 0, 4;",
    );
    expect(
      protocolTaskActionSql('EXCLUIR', 9),
      'EXEC SP_TB_TAREFAS_EXCLUIR 9;',
    );
    expect(protocolDeleteGroupSql(31), 'EXEC SP_TB_TAREFAS_DELETE 31, 0;');
    expect(
      () => protocolApplicationSql(
        date: '31/02/2026',
        time: '08:30',
        protocolCode: 4,
        animalCode: 43,
        completed: false,
      ),
      throwsFormatException,
    );
  });

  test('gera procedure de inclusão e edição do histórico de matéria seca', () {
    expect(
      dryMatterHistorySaveSql(
        typeCode: 1,
        date: '22/05/2026',
        ingredientCode: 0,
        dietCode: 7,
        percentage: 34.5,
      ),
      "EXEC SP_TB_HISTORICOMS_INSERT -1, 1, '2026-05-22', 0, 7, 34.50;",
    );
    expect(
      dryMatterHistorySaveSql(
        id: 12,
        typeCode: 2,
        date: '2026-05-22',
        ingredientCode: 3,
        dietCode: 0,
        percentage: 88,
      ),
      'EXEC SP_TB_HISTORICOMS_INSERT 12, 2, \'2026-05-22\', 3, 0, 88.00;',
    );
    expect(
      () => dryMatterHistorySaveSql(
        typeCode: 1,
        date: '31/02/2026',
        ingredientCode: 0,
        dietCode: 7,
        percentage: 34.5,
      ),
      throwsFormatException,
    );
  });

  test('gera SQL de inclusão, edição e encerramento de ciclo BST', () {
    expect(
      bstCycleInsertSql(
        animalCode: 43,
        entryDate: '22/05/2026',
        hormoneCode: 4,
        lactationCode: 'L-2026',
        week: "SEMANA D'ÁGUA",
      ),
      contains(
        "INSERT INTO TB_BST (CODANIMAL, DATAENTRADA, DATASAIDA, CODHORMONIO, "
        "ATIVO, HORA_DO_REGISTRO, CODLACTACAO, SEMANA) VALUES "
        "(43, '2026-05-22', NULL, 4, 1, dbo.cHORA_DO_REGISTRO(), "
        "N'L-2026', N'SEMANA D''ÁGUA');",
      ),
    );
    expect(
      bstCycleUpdateSql(cycleCode: 8, hormoneCode: 2, week: 'Semana 2'),
      contains("WHERE CODBST = 8 AND ATIVO = 1"),
    );
    expect(
      bstCycleDeactivateSql(8),
      contains('SET ATIVO = 2, DATASAIDA = GETDATE()'),
    );
    expect(
      () => bstCycleInsertSql(
        animalCode: 0,
        entryDate: '22/05/2026',
        hormoneCode: 4,
        lactationCode: 'L-2026',
        week: 'Semana 2',
      ),
      throwsArgumentError,
    );
  });

  test('gera lista BST para a data selecionada', () {
    expect(
      bstApplicationCreateListSql('22/05/2026'),
      "EXEC SP_TB_BST_APLICACAO_INSERT '2026-05-22';",
    );
    expect(
      bstApplicationMarkAppliedSql(15),
      contains('UPDATE TB_BST_APLICACAO SET APLICACAO = 2'),
    );
    expect(
      bstApplicationMarkAppliedSql(15),
      contains('WHERE ID = 15 AND APLICACAO <> 2'),
    );
    expect(
      bstApplicationDeletePendingSql(15),
      'DELETE FROM TB_BST_APLICACAO WHERE ID = 15 AND APLICACAO <> 2;',
    );
    expect(
      () => bstApplicationCreateListSql('31/02/2026'),
      throwsFormatException,
    );
  });

  test('gera procedure de casqueamento com os campos do B4A', () {
    expect(
      hoofTrimmingInsertSql(
        date: '22/05/2026',
        animalCode: 43,
        employeeCode: 2,
        assistantCode: 5,
        typeCode: 1,
        comment: "DOR D'ÁGUA",
      ),
      "EXEC SP_TB_CASQUEAMENTO_INSERT -1, '2026-05-22', "
      "43, 2, 5, 1, N'DOR D''ÁGUA';",
    );
    expect(
      () => hoofTrimmingInsertSql(
        date: '31/02/2026',
        animalCode: 43,
        employeeCode: 2,
        assistantCode: 5,
        typeCode: 1,
        comment: '',
      ),
      throwsFormatException,
    );
    expect(
      () => hoofTrimmingInsertSql(
        date: '2026-05-22',
        animalCode: 0,
        employeeCode: 2,
        assistantCode: 5,
        typeCode: 1,
        comment: '',
      ),
      throwsArgumentError,
    );
  });

  test('gera tarefa de tratamento com data e horário ISO seguros', () {
    expect(
      animalTreatmentTaskSql(
        date: '22/05/2026',
        time: '08:30',
        treatmentCode: 3,
        animalCode: 43,
      ),
      "EXEC SP_TB_TAREFAS_INSERT_TRATAMENTO "
      "'2026-05-22T08:30:00', '08:30', 3, 43;",
    );
    expect(
      () => animalTreatmentTaskSql(
        date: '22/05/2026',
        time: '25:10',
        treatmentCode: 3,
        animalCode: 43,
      ),
      throwsFormatException,
    );
  });

  test('gera inclusão e alteração de comentário conforme o B4A', () {
    final insert = animalCommentSaveSql(
      id: null,
      animalCode: 43,
      date: '21/05/2026',
      type: 'SAÚDE',
      comment: "VACA D'ÁGUA",
    );
    expect(insert, contains('SELECT @ID = ISNULL(MAX(ID) + 1, 1)'));
    expect(
      insert,
      contains("@ID, 43, '2026-05-21', N'SAÚDE', N'VACA D''ÁGUA'"),
    );

    final update = animalCommentSaveSql(
      id: 8,
      animalCode: 43,
      date: '2026-05-21',
      type: 'SAÚDE',
      comment: 'REVISÃO',
    );
    expect(update, contains('UPDATE TB_COMENTARIOS'));
    expect(update, contains('WHERE ID = 8'));
    expect(
      () => animalCommentSaveSql(
        id: null,
        animalCode: 0,
        date: '21/05/2026',
        type: '',
        comment: '',
      ),
      throwsArgumentError,
    );
  });

  test('gera procedimento de descarte com data, motivo e comentário', () {
    expect(
      animalDiscardSql(
        animalCode: 43,
        reasonCode: 4,
        date: '20/05/2026',
        comment: "DESCARTE D'ÁGUA",
      ),
      "EXEC SP_TB_ANIMAIS_DESCARTAR @CODANIMAL = 43, "
      "@CODMOTIVODESCARTE = 4, @DATADESCARTE = '2026-05-20', "
      "@COMENTARIODESCARTE = N'DESCARTE D''ÁGUA';",
    );
    expect(
      () => animalDiscardSql(
        animalCode: 0,
        reasonCode: 4,
        date: '20/05/2026',
        comment: '',
      ),
      throwsArgumentError,
    );
  });

  test('gera SQL de troca de lote individual ou em multisseleção', () {
    expect(
      animalLotTransferSql(
        animalCodes: [43],
        destinationLotCode: 8,
        currentLotCode: 2,
      ),
      contains('WHERE CODANIMAL = 43 AND CODLOTE = 2'),
    );
    final multiple = animalLotTransferSql(
      animalCodes: [43, 44, 43],
      destinationLotCode: 8,
    );
    expect(multiple, contains('WHERE CODANIMAL IN (43, 44)'));
    expect(multiple, contains('dbo.cHORA_DO_REGISTRO()'));
    expect(
      () => animalLotTransferSql(animalCodes: const [], destinationLotCode: 8),
      throwsArgumentError,
    );
  });

  test('gera associação de chip RFID com escape e validação', () {
    expect(
      animalChipAssociationSql(43, '982000123'),
      "EXEC SP_TB_ANIMAIS_INCLUIR_CHIP 43, '982000123';",
    );
    expect(
      animalChipAssociationSql(43, "98'200"),
      "EXEC SP_TB_ANIMAIS_INCLUIR_CHIP 43, '98''200';",
    );
    expect(() => animalChipAssociationSql(0, '982000123'), throwsArgumentError);
  });

  test('gera procedimentos distintos para registrar e estornar aborto', () {
    expect(
      abortionRegisterSql(
        date: '15/05/2026',
        animalCode: 43,
        withLactation: 1,
        comment: "ABORTO D'ÁGUA",
        destinationLot: 5,
        newLactation: 2,
      ),
      "EXEC SP_TB_ABORTO_INSERT '2026-05-15', 43, 1, "
      "N'ABORTO D''ÁGUA', 5, 2;",
    );
    expect(
      abortionReverseSql(
        date: '15/05/2026',
        animalCode: 43,
        productionStatus: 'EM LEITE',
        reproductiveStatus: 'VAZIA',
        keepPregnancy: 2,
        destinationLot: 4,
        comment: "ESTORNO D'ÁGUA",
      ),
      "EXEC SP_TB_ABORTO_ESTORNO '2026-05-15', 43, N'EM LEITE', "
      "N'VAZIA', 2, 4, N'ESTORNO D''ÁGUA';",
    );
    expect(
      () => abortionRegisterSql(
        date: '31/02/2026',
        animalCode: 43,
        withLactation: 1,
        comment: '',
        destinationLot: 5,
        newLactation: 2,
      ),
      throwsFormatException,
    );
  });

  test('protege exclusão de sessão ECC com avaliações informadas', () {
    expect(
      bodyConditionCreateSessionSql('14/05/2026', 5),
      "EXEC SP_TB_ESCORE_INSERT '2026-05-14', 5;",
    );
    expect(
      bodyConditionUpdateScoreSql(71, 3),
      'EXEC SP_TB_ESCORE_UPDATE 71, 3.00;',
    );
    expect(
      () => bodyConditionUpdateScoreSql(71, double.infinity),
      throwsArgumentError,
    );
  });

  test('gera comandos de sessão e edição de ECC conforme o B4A', () {
    expect(
      bodyConditionCreateSessionSql('13/05/2026', 7),
      "EXEC SP_TB_ESCORE_INSERT '2026-05-13', 7;",
    );
    expect(
      bodyConditionUpdateScoreSql(42, 3.5),
      'EXEC SP_TB_ESCORE_UPDATE 42, 3.50;',
    );
    expect(() => bodyConditionUpdateScoreSql(42, -1), throwsArgumentError);
    expect(
      () => bodyConditionCreateSessionSql('31/02/2026', 7),
      throwsFormatException,
    );
  });

  test('consulta vacas elegíveis para pré-parto conforme o B4A', () {
    final query = animalPrecalvingQuery(tag: '43');

    expect(query, contains("STATUSPRODUCAO IN ('SECA', 'N/D')"));
    expect(query, contains('TB_PRENHEZES P'));
    expect(query, contains('TB_PREPARTO WHERE DATASAIDA IS NULL'));
    expect(query, contains('DATEADD(day, ISNULL(L.DIAS_PREPARTO, 0)'));
    expect(query, contains("BRINCO) LIKE N'%43%'"));
  });

  test('gera inclusão no pré-parto conforme procedure B4A', () {
    expect(
      animalPrecalvingInsertSql(
        animalCode: 43,
        date: '12/05/2026',
        destinationLotCode: 8,
        comment: "PRÉ-PARTO D'ÁGUA",
      ),
      "EXEC SP_TB_ANIMAIS_PREPARTO_INSERT 43, '2026-05-12', 8, "
      "N'PRÉ-PARTO D''ÁGUA';",
    );
  });

  test('consulta vacas em leite e calcula previsão de secagem', () {
    final query = animalDryOffQuery(tag: '43');

    expect(query, contains("A.STATUSPRODUCAO = 'EM LEITE'"));
    expect(query, contains('TB_LOTES L'));
    expect(query, contains('TB_PRENHEZES P'));
    expect(query, contains('DATEADD(day, ISNULL(L.DIAS_SECAGEM, 0)'));
    expect(query, contains("BRINCO) LIKE N'%43%'"));
  });

  test('gera gravação de secagem com medicamento e lote destino', () {
    expect(
      animalDryOffSql(
        animalCode: 43,
        date: '11/05/2026',
        destinationLotCode: 7,
        comment: "SECAGEM D'ÁGUA",
        medicationCode: 12,
      ),
      "EXEC SP_TB_ANIMAIS_SECAR 43, '2026-05-11', 7, "
      "N'SECAGEM D''ÁGUA', 12;",
    );
  });

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

  test('consulta bezerros aptos e permite histórico de desmame', () {
    final pending = weaningCandidateQuery(tag: 'B43');
    expect(pending, contains('TB_PARTOS P'));
    expect(pending, contains('P.PESODESMAME, 0) = 0'));
    expect(pending, contains("A.BRINCO = N'B43'"));

    final history = weaningCandidateQuery(includeWeaned: true);
    expect(history, isNot(contains('P.PESODESMAME, 0) = 0')));
  });

  test('gera atualização do desmame conforme o B4A', () {
    expect(
      animalWeaningSql(
        calfCode: 61,
        date: '10/05/2026',
        weight: 84.5,
        destinationLotCode: 9,
      ),
      "EXEC SP_TB_PARTO_DESMAME @DATA = '2026-05-10', @CODANIMAL = 61, "
      "@CODLOTEDESTINO = 9, @PESODESMAME = '84.50';",
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

  test('configura tratamentos com doença, carência e procedures B4A', () {
    final config = treatmentsConfig();

    expect(config.query, contains('INNER JOIN TB_DOENCAS'));
    expect(config.uniqueColumn, 'TRATAMENTO');
    expect(config.fields[2].optionsValueColumn, 'CODDOENCA');
    expect(config.fields[2].optionsLabelColumn, 'DOENCA');
    expect(
      config.saveSql(5, {
        'TRATAMENTO': 'MASTITE',
        'COMENTARIO': "VACA D'ÁGUA",
        'CODDOENCA': '2',
        'CARENCIA': '3',
      }),
      "EXEC SP_TB_TRATAMENTOS_INSERT_UPDATE 5, N'MASTITE', "
      "N'VACA D''ÁGUA', 2, 3;",
    );
    expect(config.deleteSql(5), 'EXEC SP_TB_TRATAMENTOS_DELETE 5;');
  });

  test('configura itens do protocolo de tratamento vinculados ao pai', () {
    final config = treatmentDetailsConfig(6);

    expect(config.query, contains('WHERE CODTRATAMENTO = 6 ORDER BY TEMPO'));
    expect(
      config.saveSql(2, {
        'DESCRICAO': "1 comprimido d'água",
        'LINHADETEMPO': 'MANHÃ',
        'TEMPO': '2',
      }),
      "EXEC SP_TB_TRATAMENTOS_DETALHES_INSERT_UPDATE 2, 6, "
      "N'1 comprimido d''água', N'MANHÃ', 2;",
    );
    expect(config.deleteSql(2), 'EXEC SP_TB_TRATAMENTOS_DETALHES_DELETE 2;');
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
