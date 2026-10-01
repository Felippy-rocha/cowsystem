import 'package:flutter/material.dart';

import 'data/animal_record.dart';

enum AnimalSelectionAction {
  changeLot,
  associateChip,
  addProtocol,
  addComment,
  addInsemination,
  addTreatment,
  mating,
  editAnimal,
  discardAnimal,
  markDiscard,
  consultComments,
  consultInseminations,
  consultProtocols,
  consultTreatments,
  animalInformation,
  registerBirth,
  registerPrepartum,
  registerDrying,
}

class AnimalSelectionMenuOption {
  const AnimalSelectionMenuOption({
    required this.action,
    required this.group,
    required this.title,
    required this.icon,
    this.enabled = true,
    this.reason,
  });

  final AnimalSelectionAction action;
  final String group;
  final String title;
  final IconData icon;
  final bool enabled;
  final String? reason;
}

Future<AnimalSelectionAction?> showAnimalSelectionMenu({
  required BuildContext context,
  required List<AnimalRecord> animals,
}) {
  return showModalBottomSheet<AnimalSelectionAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AnimalSelectionMenuSheet(animals: animals),
  );
}

List<AnimalSelectionMenuOption> animalSelectionMenuOptions(
  List<AnimalRecord> animals,
) {
  if (animals.isEmpty) return const [];
  final multiple = animals.length > 1;
  if (multiple) {
    return const [
      AnimalSelectionMenuOption(
        action: AnimalSelectionAction.changeLot,
        group: 'Ações',
        title: 'Alterar loteamento',
        icon: Icons.swap_horiz_outlined,
      ),
      AnimalSelectionMenuOption(
        action: AnimalSelectionAction.addInsemination,
        group: 'Ações',
        title: 'Incluir inseminação',
        icon: Icons.science_outlined,
      ),
      AnimalSelectionMenuOption(
        action: AnimalSelectionAction.consultInseminations,
        group: 'Consultas',
        title: 'Consultar inseminações',
        icon: Icons.manage_search_outlined,
      ),
    ];
  }

  final animal = animals.single;
  final reproductive = animal.reproductiveStatus.trim().toUpperCase();
  final production = animal.productionStatus.trim().toUpperCase();
  final canInseminate =
      reproductive != 'INDUCAO' &&
      !(reproductive == 'PEV' && animal.daysInMilk < 48) &&
      animal.discardCode != 1;
  final canMate = animal.discardCode != 1;
  final isPregnant = reproductive == 'PRENHA';

  return [
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.changeLot,
      group: 'Ações',
      title: 'Alterar loteamento',
      icon: Icons.swap_horiz_outlined,
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.associateChip,
      group: 'Ações',
      title: 'Associar chip RFID',
      icon: Icons.nfc_outlined,
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.addProtocol,
      group: 'Ações',
      title: 'Incluir animal em protocolo',
      icon: Icons.assignment_outlined,
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.addComment,
      group: 'Ações',
      title: 'Incluir comentário',
      icon: Icons.comment_outlined,
    ),
    AnimalSelectionMenuOption(
      action: AnimalSelectionAction.addInsemination,
      group: 'Ações',
      title: 'Incluir inseminação',
      icon: Icons.science_outlined,
      enabled: canInseminate,
      reason: canInseminate
          ? null
          : 'Indisponível para o estado reprodutivo atual',
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.addTreatment,
      group: 'Ações',
      title: 'Incluir tratamento',
      icon: Icons.medical_services_outlined,
    ),
    AnimalSelectionMenuOption(
      action: AnimalSelectionAction.mating,
      group: 'Ações',
      title: 'Opções de acasalamento',
      icon: Icons.biotech_outlined,
      enabled: canMate,
      reason: canMate ? null : 'Animal marcado para descarte',
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.editAnimal,
      group: 'Avançado',
      title: 'Editar animal',
      icon: Icons.edit_outlined,
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.discardAnimal,
      group: 'Avançado',
      title: 'Descartar animal',
      icon: Icons.delete_outline,
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.markDiscard,
      group: 'Avançado',
      title: 'Marcar descarte',
      icon: Icons.warning_amber_outlined,
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.consultComments,
      group: 'Consultas',
      title: 'Consultar comentários',
      icon: Icons.comment_outlined,
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.consultInseminations,
      group: 'Consultas',
      title: 'Consultar inseminações',
      icon: Icons.science_outlined,
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.consultProtocols,
      group: 'Consultas',
      title: 'Consultar protocolos',
      icon: Icons.assignment_outlined,
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.consultTreatments,
      group: 'Consultas',
      title: 'Consultar tratamentos',
      icon: Icons.medical_services_outlined,
    ),
    const AnimalSelectionMenuOption(
      action: AnimalSelectionAction.animalInformation,
      group: 'Consultas',
      title: 'Informações do animal',
      icon: Icons.info_outline,
    ),
    AnimalSelectionMenuOption(
      action: AnimalSelectionAction.registerBirth,
      group: 'Serviços',
      title: 'Registrar parto',
      icon: Icons.child_friendly_outlined,
      enabled:
          isPregnant &&
          production == 'PRE-PARTO' &&
          animal.pregnancyDays >= 240,
      reason: 'Disponível para prenhas em pré-parto com 240 dias ou mais',
    ),
    AnimalSelectionMenuOption(
      action: AnimalSelectionAction.registerPrepartum,
      group: 'Serviços',
      title: 'Registrar pré-parto',
      icon: Icons.event_note_outlined,
      enabled:
          isPregnant && production == 'SECA' && animal.pregnancyDays >= 220,
      reason: 'Disponível para prenhas secas com 220 dias ou mais',
    ),
    AnimalSelectionMenuOption(
      action: AnimalSelectionAction.registerDrying,
      group: 'Serviços',
      title: 'Registrar secagem',
      icon: Icons.water_drop_outlined,
      enabled: isPregnant && production == 'EM LEITE',
      reason: 'Disponível para prenhas em leite',
    ),
  ];
}

class _AnimalSelectionMenuSheet extends StatelessWidget {
  const _AnimalSelectionMenuSheet({required this.animals});

  final List<AnimalRecord> animals;

  @override
  Widget build(BuildContext context) {
    final options = animalSelectionMenuOptions(animals);
    final groups = <String, List<AnimalSelectionMenuOption>>{};
    for (final option in options) {
      groups.putIfAbsent(option.group, () => []).add(option);
    }
    final selectedTags = animals.map((animal) => animal.tag).take(3).join(', ');
    final extraCount = animals.length - 3;

    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.84,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${animals.length} ${animals.length == 1 ? 'animal selecionado' : 'animais selecionados'}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            extraCount > 0
                                ? '$selectedTags e mais $extraCount'
                                : selectedTags,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar menu',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in groups.entries)
                      ExpansionTile(
                        initiallyExpanded: entry.key == 'Ações',
                        title: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        children: [
                          for (final option in entry.value)
                            ListTile(
                              enabled: option.enabled,
                              leading: Icon(option.icon),
                              title: Text(option.title),
                              subtitle: option.enabled || option.reason == null
                                  ? null
                                  : Text(option.reason!),
                              onTap: option.enabled
                                  ? () => Navigator.pop(context, option.action)
                                  : null,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
