import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/general_supply_inventory_repository.dart';
import 'medication_inventory_page.dart';
import 'data/soap_client.dart';

class GeneralSupplyInventoryPage extends StatefulWidget {
  const GeneralSupplyInventoryPage({super.key});

  @override
  State<GeneralSupplyInventoryPage> createState() =>
      _GeneralSupplyInventoryPageState();
}

class _GeneralSupplyInventoryPageState
    extends State<GeneralSupplyInventoryPage> {
  late final SoapClient _client;
  late final GeneralSupplyInventoryRepository _repository;
  List<GeneralSupplyInventoryDate> _dates = const [];
  List<GeneralSupplyApplication> _applications = const [];
  List<GeneralSupplyInventoryItem> _items = const [];
  int? _selectedInventoryId;
  int? _applicationCode;
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = GeneralSupplyInventoryRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load({int? preferredInventoryId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dates = await _repository.fetchDates();
      final applications = await _repository.fetchApplications();
      final inventoryId = dates.any((entry) => entry.id == preferredInventoryId)
          ? preferredInventoryId
          : dates.any((entry) => entry.id == _selectedInventoryId)
          ? _selectedInventoryId
          : dates.firstOrNull?.id;
      final applicationCode =
          applications.any((entry) => entry.code == _applicationCode)
          ? _applicationCode
          : applications.firstOrNull?.code;
      final date = dates
          .where((entry) => entry.id == inventoryId)
          .firstOrNull
          ?.date;
      final items = date == null || applicationCode == null
          ? <GeneralSupplyInventoryItem>[]
          : await _repository.fetchItems(
              date: date,
              applicationCode: applicationCode,
            );
      if (!mounted) return;
      setState(() {
        _dates = dates;
        _applications = applications;
        _selectedInventoryId = inventoryId;
        _applicationCode = applicationCode;
        _items = items;
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

  Future<void> _applyFilters({int? inventoryId, int? applicationCode}) async {
    final dateId = inventoryId ?? _selectedInventoryId;
    final selectedApplication = applicationCode ?? _applicationCode;
    final date = _dates.where((entry) => entry.id == dateId).firstOrNull?.date;
    setState(() {
      _selectedInventoryId = dateId;
      _applicationCode = selectedApplication;
      _loading = true;
      _error = null;
    });
    if (date == null || selectedApplication == null) {
      setState(() {
        _items = const [];
        _loading = false;
      });
      return;
    }
    try {
      final items = await _repository.fetchItems(
        date: date,
        applicationCode: selectedApplication,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _createInventory() async {
    final applicationCode = _applicationCode;
    final application = _applications
        .where((entry) => entry.code == applicationCode)
        .firstOrNull;
    if (applicationCode == null || application == null) {
      setState(
        () => _error = 'Selecione uma aplicação para criar o inventário.',
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Criar inventário?'),
        content: Text(
          'Será aberta uma nova contagem para ${application.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _creating = true;
      _loading = true;
      _error = null;
    });
    try {
      await _repository.createInventory(applicationCode);
      if (mounted) setState(() => _creating = false);
      await _load();
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _creating = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openItem(GeneralSupplyInventoryItem item) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            GeneralSupplyInventoryFormPage(item: item, repository: _repository),
      ),
    );
    if (saved == true) await _load(preferredInventoryId: _selectedInventoryId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final checked = _items.where((item) => item.confirmed).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventário de insumos gerais'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Criar inventário',
            onPressed: _loading || _creating || _applicationCode == null
                ? null
                : _createInventory,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue:
                      _applications.any(
                        (entry) => entry.code == _applicationCode,
                      )
                      ? _applicationCode
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Aplicação',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _applications
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.code,
                          child: Text(entry.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _loading
                      ? null
                      : (value) => _applyFilters(applicationCode: value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue:
                      _dates.any((entry) => entry.id == _selectedInventoryId)
                      ? _selectedInventoryId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Data do inventário',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _dates
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.id,
                          child: Text(entry.date),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _loading
                      ? null
                      : (value) => _applyFilters(inventoryId: value),
                ),
              ],
            ),
          ),
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
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Row(
                children: [
                  Text('${_items.length} insumo(s)'),
                  const Spacer(),
                  Text('$checked conferido(s)'),
                ],
              ),
            ),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 42),
                        const SizedBox(height: 12),
                        const Text('Nenhum insumo nesta contagem.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _creating || _applicationCode == null
                              ? null
                              : _createInventory,
                          icon: const Icon(Icons.add),
                          label: Text(
                            _creating ? 'Criando...' : 'Criar inventário',
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: _items.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final low = item.stock <= item.minimumStock;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.confirmed
                                ? colors.primaryContainer
                                : low
                                ? colors.errorContainer
                                : colors.secondaryContainer,
                            child: Icon(
                              item.confirmed
                                  ? Icons.check
                                  : low
                                  ? Icons.warning_amber_outlined
                                  : Icons.inventory_2_outlined,
                            ),
                          ),
                          title: Text(
                            item.description,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item.application} · ${item.type}\n'
                            'Estoque ${_quantity(item.stock)} · mínimo ${_quantity(item.minimumStock)} · compra ${_quantity(item.purchaseQuantity)}\n'
                            'Último preço ${_currency(item.lastPurchasePrice)}'
                            '${item.description2.isEmpty ? '' : '\n${item.description2}'}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openItem(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class GeneralSupplyInventoryFormPage extends StatefulWidget {
  const GeneralSupplyInventoryFormPage({
    required this.item,
    required this.repository,
    super.key,
  });

  final GeneralSupplyInventoryItem item;
  final GeneralSupplyInventoryRepository repository;

  @override
  State<GeneralSupplyInventoryFormPage> createState() =>
      _GeneralSupplyInventoryFormPageState();
}

class _GeneralSupplyInventoryFormPageState
    extends State<GeneralSupplyInventoryFormPage> {
  final _descriptionController = TextEditingController();
  final _description2Controller = TextEditingController();
  final _description3Controller = TextEditingController();
  final _typeController = TextEditingController();
  final _minimumController = TextEditingController();
  final _stockController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _descriptionController.text = item.description;
    _description2Controller.text = item.description2;
    _description3Controller.text = item.description3;
    _typeController.text = item.type;
    _minimumController.text = _quantity(item.minimumStock);
    _stockController.text = _quantity(item.stock);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _description2Controller.dispose();
    _description3Controller.dispose();
    _typeController.dispose();
    _minimumController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final minimum = double.tryParse(
      _minimumController.text.trim().replaceAll(',', '.'),
    );
    final stock = double.tryParse(
      _stockController.text.trim().replaceAll(',', '.'),
    );
    if (_descriptionController.text.trim().isEmpty ||
        _typeController.text.trim().isEmpty ||
        minimum == null ||
        stock == null) {
      setState(
        () => _error =
            'Informe descrição, tipo, estoque mínimo e estoque contado.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.confirmItem(
        id: widget.item.id,
        description: _descriptionController.text,
        description2: _description2Controller.text,
        description3: _description3Controller.text,
        type: _typeController.text,
        minimumStock: minimum,
        stock: stock,
      );
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message?.toString() ?? 'Confira os campos informados.';
          _saving = false;
        });
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
        title: const Text('Conferir insumo'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _generalTextField(_descriptionController, 'Descrição'),
          const SizedBox(height: 12),
          _generalTextField(_description2Controller, 'Descrição 2'),
          const SizedBox(height: 12),
          _generalTextField(_description3Controller, 'Descrição 3'),
          const SizedBox(height: 12),
          _generalTextField(_typeController, 'Tipo'),
          const SizedBox(height: 12),
          _generalTextField(
            _minimumController,
            'Estoque mínimo',
            numeric: true,
          ),
          const SizedBox(height: 12),
          _generalTextField(_stockController, 'Estoque contado', numeric: true),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_saving ? 'Salvando...' : 'Conferir insumo'),
          ),
        ],
      ),
    );
  }
}

class InventoryMenuPage extends StatelessWidget {
  const InventoryMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventariar'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.medication_outlined),
              title: const Text('Medicamentos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const MedicationInventoryPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Insumos gerais'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const GeneralSupplyInventoryPage(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _generalTextField(
  TextEditingController controller,
  String label, {
  bool numeric = false,
}) => TextField(
  controller: controller,
  keyboardType: numeric
      ? const TextInputType.numberWithOptions(decimal: true)
      : TextInputType.text,
  decoration: InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
  ),
);

String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');

String _currency(double value) => '\$${value.toStringAsFixed(2)}';
