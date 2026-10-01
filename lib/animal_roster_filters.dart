import 'package:flutter/material.dart';

class AnimalRosterFilters {
  const AnimalRosterFilters({
    required this.reproductive,
    required this.production,
    required this.lots,
    required this.breeds,
    required this.registrationStatus,
  });

  final Set<String> reproductive;
  final Set<String> production;
  final Set<String> lots;
  final Set<String> breeds;
  final String registrationStatus;
}

Future<AnimalRosterFilters?> showAnimalRosterFilters({
  required BuildContext context,
  required AnimalRosterFilters initial,
  required List<String> reproductiveOptions,
  required List<String> productionOptions,
  required List<String> lotOptions,
  required List<String> breedOptions,
}) {
  return showModalBottomSheet<AnimalRosterFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AnimalRosterFiltersSheet(
      initial: initial,
      reproductiveOptions: reproductiveOptions,
      productionOptions: productionOptions,
      lotOptions: lotOptions,
      breedOptions: breedOptions,
    ),
  );
}

class _AnimalRosterFiltersSheet extends StatefulWidget {
  const _AnimalRosterFiltersSheet({
    required this.initial,
    required this.reproductiveOptions,
    required this.productionOptions,
    required this.lotOptions,
    required this.breedOptions,
  });

  final AnimalRosterFilters initial;
  final List<String> reproductiveOptions;
  final List<String> productionOptions;
  final List<String> lotOptions;
  final List<String> breedOptions;

  @override
  State<_AnimalRosterFiltersSheet> createState() =>
      _AnimalRosterFiltersSheetState();
}

class _AnimalRosterFiltersSheetState extends State<_AnimalRosterFiltersSheet> {
  late final Set<String> _reproductive = {...widget.initial.reproductive};
  late final Set<String> _production = {...widget.initial.production};
  late final Set<String> _lots = {...widget.initial.lots};
  late final Set<String> _breeds = {...widget.initial.breeds};
  late String _registrationStatus = widget.initial.registrationStatus;

  Future<Set<String>?> _chooseOptions({
    required String title,
    required List<String> options,
    required Set<String> initial,
  }) async {
    final searchController = TextEditingController();
    final selected = {...initial};
    try {
      return await showModalBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) {
            final query = searchController.text.trim().toLowerCase();
            final visible = options
                .where((option) => option.toLowerCase().contains(query))
                .toList(growable: false);
            return Material(
              color: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.86,
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text('${selected.length} selecionados'),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SearchBar(
                          controller: searchController,
                          hintText: 'Buscar $title',
                          leading: const Icon(Icons.search),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                      Expanded(
                        child: visible.isEmpty
                            ? const Center(
                                child: Text('Nenhuma opção encontrada.'),
                              )
                            : ListView.separated(
                                itemCount: visible.length,
                                separatorBuilder: (_, index) => const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                                itemBuilder: (context, index) {
                                  final option = visible[index];
                                  return CheckboxListTile(
                                    dense: true,
                                    value: selected.contains(option),
                                    title: Text(option),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    onChanged: (checked) => setSheetState(() {
                                      if (checked == true) {
                                        selected.add(option);
                                      } else {
                                        selected.remove(option);
                                      }
                                    }),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => Navigator.pop(
                                sheetContext,
                                Set<String>.from(selected),
                              ),
                              child: const Text('Selecionar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      searchController.dispose();
    }
  }

  Future<void> _chooseAndSet({
    required String title,
    required List<String> options,
    required Set<String> selection,
  }) async {
    final result = await _chooseOptions(
      title: title,
      options: options,
      initial: selection,
    );
    if (result == null || !mounted) return;
    setState(() {
      selection
        ..clear()
        ..addAll(result);
    });
  }

  void _clear() {
    setState(() {
      _reproductive.clear();
      _production.clear();
      _lots.clear();
      _breeds.clear();
      _registrationStatus = 'ATIVO';
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      AnimalRosterFilters(
        reproductive: {..._reproductive},
        production: {..._production},
        lots: {..._lots},
        breeds: {..._breeds},
        registrationStatus: _registrationStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Animais - filtro',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _MultiFilterSection(
                    title: 'Status reprodução',
                    selected: _reproductive,
                    onTap: () => _chooseAndSet(
                      title: 'Status reprodução',
                      options: widget.reproductiveOptions,
                      selection: _reproductive,
                    ),
                  ),
                  _MultiFilterSection(
                    title: 'Status produção',
                    selected: _production,
                    onTap: () => _chooseAndSet(
                      title: 'Status produção',
                      options: widget.productionOptions,
                      selection: _production,
                    ),
                  ),
                  _MultiFilterSection(
                    title: 'Lotes',
                    selected: _lots,
                    onTap: () => _chooseAndSet(
                      title: 'Lotes',
                      options: widget.lotOptions,
                      selection: _lots,
                    ),
                  ),
                  _MultiFilterSection(
                    title: 'Raça',
                    selected: _breeds,
                    onTap: () => _chooseAndSet(
                      title: 'Raça',
                      options: widget.breedOptions,
                      selection: _breeds,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_registrationStatus),
                    initialValue: _registrationStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'A DESCARTAR',
                        child: Text('A DESCARTAR'),
                      ),
                      DropdownMenuItem(value: 'ATIVO', child: Text('ATIVO')),
                      DropdownMenuItem(
                        value: 'DOADORA EXTERNA',
                        child: Text('DOADORA EXTERNA'),
                      ),
                      DropdownMenuItem(
                        value: 'DOADORA INTERNA',
                        child: Text('DOADORA INTERNA'),
                      ),
                      DropdownMenuItem(
                        value: 'INATIVO',
                        child: Text('INATIVO'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _registrationStatus = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  TextButton(onPressed: _clear, child: const Text('Limpar')),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _apply, child: const Text('OK')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiFilterSection extends StatelessWidget {
  const _MultiFilterSection({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final Set<String> selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = selected.isEmpty
        ? 'Todos'
        : selected.length == 1
        ? selected.first
        : '${selected.length} selecionados';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(title),
      subtitle: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
