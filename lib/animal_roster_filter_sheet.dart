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
    builder: (_) => _AnimalRosterFilterSheet(
      initial: initial,
      reproductiveOptions: reproductiveOptions,
      productionOptions: productionOptions,
      lotOptions: lotOptions,
      breedOptions: breedOptions,
    ),
  );
}

class _AnimalRosterFilterSheet extends StatefulWidget {
  const _AnimalRosterFilterSheet({
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
  State<_AnimalRosterFilterSheet> createState() =>
      _AnimalRosterFilterSheetState();
}

class _AnimalRosterFilterSheetState extends State<_AnimalRosterFilterSheet> {
  late final Set<String> _reproductive = {...widget.initial.reproductive};
  late final Set<String> _production = {...widget.initial.production};
  late final Set<String> _lots = {...widget.initial.lots};
  late final Set<String> _breeds = {...widget.initial.breeds};
  late String _registrationStatus = widget.initial.registrationStatus;
  final _searchController = TextEditingController();
  String? _editingCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Set<String> get _editingSelection => switch (_editingCategory) {
    'Status reprodução' => _reproductive,
    'Status produção' => _production,
    'Lotes' => _lots,
    'Raça' => _breeds,
    'Status' => {_registrationStatus},
    _ => <String>{},
  };

  List<String> get _editingOptions => switch (_editingCategory) {
    'Status reprodução' => widget.reproductiveOptions,
    'Status produção' => widget.productionOptions,
    'Lotes' => widget.lotOptions,
    'Raça' => widget.breedOptions,
    'Status' => const [
      'A DESCARTAR',
      'ATIVO',
      'DOADORA EXTERNA',
      'DOADORA INTERNA',
      'INATIVO',
    ],
    _ => const <String>[],
  };

  List<String> get _visibleOptions {
    final query = _searchController.text.trim().toLowerCase();
    return _editingOptions
        .where((option) => option.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _toggleOption(String option) {
    setState(() {
      if (_editingCategory == 'Status') {
        _registrationStatus = option;
        return;
      }
      final selection = _editingSelection;
      if (!selection.remove(option)) selection.add(option);
    });
  }

  void _clearEditingSelection() {
    setState(() {
      if (_editingCategory == 'Status') {
        _registrationStatus = 'ATIVO';
      } else {
        _editingSelection.clear();
      }
    });
  }

  void _reset() {
    setState(() {
      _reproductive.clear();
      _production.clear();
      _lots.clear();
      _breeds.clear();
      _registrationStatus = 'ATIVO';
      _searchController.clear();
    });
  }

  void _returnToCategories() {
    setState(() {
      _editingCategory = null;
      _searchController.clear();
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
    final editing = _editingCategory != null;
    return Material(
      color: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
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
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    if (editing)
                      IconButton(
                        tooltip: 'Voltar aos filtros',
                        onPressed: _returnToCategories,
                        icon: const Icon(Icons.arrow_back),
                      )
                    else
                      const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _editingCategory ?? 'Animais - filtro',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (editing && _editingCategory != 'Status')
                      Text('${_editingSelection.length} selecionados'),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Buscar em $_editingCategory',
                    leading: const Icon(Icons.search),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              Expanded(child: editing ? _buildOptions() : _buildCategories()),
              _buildActions(editing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _FilterCategoryTile(
          title: 'Status reprodução',
          selected: _reproductive,
          onTap: () => _openCategory('Status reprodução'),
        ),
        _FilterCategoryTile(
          title: 'Status produção',
          selected: _production,
          onTap: () => _openCategory('Status produção'),
        ),
        _FilterCategoryTile(
          title: 'Lotes',
          selected: _lots,
          onTap: () => _openCategory('Lotes'),
        ),
        _FilterCategoryTile(
          title: 'Raça',
          selected: _breeds,
          onTap: () => _openCategory('Raça'),
        ),
        _FilterCategoryTile(
          title: 'Status',
          selected: {_registrationStatus},
          onTap: () => _openCategory('Status'),
        ),
      ],
    );
  }

  void _openCategory(String title) {
    setState(() {
      _editingCategory = title;
      _searchController.clear();
    });
  }

  Widget _buildOptions() {
    final options = _visibleOptions;
    final selected = _editingSelection;
    if (options.isEmpty) {
      return const Center(child: Text('Nenhuma opção disponível.'));
    }
    final optionsList = ListView.separated(
      itemCount: options.length,
      separatorBuilder: (_, index) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final option = options[index];
        if (_editingCategory == 'Status') {
          return RadioListTile<String>(
            dense: true,
            value: option,
            title: Text(option),
          );
        }
        return CheckboxListTile(
          dense: true,
          value: selected.contains(option),
          title: Text(option),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (_) => _toggleOption(option),
        );
      },
    );
    if (_editingCategory == 'Status') {
      return RadioGroup<String>(
        groupValue: _registrationStatus,
        onChanged: (value) {
          if (value != null) _toggleOption(value);
        },
        child: optionsList,
      );
    }
    return optionsList;
  }

  Widget _buildActions(bool editing) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          if (!editing)
            TextButton(onPressed: _reset, child: const Text('Limpar'))
          else
            TextButton(
              onPressed: _clearEditingSelection,
              child: const Text('Limpar seleção'),
            ),
          const Spacer(),
          OutlinedButton(
            onPressed: editing
                ? _returnToCategories
                : () => Navigator.pop(context),
            child: Text(editing ? 'Voltar' : 'Cancelar'),
          ),
          if (!editing) ...[
            const SizedBox(width: 8),
            FilledButton(onPressed: _apply, child: const Text('OK')),
          ],
        ],
      ),
    );
  }
}

class _FilterCategoryTile extends StatelessWidget {
  const _FilterCategoryTile({
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
