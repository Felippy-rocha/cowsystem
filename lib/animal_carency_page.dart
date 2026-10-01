import 'package:flutter/material.dart';

import 'animal_details_page.dart';
import 'data/animal_carency_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalCarencyPage extends StatefulWidget {
  const AnimalCarencyPage({super.key});

  @override
  State<AnimalCarencyPage> createState() => _AnimalCarencyPageState();
}

class _AnimalCarencyPageState extends State<AnimalCarencyPage> {
  static const _pageSize = 200;

  final _tagController = TextEditingController();
  late final SoapClient _client;
  late final AnimalCarencyRepository _repository;
  List<String> _types = const [];
  List<AnimalCarencyRecord> _records = const [];
  String? _selectedType;
  bool _loading = true;
  bool _hasMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalCarencyRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _records = const [];
    });
    try {
      final types = await _repository.fetchTypes();
      final selectedType = types.contains(_selectedType) ? _selectedType : null;
      final offset = reset ? 0 : _records.length;
      final rows = await _repository.fetchAnimals(
        tag: _tagController.text,
        type: selectedType,
        offset: offset,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _types = types;
        _selectedType = selectedType;
        _records = reset ? rows : [..._records, ...rows];
        _hasMore = rows.length == _pageSize;
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

  Future<void> _openAnimal(AnimalCarencyRecord record) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AnimalDetailsPage(animal: record.animal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animais em carência'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _tagController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Brinco',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Pesquisar brinco',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.search),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _load(),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _types.contains(_selectedType)
                      ? _selectedType
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de carência',
                    prefixIcon: Icon(Icons.medical_services_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Todos os tipos'),
                    ),
                    ..._types.map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (type) {
                          setState(() => _selectedType = type);
                          _load();
                        },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${_records.length} animais'),
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
          Expanded(
            child: _records.isEmpty && !_loading
                ? const Center(child: Text('Nenhum animal em carência.'))
                : ListView.separated(
                    itemCount: _records.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == _records.length) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () => _load(reset: false),
                            icon: const Icon(Icons.expand_more),
                            label: const Text('Carregar mais'),
                          ),
                        );
                      }
                      return _recordTile(_records[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _recordTile(AnimalCarencyRecord record) {
    final animal = record.animal;
    final colors = Theme.of(context).colorScheme;
    final alertColor = animal.activeCode == 1
        ? animal.discardCode == 1
              ? colors.tertiary
              : colors.primary
        : colors.error;
    final subtitle = [
      'Carência de ${record.type} · saída ${record.exitDate}',
      '${animal.productionStatus} · ${animal.reproductiveStatus}',
      if (animal.displayLot.isNotEmpty) 'Lote ${animal.displayLot}',
      if (animal.breed.isNotEmpty) animal.breed,
      if (animal.productionStatus == 'EM LEITE' && animal.daysInMilk > 0)
        'DEL ${animal.daysInMilk}',
    ].where((value) => value.isNotEmpty).join(' · ');
    return ListTile(
      onTap: () => _openAnimal(record),
      leading: CircleAvatar(
        backgroundColor: alertColor.withValues(alpha: 0.12),
        child: Icon(
          animal.activeCode == 1 && animal.discardCode != 1
              ? Icons.pets_outlined
              : Icons.warning_amber_outlined,
          color: alertColor,
        ),
      ),
      title: Text(
        animal.tag,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
