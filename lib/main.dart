import 'package:flutter/material.dart';

import 'data/animal_record.dart';
import 'data/animal_repository.dart';
import 'data/lot_record.dart';
import 'data/lot_repository.dart';
import 'data/soap_client.dart';

void main() {
  runApp(const CowSystemApp());
}

class CowSystemApp extends StatelessWidget {
  const CowSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CowSystem',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff176b5b),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff3f7f5),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'CowSystem',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Notificacoes',
            onPressed: () => _showMessage(context, 'Nenhuma notificacao nova.'),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          IconButton(
            tooltip: 'Perfil',
            onPressed: () => _showMessage(context, 'Perfil do usuario'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Visao geral da fazenda',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Acompanhe o rebanho e as atividades do dia.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _StatusBanner(),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 620 ? 4 : 2;
                      return GridView.count(
                        crossAxisCount: columns,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: columns == 4 ? 1.45 : 1.3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: const [
                          _MetricCard(
                            label: 'Rebanho',
                            value: '--',
                            icon: Icons.pets_outlined,
                          ),
                          _MetricCard(
                            label: 'Leite hoje',
                            value: '-- L',
                            icon: Icons.water_drop_outlined,
                          ),
                          _MetricCard(
                            label: 'Tarefas abertas',
                            value: '--',
                            icon: Icons.checklist_outlined,
                          ),
                          _MetricCard(
                            label: 'Alertas',
                            value: '--',
                            icon: Icons.warning_amber_outlined,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Acesso rapido',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _QuickAccessGrid(),
                  const SizedBox(height: 24),
                  Text(
                    'Modulos',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _ModuleList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class ModulePage extends StatelessWidget {
  const ModulePage({required this.title, super.key});

  final String title;

  List<_ModuleEntry> get _entries {
    switch (title) {
      case 'Cadastros':
        return const [
          _ModuleEntry('Animais', Icons.pets_outlined),
          _ModuleEntry('Lotes', Icons.grid_view_outlined),
          _ModuleEntry('Fornecedores', Icons.local_shipping_outlined),
          _ModuleEntry('Insumos gerais', Icons.inventory_2_outlined),
          _ModuleEntry('Medicamentos', Icons.medication_outlined),
          _ModuleEntry('Protocolos', Icons.assignment_outlined),
          _ModuleEntry('Tratamentos', Icons.healing_outlined),
          _ModuleEntry('Touros', Icons.pets_outlined),
        ];
      case 'Servicos':
        return const [
          _ModuleEntry('Controle leiteiro', Icons.water_drop_outlined),
          _ModuleEntry('Pesagem', Icons.monitor_weight_outlined),
          _ModuleEntry('Inseminacao', Icons.science_outlined),
          _ModuleEntry('Diagnostico gestacional', Icons.monitor_heart_outlined),
          _ModuleEntry('Parto', Icons.child_friendly_outlined),
          _ModuleEntry('Registrar desmame', Icons.swap_horiz_outlined),
          _ModuleEntry('Registrar secagem', Icons.opacity_outlined),
          _ModuleEntry('Casqueamento', Icons.content_cut_outlined),
        ];
      case 'Relatorios':
        return const [
          _ModuleEntry('Resumo do rebanho', Icons.pets_outlined),
          _ModuleEntry('Resumo de leite', Icons.water_drop_outlined),
          _ModuleEntry('Analise de consumo', Icons.analytics_outlined),
          _ModuleEntry('Analise de partos', Icons.family_restroom_outlined),
          _ModuleEntry('Previsao de toque', Icons.event_available_outlined),
          _ModuleEntry('Tarefas em aberto', Icons.checklist_outlined),
        ];
      case 'Ajustes':
        return const [
          _ModuleEntry('Perfil', Icons.person_outline),
          _ModuleEntry('Sincronizacao', Icons.sync_outlined),
          _ModuleEntry('Notificacoes', Icons.notifications_none_outlined),
          _ModuleEntry('Configuracoes', Icons.settings_outlined),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        separatorBuilder: (_, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return Card(
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 6,
              ),
              leading: Icon(entry.icon, color: colors.primary),
              title: Text(
                entry.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) {
                      if (entry.label == 'Animais') return const AnimalsPage();
                      if (entry.label == 'Lotes') return const LotsPage();
                      return ModulePage(title: entry.label);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ModuleEntry {
  const _ModuleEntry(this.label, this.icon);

  final String label;
  final IconData icon;
}

class LotsPage extends StatefulWidget {
  const LotsPage({super.key});

  @override
  State<LotsPage> createState() => _LotsPageState();
}

class _LotsPageState extends State<LotsPage> {
  final _searchController = TextEditingController();
  late final SoapClient _soapClient;
  late final LotRepository _repository;
  List<LotRecord> _lots = const [];
  int _selectedTab = 0;
  int? _selectedLotCode;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _soapClient = SoapClient();
    _repository = LotRepository(soapClient: _soapClient);
    _loadLots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _soapClient.close();
    super.dispose();
  }

  List<LotRecord> get _filteredLots {
    final query = _searchController.text.trim().toLowerCase();
    return _lots
        .where((lot) => lot.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loadLots,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Adicionar lote',
            onPressed: _openLotForm,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Lote',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Lista')),
              ButtonSegment(value: 1, label: Text('Grid')),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (selection) {
              setState(() => _selectedTab = selection.first);
            },
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLots.isEmpty
                    ? Center(
                        child: Text(
                          _errorMessage ?? 'Nenhum lote cadastrado',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _selectedTab == 0
                        ? ListView.separated(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                            itemCount: _filteredLots.length,
                            separatorBuilder: (_, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) =>
                                _lotListTile(_filteredLots[index]),
                          )
                        : _lotsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _lotListTile(LotRecord lot) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      title: Text(lot.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      subtitle: Text(
        'Status: ${_lotStatusLabel(lot)}\n'
        'Dieta: ${_lotDietLabel(lot)}\n'
        'DG: ${_binaryLabel(lot.pregnancyDiagnosis)} | '
        'Aleitamento: ${_binaryLabel(lot.milkFeeding)}',
        style: const TextStyle(fontSize: 15, height: 1.5),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opcoes do lote',
        onSelected: (action) {
          if (action == 'edit') _openLotForm(lot);
          if (action == 'delete') _confirmDelete(lot);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Alterar')),
          PopupMenuItem(value: 'delete', child: Text('Excluir')),
        ],
      ),
    );
  }

  Widget _lotsGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width),
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: IntrinsicColumnWidth(),
            },
            border: const TableBorder(
              horizontalInside: BorderSide(color: Color(0xff283593)),
              verticalInside: BorderSide(color: Color(0xff283593)),
              top: BorderSide(color: Color(0xff283593)),
              bottom: BorderSide(color: Color(0xff283593)),
              left: BorderSide(color: Color(0xff283593)),
              right: BorderSide(color: Color(0xff283593)),
            ),
            children: [
              _gridRow(
                const [Text('Lote'), Text('Status')],
                header: true,
              ),
              ..._filteredLots.map(
                (lot) => _gridRow(
                  [
                    Text(lot.name, softWrap: false),
                    _gridStatusCell(lot),
                  ],
                  selected: _selectedLotCode == lot.code,
                  onTap: () => setState(() => _selectedLotCode = lot.code),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridStatusCell(LotRecord lot) {
    final status = _lotStatusLabel(lot);
    if (_selectedLotCode != lot.code) return Text(status, softWrap: false);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(status, softWrap: false),
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          tooltip: 'Acoes do lote',
          icon: const Icon(Icons.more_horiz, size: 24),
          onSelected: (action) {
            if (action == 'edit') _openLotForm(lot);
            if (action == 'delete') _confirmDelete(lot);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Alterar')),
            PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      ],
    );
  }

  String _lotStatusLabel(LotRecord lot) {
    final status = lot.productionStatus.trim();
    return status.isEmpty ? 'N/D' : status;
  }

  String _lotDietLabel(LotRecord lot) {
    final diet = lot.diet.trim();
    return diet.isEmpty ? 'N/D' : diet;
  }

  String _binaryLabel(int value) {
    if (value == 1) return 'SIM';
    if (value == 2) return 'NAO';
    return 'N/D';
  }

  TableRow _gridRow(
    List<Widget> cells, {
    bool header = false,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        color: header
            ? const Color(0xffd1cfd1)
            : selected
                ? const Color(0xffffe500)
                : Colors.white,
      ),
      children: cells
          .map(
            (cell) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: InkWell(
                onTap: header ? null : onTap,
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: header ? 22 : 20,
                    fontWeight: FontWeight.w400,
                  ),
                  child: cell,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _openLotForm([LotRecord? existing]) async {
    final lot = await Navigator.of(context).push<LotRecord>(
      MaterialPageRoute<LotRecord>(
        builder: (_) => LotFormPage(
          existing: existing,
          statusOptions: _statusOptions,
          dietOptions: _dietOptions,
        ),
      ),
    );
    if (lot == null || !mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _repository.insertLot(lot);
      if (mounted) setState(() => _isLoading = false);
      await _loadLots();
    } on SoapException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<int, String> get _statusOptions => {
        for (final lot in _lots)
          if (lot.productionStatus.trim().isNotEmpty)
            lot.productionStatusCode: lot.productionStatus.trim(),
      };

  Map<int, String> get _dietOptions => {
        for (final lot in _lots)
          if (lot.diet.trim().isNotEmpty) lot.dietCode: lot.diet.trim(),
      };

  Future<void> _confirmDelete(LotRecord lot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lote?'),
        content: Text('O lote "${lot.name}" sera excluido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _repository.deleteLot(lot.code);
      if (mounted) setState(() => _isLoading = false);
      await _loadLots();
    } on SoapException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLots() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final lots = await _repository.fetchLots();
      if (mounted) setState(() => _lots = lots);
    } on SoapException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'Nao foi possivel consultar o Azure.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class LotFormPage extends StatefulWidget {
  const LotFormPage({
    this.existing,
    this.statusOptions = const {},
    this.dietOptions = const {},
    super.key,
  });

  final LotRecord? existing;
  final Map<int, String> statusOptions;
  final Map<int, String> dietOptions;

  @override
  State<LotFormPage> createState() => _LotFormPageState();
}

class _LotFormPageState extends State<LotFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dryingController = TextEditingController(text: '0');
  final _preCalvingController = TextEditingController(text: '0');
  final _stallController = TextEditingController(text: '0');
  int _statusValue = 0;
  int _dietValue = 0;
  int _diagnosisValue = 0;
  int _feedingValue = 0;

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _dryingController,
      _preCalvingController,
      _stallController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final lot = widget.existing;
    if (lot != null) {
      _nameController.text = lot.name;
      _statusValue = lot.productionStatusCode;
      _dietValue = lot.dietCode;
      _dryingController.text = '${lot.dryingDays}';
      _preCalvingController.text = '${lot.preCalvingDays}';
      _diagnosisValue = lot.pregnancyDiagnosis;
      _feedingValue = lot.milkFeeding;
      _stallController.text = '${lot.stallType}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Incluir lote' : 'Alterar lote'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do lote',
                prefixIcon: Icon(Icons.grid_view_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Preenchimento obrigatorio'
                  : null,
            ),
            const SizedBox(height: 16),
            selectField(
              label: 'Status producao',
              value: _statusValue,
              options: widget.statusOptions,
              onChanged: (value) => setState(() => _statusValue = value!),
            ),
            const SizedBox(height: 12),
            selectField(
              label: 'Dieta',
              value: _dietValue,
              options: widget.dietOptions,
              onChanged: (value) => setState(() => _dietValue = value!),
            ),
            const SizedBox(height: 12),
            numberField(_dryingController, 'Dias de secagem'),
            const SizedBox(height: 12),
            numberField(_preCalvingController, 'Dias de pre-parto'),
            const SizedBox(height: 12),
            selectField(
              label: 'Diagnostico gestacional',
              value: _diagnosisValue,
              options: const {1: 'SIM', 2: 'NAO'},
              onChanged: (value) => setState(() => _diagnosisValue = value!),
            ),
            const SizedBox(height: 12),
            selectField(
              label: 'Aleitamento',
              value: _feedingValue,
              options: const {1: 'SIM', 2: 'NAO'},
              onChanged: (value) => setState(() => _feedingValue = value!),
            ),
            const SizedBox(height: 12),
            numberField(_stallController, 'Tipo de baia'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar lote'),
            ),
          ],
        ),
      ),
    );
  }

  Widget numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => int.tryParse(value ?? '') == null
          ? 'Informe um numero inteiro'
          : null,
    );
  }

  Widget selectField({
    required String label,
    required int value,
    required Map<int, String> options,
    required ValueChanged<int?> onChanged,
  }) {
    final values = {...options};
    values.putIfAbsent(value, () => value == 0 ? 'N/D' : '$value');
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      hint: const Text('Selecione uma opcao'),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.arrow_drop_down_circle_outlined),
        border: const OutlineInputBorder(),
      ),
      items: values.entries
          .map(
            (entry) => DropdownMenuItem<int>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  void save() {
    if (!_formKey.currentState!.validate()) return;
    int number(TextEditingController controller) => int.parse(controller.text);
    Navigator.of(context).pop(
      LotRecord(
        code: widget.existing?.code ?? -1,
        name: _nameController.text.trim(),
        productionStatusCode: _statusValue,
        dietCode: _dietValue,
        dryingDays: number(_dryingController),
        preCalvingDays: number(_preCalvingController),
        pregnancyDiagnosis: _diagnosisValue,
        milkFeeding: _feedingValue,
        stallType: number(_stallController),
      ),
    );
  }
}

class AnimalsPage extends StatefulWidget {
  const AnimalsPage({super.key});

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  final searchController = TextEditingController();
  final List<AnimalRecord> animals0 = [];
  late final SoapClient soapClient;
  late final AnimalRepository repository;
  int selectedTab = 0;
  bool onlyActive = true;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    soapClient = SoapClient();
    repository = AnimalRepository(soapClient: soapClient);
    loadAnimals();
  }

  @override
  void dispose() {
    searchController.dispose();
    soapClient.close();
    super.dispose();
  }

  List<AnimalRecord> get _filteredAnimals {
    final query = searchController.text.trim().toLowerCase();
    return animals0.where((animal) {
      final matchesQuery =
          query.isEmpty || animal.tag.toLowerCase().contains(query);
      return matchesQuery && (!onlyActive || animal.active);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animais'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: loadAnimals,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Adicionar animal',
            onPressed: () async {
              final animal = await Navigator.of(context).push<AnimalRecord>(
                MaterialPageRoute<AnimalRecord>(
                  builder: (_) => const AnimalFormPage(),
                ),
              );
              if (animal != null && mounted) {
                setState(() => animals0.add(animal));
              }
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Pesquisar por brinco',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Filtros',
                  onPressed: () => showMessage('Filtros avancados em breve.'),
                  icon: const Icon(Icons.tune),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Ativos'),
                  selected: onlyActive,
                  onSelected: (selected) {
                    setState(() => onlyActive = selected);
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filteredAnimals.length} registro(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Lista'),
                  icon: Icon(Icons.view_list),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Grade'),
                  icon: Icon(Icons.grid_view),
                ),
              ],
              selected: {selectedTab},
              onSelectionChanged: (selection) {
                setState(() => selectedTab = selection.first);
              },
            ),
          ),
          Expanded(
            child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredAnimals.isEmpty
                ? _AnimalsEmptyState(errorMessage: errorMessage)
                : selectedTab == 0
                  ? _AnimalsList(animals: _filteredAnimals)
                  : _AnimalsGrid(animals: _filteredAnimals),
          ),
        ],
      ),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> loadAnimals() async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final animals = await repository.fetchAnimals();
      if (!mounted) return;
      setState(() {
        animals0
          ..clear()
          ..addAll(animals);
      });
    } on SoapException catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = 'Nao foi possivel consultar o Azure.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}

class _AnimalsList extends StatelessWidget {
  const _AnimalsList({required this.animals});

  final List<AnimalRecord> animals;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: animals.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final animal = animals[index];
        return Card(
          elevation: 0,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.pets_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              'Brinco ${animal.tag}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${animal.breed}  |  ${animal.reproductiveStatus}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDetails(context, animal),
          ),
        );
      },
    );
  }

  void showDetails(BuildContext context, AnimalRecord animal) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Animal ${animal.tag}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('Raca: ${animal.breed}'),
            Text('Status reprodutivo: ${animal.reproductiveStatus}'),
            Text(
              'Status produtivo: ${animal.productionStatus.isEmpty ? 'Nao informado' : animal.productionStatus}',
            ),
            Text('Lote: ${animal.lot.isEmpty ? 'Nao informado' : animal.lot}'),
          ],
        ),
      ),
    );
  }
}

