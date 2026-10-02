import 'package:flutter/material.dart';

import 'data/animal_milk_summary_repository.dart';
import 'data/animal_record.dart';
import 'data/animal_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalMilkSummaryPage extends StatefulWidget {
  const AnimalMilkSummaryPage({super.key});

  @override
  State<AnimalMilkSummaryPage> createState() => _AnimalMilkSummaryPageState();
}

class _AnimalMilkSummaryPageState extends State<AnimalMilkSummaryPage> {
  late final SoapClient _client;
  late final AnimalMilkSummaryRepository _repository;
  late final AnimalRepository _animals;
  final TextEditingController _tagController = TextEditingController();
  List<String> _lactations = const [];
  List<AnimalMilkSummaryRecord> _records = const [];
  AnimalRecord? _animal;
  String? _lactation;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalMilkSummaryRepository(soapClient: _client);
    _animals = AnimalRepository(soapClient: _client);
  }

  @override
  void dispose() {
    _tagController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _searchAnimal() async {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await _animals.fetchAnimals(
        where: "BRINCO = '${tag.replaceAll("'", "''")}'",
      );
      if (!mounted) return;
      if (found.isEmpty) {
        setState(() {
          _animal = null;
          _lactations = const [];
          _records = const [];
          _loading = false;
          _error = 'Nenhum animal encontrado para o brinco $tag.';
        });
        return;
      }
      final animal = found.first;
      final lactations = await _repository.fetchLactations(animal.animalCode);
      if (!mounted) return;
      setState(() {
        _animal = animal;
        _lactations = lactations;
        _lactation = lactations.firstOrNull;
        _records = const [];
        _loading = false;
      });
      final lactation = _lactation;
      if (lactation != null) await _loadRecords(animal.animalCode, lactation);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRecords(int animalCode, String lactationCode) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.fetchSummary(animalCode, lactationCode);
      if (!mounted) return;
      setState(() {
        _records = records;
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final animal = _animal;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo leite por animal'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Brinco',
                      prefixIcon: Icon(Icons.tag_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchAnimal(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Pesquisar',
                  onPressed: _loading ? null : _searchAnimal,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          if (animal != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DropdownButtonFormField<String>(
                initialValue: _lactations.contains(_lactation)
                    ? _lactation
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Lactação — ${animal.tag}',
                  prefixIcon: const Icon(Icons.loop_outlined),
                  border: const OutlineInputBorder(),
                ),
                items: _lactations
                    .map(
                      (code) =>
                          DropdownMenuItem(value: code, child: Text(code)),
                    )
                    .toList(growable: false),
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() => _lactation = value);
                        if (value != null) {
                          _loadRecords(animal.animalCode, value);
                        }
                      },
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: _searchAnimal,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          if (_records.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_records.length} registro(s) · '
                  'Total ${_quantity(_records.fold<double>(0, (sum, r) => sum + r.totalMilk))} kg',
                ),
              ),
            ),
          Expanded(
            child: animal == null
                ? const Center(
                    child: Text('Informe o brinco para consultar o resumo.'),
                  )
                : _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(child: Text('Nenhum registro na lactação.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: _records.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(record.del.toString()),
                          ),
                          title: Text(
                            record.date,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Leite ${_quantity(record.totalMilk)} kg · DEL ${record.del}\n'
                            'Carência ${record.withdrawalType.isEmpty ? '—' : record.withdrawalType}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
}
