import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/diet_repository.dart';
import 'data/permission_repository.dart';
import 'data/soap_client.dart';

class AnimalDietPage extends StatefulWidget {
  const AnimalDietPage({super.key});

  @override
  State<AnimalDietPage> createState() => _AnimalDietPageState();
}

class _AnimalDietPageState extends State<AnimalDietPage>
    with SingleTickerProviderStateMixin {
  late final SoapClient _client;
  late final DietRepository _repository;
  late final PermissionRepository _permissions;
  late final TabController _tabs;
  List<DietRecord> _diets = const [];
  List<DietIngredient> _ingredients = const [];
  List<DietChoice> _safra = const [];
  List<PermissionDefinitionRecord> _permissionCatalog = const [];
  Map<int, bool> _profilePermissions = const {};
  DietRecord? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = DietRepository(soapClient: _client);
    _permissions = PermissionRepository(soapClient: _client);
    _tabs = TabController(length: 2, vsync: this)..addListener(_tabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_tabChanged)
      ..dispose();
    _client.close();
    super.dispose();
  }

  void _tabChanged() {
    if (_tabs.indexIsChanging || !mounted) return;
    setState(() {});
    final selected = _selected;
    if (selected == null) return;
    if (_tabs.index == 1) _loadIngredients(selected);
  }

  bool _allowed(String action) {
    final definition = _permissionCatalog.where(
      (permission) =>
          permission.routine.toUpperCase() == 'DIETA' &&
          permission.action.toUpperCase().startsWith(action.toUpperCase()),
    );
    return definition.isNotEmpty &&
        _profilePermissions[definition.first.code] == true;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = ClientRoutingSession.profileCode;
      final permissionData = profile > 0
          ? await Future.wait([
              _permissions.fetchPermissionCatalog(),
              _permissions.fetchProfilePermissions(profile),
            ])
          : <dynamic>[<PermissionDefinitionRecord>[], <int, bool>{}];
      final catalog = permissionData[0] as List<PermissionDefinitionRecord>;
      final permissions = permissionData[1] as Map<int, bool>;
      final diets = await _repository.fetchDiets();
      final safra = await _repository.fetchSafra();
      if (!mounted) return;
      setState(() {
        _permissionCatalog = catalog;
        _profilePermissions = permissions;
        _diets = diets;
        _safra = safra;
        _loading = false;
      });
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadIngredients(DietRecord diet) async {
    setState(() {
      _loading = true;
      _selected = diet;
    });
    try {
      final rows = await _repository.fetchIngredients(diet.code);
      if (!mounted) return;
      setState(() {
        _ingredients = rows;
        _loading = false;
      });
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openDietForm({DietRecord? diet}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DietFormPage(
          repository: _repository,
          record: diet,
          permissionCatalog: _permissionCatalog,
          profilePermissions: _profilePermissions,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _openIngredientForm({DietIngredient? ingredient}) async {
    final selected = _selected;
    if (selected == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DietIngredientFormPage(
          repository: _repository,
          diet: selected,
          safra: _safra,
          ingredient: ingredient,
        ),
      ),
    );
    if (saved == true) await _loadIngredients(selected);
  }

  Future<void> _deleteIngredient(DietIngredient ingredient) async {
    final confirmed = await _confirm(
      'Excluir ingrediente?',
      'O ingrediente ${ingredient.name} será removido desta dieta.',
    );
    if (!confirmed) return;
    try {
      await _repository.deleteIngredient(ingredient.id);
      final selected = _selected;
      if (selected != null) await _loadIngredients(selected);
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<bool> _confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dietas'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          if (_tabs.index == 0 && _allowed('INCLUIR DIETA'))
            IconButton(
              tooltip: 'Incluir dieta',
              onPressed: _loading ? null : () => _openDietForm(),
              icon: const Icon(Icons.add),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Dietas'),
            Tab(text: 'Ingredientes'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: _load,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_dietList(colors), _ingredientList(colors)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dietList(ColorScheme colors) {
    if (_loading && _diets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_diets.isEmpty) {
      return const Center(child: Text('Nenhuma dieta cadastrada.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      itemCount: _diets.length,
      separatorBuilder: (_, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final diet = _diets[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: diet.active == 1
                  ? colors.primaryContainer
                  : colors.errorContainer,
              child: Icon(
                diet.active == 1
                    ? Icons.restaurant_outlined
                    : Icons.block_outlined,
              ),
            ),
            title: Text(
              diet.description,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${diet.formulator} · ${diet.date}\n'
              'MS real ${_quantity(diet.realDryMatter)}% · Qtd/dia ${diet.quantityPerDay}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              tooltip: 'Ações da dieta',
              onSelected: (action) {
                if (action == 'edit') _openDietForm(diet: diet);
                if (action == 'ingredients') {
                  _selected = diet;
                  _tabs.animateTo(1);
                  _loadIngredients(diet);
                }
              },
              itemBuilder: (context) => [
                if (_allowed('ALTERAR DIETA'))
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(
                  value: 'ingredients',
                  child: Text('Ver ingredientes'),
                ),
              ],
            ),
            onTap: () {
              setState(() => _selected = diet);
              _tabs.animateTo(1);
              _loadIngredients(diet);
            },
          ),
        );
      },
    );
  }

  Widget _ingredientList(ColorScheme colors) {
    final selected = _selected;
    if (selected == null) {
      return const Center(child: Text('Selecione uma dieta.'));
    }
    if (_loading && _ingredients.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ingredients.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: const Center(child: Text('Nenhum ingrediente nesta dieta.')),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => _openIngredientForm(),
              icon: const Icon(Icons.add),
              label: const Text('Incluir ingrediente'),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            itemCount: _ingredients.length,
            separatorBuilder: (_, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final ingredient = _ingredients[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(child: Text('${ingredient.order}')),
                  title: Text(ingredient.name),
                  subtitle: Text(
                    '${_quantity(ingredient.quantity)} kg · Preço ${_currency(ingredient.price)} · Total ${_currency(ingredient.total)}\n'
                    'Safra ${ingredient.cropYear} · MS real ${_quantity(ingredient.realDryMatter)}%',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Ações do ingrediente',
                    onSelected: (action) {
                      if (action == 'edit') {
                        _openIngredientForm(ingredient: ingredient);
                      }
                      if (action == 'delete') {
                        _deleteIngredient(ingredient);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _openIngredientForm(),
            icon: const Icon(Icons.add),
            label: const Text('Incluir ingrediente'),
          ),
        ),
      ],
    );
  }
}

class DietFormPage extends StatefulWidget {
  const DietFormPage({
    required this.repository,
    this.record,
    required this.permissionCatalog,
    required this.profilePermissions,
    super.key,
  });

  final DietRepository repository;
  final DietRecord? record;
  final List<PermissionDefinitionRecord> permissionCatalog;
  final Map<int, bool> profilePermissions;

  @override
  State<DietFormPage> createState() => _DietFormPageState();
}

class _DietFormPageState extends State<DietFormPage> {
  final _descriptionController = TextEditingController();
  final _formulatorController = TextEditingController();
  final _realDryMatterController = TextEditingController();
  final _quantityPerDayController = TextEditingController();
  late DateTime _date;
  late DateTime _dryMatterDate;
  bool _active = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _descriptionController.text = record?.description ?? '';
    _formulatorController.text = record?.formulator ?? '';
    _realDryMatterController.text = record == null
        ? ''
        : _quantity(record.realDryMatter);
    _quantityPerDayController.text = record == null
        ? '1'
        : '${record.quantityPerDay}';
    _active = record == null ? true : record.active == 1;
    _date = record == null ? DateTime.now() : _parseDate(record.date);
    _dryMatterDate = record == null
        ? DateTime.now()
        : _parseDate(record.dryMatterDate);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _formulatorController.dispose();
    _realDryMatterController.dispose();
    _quantityPerDayController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool dryMatter) async {
    final value = await showDatePicker(
      context: context,
      initialDate: dryMatter ? _dryMatterDate : _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) {
      setState(() => dryMatter ? _dryMatterDate = value : _date = value);
    }
  }

  Future<void> _save() async {
    final realDryMatter = double.tryParse(
      _realDryMatterController.text.trim().replaceAll(',', '.'),
    );
    final quantityPerDay = int.tryParse(_quantityPerDayController.text.trim());
    if (_descriptionController.text.trim().isEmpty ||
        _formulatorController.text.trim().isEmpty ||
        realDryMatter == null ||
        quantityPerDay == null ||
        quantityPerDay <= 0) {
      setState(
        () => _error =
            'Informe descrição, formulador, MS real e quantidade diária.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveDiet(
        code: widget.record?.code ?? -1,
        description: _descriptionController.text.trim(),
        date: _sqlDate(_date),
        formulator: _formulatorController.text.trim(),
        active: _active ? 1 : 0,
        dryMatterDate: _sqlDate(_dryMatterDate),
        realDryMatter: realDryMatter,
        quantityPerDay: quantityPerDay,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record == null ? 'Incluir dieta' : 'Alterar dieta'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data'),
            subtitle: Text(_displayDate(_date)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _saving ? null : () => _pickDate(false),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _formulatorController,
            decoration: const InputDecoration(
              labelText: 'Formulador',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data do MS real'),
            subtitle: Text(_displayDate(_dryMatterDate)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _saving ? null : () => _pickDate(true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _realDryMatterController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'MS real',
              suffixText: '%',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityPerDayController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantidade por dia',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile.adaptive(
            title: const Text('Ativo'),
            value: _active,
            onChanged: _saving
                ? null
                : (value) => setState(() => _active = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}

class DietIngredientFormPage extends StatefulWidget {
  const DietIngredientFormPage({
    required this.repository,
    required this.diet,
    required this.safra,
    this.ingredient,
    super.key,
  });

  final DietRepository repository;
  final DietRecord diet;
  final List<DietChoice> safra;
  final DietIngredient? ingredient;

  @override
  State<DietIngredientFormPage> createState() => _DietIngredientFormPageState();
}

class _DietIngredientFormPageState extends State<DietIngredientFormPage> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _orderController = TextEditingController();
  final _realDryMatterController = TextEditingController();
  final _dryMatterQuantityController = TextEditingController();
  int? _cropYearCode;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ingredient = widget.ingredient;
    _nameController.text = ingredient?.name ?? '';
    _quantityController.text = ingredient == null
        ? ''
        : _quantity(ingredient.quantity);
    _priceController.text = ingredient == null
        ? ''
        : _quantity(ingredient.price);
    _orderController.text = ingredient == null ? '' : '${ingredient.order}';
    _realDryMatterController.text = ingredient == null
        ? ''
        : _quantity(ingredient.realDryMatter);
    _dryMatterQuantityController.text = ingredient == null
        ? ''
        : _quantity(ingredient.dryMatterQuantity);
    _cropYearCode =
        widget.safra.any((item) => item.name == ingredient?.cropYear)
        ? widget.safra
              .firstWhere((item) => item.name == ingredient?.cropYear)
              .code
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _orderController.dispose();
    _realDryMatterController.dispose();
    _dryMatterQuantityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final quantity = double.tryParse(
      _quantityController.text.trim().replaceAll(',', '.'),
    );
    final price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );
    final order = int.tryParse(_orderController.text.trim());
    final realDryMatter = double.tryParse(
      _realDryMatterController.text.trim().replaceAll(',', '.'),
    );
    final dryMatterQuantity = double.tryParse(
      _dryMatterQuantityController.text.trim().replaceAll(',', '.'),
    );
    if (_nameController.text.trim().isEmpty ||
        quantity == null ||
        price == null ||
        order == null ||
        realDryMatter == null) {
      setState(
        () =>
            _error = 'Informe ingrediente, quantidade, preço, ordem e MS real.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveIngredient(
        id: widget.ingredient?.id ?? -1,
        dietCode: widget.diet.code,
        ingredientCode: 0,
        quantity: quantity,
        price: price,
        order: order,
        cropYear: _cropYearCode == null
            ? ''
            : widget.safra
                  .firstWhere((item) => item.code == _cropYearCode)
                  .name,
        realDryMatter: realDryMatter,
        dryMatterQuantity: dryMatterQuantity ?? 0,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ingredient == null
              ? 'Incluir ingrediente'
              : 'Editar ingrediente',
        ),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Ingrediente',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantidade (kg)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Preço por kg',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _orderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Ordem',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: widget.safra.any((item) => item.code == _cropYearCode)
                ? _cropYearCode
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Safra',
              border: OutlineInputBorder(),
            ),
            items: widget.safra
                .map(
                  (item) => DropdownMenuItem(
                    value: item.code,
                    child: Text(item.name),
                  ),
                )
                .toList(growable: false),
            onChanged: _saving
                ? null
                : (value) => setState(() => _cropYearCode = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _realDryMatterController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'MS real',
              suffixText: '%',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dryMatterQuantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantidade MS',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}

DateTime _parseDate(String value) {
  final trimmed = value.trim();
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(trimmed);
  if (match != null) {
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
  }
  return DateTime.tryParse(trimmed) ?? DateTime.now();
}

String _sqlDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');

String _currency(double value) => '\$${value.toStringAsFixed(2)}';