class _AnimalsGrid extends StatelessWidget {
  const _AnimalsGrid({required this.animals});

  final List<AnimalRecord> animals;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 160,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: animals.length,
      itemBuilder: (context, index) {
        final animal = animals[index];
        return Card(
          elevation: 0,
          child: InkWell(
            onTap: () => showDetails(context, animal),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.pets_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Text(
                    'Brinco ${animal.tag}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(animal.breed, overflow: TextOverflow.ellipsis),
                  Text(
                    animal.reproductiveStatus,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void showDetails(BuildContext context, AnimalRecord animal) {
    _AnimalsList(animals: [animal]).showDetails(context, animal);
  }
}

class AnimalFormPage extends StatefulWidget {
  const AnimalFormPage({super.key});

  @override
  State<AnimalFormPage> createState() => _AnimalFormPageState();
}

class _AnimalFormPageState extends State<AnimalFormPage> {
  final formKey = GlobalKey<FormState>();
  final tagController = TextEditingController();
  final electronicTagController = TextEditingController();
  final birthDateController = TextEditingController();
  final lactationsController = TextEditingController();
  final lastBirthController = TextEditingController();

  String? donor;
  String? lot;
  String? breed;
  String? reproductiveStatus;
  String? productionStatus;
  String? origin;
  String? betaCasein;

  @override
  void dispose() {
    tagController.dispose();
    electronicTagController.dispose();
    birthDateController.dispose();
    lactationsController.dispose();
    lastBirthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incluir animal'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Identificacao',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            requiredTextField(
              controller: tagController,
              label: 'Brinco',
              icon: Icons.sell_outlined,
            ),
            const SizedBox(height: 12),
            textField(
              controller: electronicTagController,
              label: 'Brinco eletronico',
              icon: Icons.nfc_outlined,
            ),
            const SizedBox(height: 20),
            Text(
              'Dados do animal',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            dropdown(
              label: 'Doadora',
              value: donor,
              values: const ['Sim', 'Nao'],
              onChanged: (value) => setState(() => donor = value),
              required: true,
            ),
            const SizedBox(height: 12),
            dropdown(
              label: 'Lote',
              value: lot,
              values: const ['A definir', 'Lote 1', 'Lote 2'],
              onChanged: (value) => setState(() => lot = value),
            ),
            const SizedBox(height: 12),
            dateField(birthDateController, 'Data de nascimento'),
            const SizedBox(height: 12),
            dropdown(
              label: 'Raca',
              value: breed,
              values: const ['A definir', 'Holandesa', 'Jersey', 'Girolando'],
              onChanged: (value) => setState(() => breed = value),
              required: true,
            ),
            const SizedBox(height: 12),
            dropdown(
              label: 'Status reprodutivo',
              value: reproductiveStatus,
              values: const ['NAO APTA', 'Vazia', 'Prenha', 'Inseminada'],
              onChanged: (value) => setState(() => reproductiveStatus = value),
              required: true,
            ),
            const SizedBox(height: 12),
            dropdown(
              label: 'Status produtivo',
              value: productionStatus,
              values: const ['Seca', 'Em leite', 'Novilha'],
              onChanged: (value) => setState(() => productionStatus = value),
            ),
            const SizedBox(height: 12),
            numberField(lactationsController, 'Numero de lactacoes'),
            const SizedBox(height: 12),
            dateField(lastBirthController, 'Ultimo parto'),
            const SizedBox(height: 12),
            dropdown(
              label: 'Origem',
              value: origin,
              values: const ['Nascida na fazenda', 'Comprada', 'Transferida'],
              onChanged: (value) => setState(() => origin = value),
            ),
            const SizedBox(height: 12),
            dropdown(
              label: 'Beta-caseina',
              value: betaCasein,
              values: const ['Nao informado', 'A1A1', 'A1A2', 'A2A2'],
              onChanged: (value) => setState(() => betaCasein = value),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar animal'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget requiredTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return textField(
      controller: controller,
      label: label,
      icon: icon,
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Preenchimento obrigatorio'
          : null,
    );
  }

  Widget textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.numbers),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget dateField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
          initialDate: DateTime.now(),
        );
        if (date != null) {
          controller.text =
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget dropdown({
    required String label,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
    bool required = false,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: const Text('Selecione uma opcao'),
      validator: required
          ? (current) => current == null ? 'Selecione uma opcao' : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.arrow_drop_down_circle_outlined),
        border: const OutlineInputBorder(),
      ),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      AnimalRecord(
        tag: tagController.text.trim(),
        electronicTag: electronicTagController.text.trim(),
        donor: donor!,
        lot: lot ?? '',
        birthDate: birthDateController.text,
        breed: breed!,
        reproductiveStatus: reproductiveStatus!,
        productionStatus: productionStatus ?? '',
        origin: origin ?? '',
        betaCasein: betaCasein ?? '',
      ),
    );
  }
}

class _AnimalsEmptyState extends StatelessWidget {
  const _AnimalsEmptyState({this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pets_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum animal carregado',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ??
                  'Os animais serao consultados no banco Azure quando a sincronizacao estiver conectada.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_done_outlined, color: colors.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Conectado ao CowSystem',
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text('Azure', style: TextStyle(color: colors.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: colors.primary),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 1 ? 5.1 : 2.1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _ActionTile(
              tileLabel: 'Controle leiteiro',
              icon: Icons.water_drop_outlined,
            ),
            _ActionTile(tileLabel: 'Tarefas', icon: Icons.checklist_outlined),
            _ActionTile(
              tileLabel: 'Diagnostico gestacional',
              icon: Icons.monitor_heart_outlined,
            ),
          ],
        );
      },
    );
  }
}

class _ModuleList extends StatelessWidget {
  const _ModuleList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _ActionTile(
          tileLabel: 'Cadastros',
          subtitle: 'Animais, lotes, fornecedores e insumos',
          icon: Icons.folder_copy_outlined,
        ),
        SizedBox(height: 10),
        _ActionTile(
          tileLabel: 'Servicos',
          subtitle: 'Manejo, inseminacao, pesagem e parto',
          icon: Icons.handyman_outlined,
        ),
        SizedBox(height: 10),
        _ActionTile(
          tileLabel: 'Relatorios',
          subtitle: 'Indicadores de leite, rebanho e estoque',
          icon: Icons.bar_chart_outlined,
        ),
        SizedBox(height: 10),
        _ActionTile(
          tileLabel: 'Ajustes',
          subtitle: 'Perfil, sincronizacao e configuracoes',
          icon: Icons.settings_outlined,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.tileLabel,
    required this.icon,
    this.subtitle,
  });

  final String tileLabel;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ModulePage(title: tileLabel),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tileLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
