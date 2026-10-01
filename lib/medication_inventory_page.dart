import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/medication_inventory_repository.dart';
import 'data/soap_client.dart';

class MedicationInventoryPage extends StatefulWidget {
  const MedicationInventoryPage({super.key});

  @override
  State<MedicationInventoryPage> createState() =>
      _MedicationInventoryPageState();
}

class _MedicationInventoryPageState extends State<MedicationInventoryPage> {
  late final SoapClient _client;
  late final MedicationInventoryRepository _repository;
  List<MedicationInventoryDate> _dates = const [];
  List<MedicationInventoryItem> _items = const [];
  int? _selectedId;
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = MedicationInventoryRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load({int? preferredId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dates = await _repository.fetchDates();
      final id = dates.any((entry) => entry.id == preferredId)
          ? preferredId
          : dates.any((entry) => entry.id == _selectedId)
          ? _selectedId
          : dates.firstOrNull?.id;
      final date = dates.where((entry) => entry.id == id).firstOrNull?.date;
      final items = date == null
          ? <MedicationInventoryItem>[]
          : await _repository.fetchItems(date);
      if (!mounted) return;
      setState(() {
        _dates = dates;
        _selectedId = id;
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

  Future<void> _selectDate(int? id) async {
    if (id == null) return;
    final date = _dates.where((entry) => entry.id == id).firstOrNull?.date;
    if (date == null) return;
    setState(() {
      _selectedId = id;
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.fetchItems(date);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Criar inventário?'),
        content: const Text(
          'Será aberta uma nova contagem para os medicamentos cadastrados.',
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
      await _repository.createInventory();
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

  Future<void> _openItem(MedicationInventoryItem item) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            MedicationInventoryFormPage(item: item, repository: _repository),
      ),
    );
    if (saved == true) await _load(preferredId: _selectedId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final checked = _items.where((item) => item.confirmed).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventário de medicamentos'),
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
            onPressed: _loading || _creating ? null : _createInventory,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: DropdownButtonFormField<int>(
              initialValue: _dates.any((entry) => entry.id == _selectedId)
                  ? _selectedId
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
              onChanged: _loading ? null : _selectDate,
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
                  Text('${_items.length} medicamento(s)'),
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
                        const Text('Nenhum inventário de medicamentos.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _creating ? null : _createInventory,
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
                                  : Icons.medication_outlined,
                            ),
                          ),
                          title: Text(
                            item.medication,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Estoque contado ${_quantity(item.stock)} · mínimo ${_quantity(item.minimumStock)}\n'
                            'Compra sugerida ${_quantity(item.purchaseQuantity)}'
                            '${item.option1.isEmpty ? '' : '\n${item.option1}'}',
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

class MedicationInventoryFormPage extends StatefulWidget {
  const MedicationInventoryFormPage({
    required this.item,
    required this.repository,
    super.key,
  });

  final MedicationInventoryItem item;
  final MedicationInventoryRepository repository;

  @override
  State<MedicationInventoryFormPage> createState() =>
      _MedicationInventoryFormPageState();
}

class _MedicationInventoryFormPageState
    extends State<MedicationInventoryFormPage> {
  final _medicationController = TextEditingController();
  final _option1Controller = TextEditingController();
  final _option2Controller = TextEditingController();
  final _option3Controller = TextEditingController();
  final _minimumController = TextEditingController();
  final _stockController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _medicationController.text = item.medication;
    _option1Controller.text = item.option1;
    _option2Controller.text = item.option2;
    _option3Controller.text = item.option3;
    _minimumController.text = _quantity(item.minimumStock);
    _stockController.text = _quantity(item.stock);
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _option1Controller.dispose();
    _option2Controller.dispose();
    _option3Controller.dispose();
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
    if (_medicationController.text.trim().isEmpty ||
        minimum == null ||
        stock == null) {
      setState(
        () => _error = 'Informe medicamento, estoque mínimo e estoque contado.',
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
        medication: _medicationController.text,
        option1: _option1Controller.text,
        option2: _option2Controller.text,
        option3: _option3Controller.text,
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
        title: const Text('Conferir medicamento'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _medicationController,
            decoration: const InputDecoration(
              labelText: 'Medicamento',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _option1Controller,
            decoration: const InputDecoration(
              labelText: 'Opção 1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _option2Controller,
            decoration: const InputDecoration(
              labelText: 'Opção 2',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _option3Controller,
            decoration: const InputDecoration(
              labelText: 'Opção 3',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minimumController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Estoque mínimo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _stockController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Estoque contado',
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
            icon: const Icon(Icons.check),
            label: Text(_saving ? 'Salvando...' : 'Conferir medicamento'),
          ),
        ],
      ),
    );
  }
}

String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
