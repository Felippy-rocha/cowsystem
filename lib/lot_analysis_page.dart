import 'package:flutter/material.dart';

import 'data/animal_record.dart';
import 'data/animal_repository.dart';
import 'data/client_routing.dart';
import 'data/lot_record.dart';
import 'data/lot_repository.dart';
import 'data/soap_client.dart';

class LotAnalysisPage extends StatefulWidget {
  const LotAnalysisPage({super.key});

  @override
  State<LotAnalysisPage> createState() => _LotAnalysisPageState();
}

class _LotAnalysisPageState extends State<LotAnalysisPage> {
  late final SoapClient _client;
  late final LotRepository _lotRepository;
  late final AnimalRepository _animalRepository;
  final _searchController = TextEditingController();
  List<LotRecord> _lots = const [];
  List<AnimalRecord> _animals = const [];
  int? _selectedLotCode;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _lotRepository = LotRepository(soapClient: _client);
    _animalRepository = AnimalRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lots = await _lotRepository.fetchLots();
      final animals = await _animalRepository.fetchAnimals(
        where: 'WHERE ATIVO = 1 AND DOADORA IN (2, 3)',
      );
      if (!mounted) return;
      setState(() {
        _lots = lots;
        _animals = animals;
        _loading = false;
        _selectedLotCode ??= lots.isNotEmpty ? lots.first.code : null;
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
    final filtered = _animals
        .where((animal) => animal.lotCode == _selectedLotCode)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loteamento'),
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
                DropdownButtonFormField<int>(
                  initialValue: _lots.any((lot) => lot.code == _selectedLotCode)
                      ? _selectedLotCode
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lote',
                    prefixIcon: Icon(Icons.grid_view_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _lots
                      .map(
                        (lot) => DropdownMenuItem(
                          value: lot.code,
                          child: Text(lot.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _loading
                      ? null
                      : (value) => setState(() => _selectedLotCode = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Brinco',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
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
          if (_selectedLotCode != null && _lots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${filtered.length} animal(is) no lote'),
              ),
            ),
          Expanded(
            child: _loading && filtered.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? const Center(
                    child: Text('Nenhum animal no lote selecionado.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final animal = filtered[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(animal.daysInMilk.toString()),
                          ),
                          title: Text(
                            'Brinco ${animal.tag}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${animal.reproductiveStatus} · ${animal.productionStatus}\n'
                            'DEL ${animal.daysInMilk} · Última IA ${animal.lastInseminationDate}\n'
                            'Núm.IAs ${animal.inseminationCount} · Prenhez ${animal.pregnancyDays} dias',
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
}
