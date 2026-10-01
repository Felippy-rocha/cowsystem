import 'package:flutter/material.dart';

import 'data/animal_cycles_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalCyclesPage extends StatefulWidget {
  const AnimalCyclesPage({super.key});

  @override
  State<AnimalCyclesPage> createState() => _AnimalCyclesPageState();
}

class _AnimalCyclesPageState extends State<AnimalCyclesPage> {
  late final SoapClient _client;
  late final AnimalCyclesRepository _repository;
  List<String> _years = const [];
  List<ReproductiveCycle> _cycles = const [];
  String? _year;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalCyclesRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final years = await _repository.fetchYears();
      final currentYear = DateTime.now().year.toString();
      final selectedYear = years.contains(_year)
          ? _year
          : years.contains(currentYear)
          ? currentYear
          : years.firstOrNull;
      final cycles = await _repository.fetchCycles(year: selectedYear ?? '');
      if (!mounted) return;
      setState(() {
        _years = years;
        _year = selectedYear;
        _cycles = cycles;
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

  Future<void> _loadYear(String? year) async {
    setState(() {
      _year = year;
      _loading = true;
      _error = null;
    });
    try {
      final cycles = await _repository.fetchCycles(year: year ?? '');
      if (!mounted) return;
      setState(() {
        _cycles = cycles;
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

  Future<void> _recalculate(ReproductiveCycle cycle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recalcular ciclo?'),
        content: Text(
          'As taxas reprodutivas do ciclo ${cycle.name} serão atualizadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recalcular'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.recalculate(cycle.code);
      await _load();
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _openCycle(ReproductiveCycle cycle) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CycleDetailsPage(cycle: cycle, repository: _repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taxa de serviço'),
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
            child: DropdownButtonFormField<String?>(
              initialValue: _year,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ano do ciclo',
                prefixIcon: Icon(Icons.calendar_month_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todos os anos'),
                ),
                ..._years.map(
                  (year) =>
                      DropdownMenuItem<String?>(value: year, child: Text(year)),
                ),
              ],
              onChanged: _loading ? null : _loadYear,
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
          if (_cycles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${_cycles.length} ciclo(s)'),
              ),
            ),
          Expanded(
            child: _loading && _cycles.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _cycles.isEmpty
                ? const Center(child: Text('Nenhum ciclo encontrado.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: _cycles.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final cycle = _cycles[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          onTap: () => _openCycle(cycle),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cycle.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Recalcular taxas',
                                      onPressed: _loading
                                          ? null
                                          : () => _recalculate(cycle),
                                      icon: const Icon(
                                        Icons.calculate_outlined,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                                Text('${cycle.startDate} a ${cycle.endDate}'),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _CycleMetric(
                                      label: 'Serviço',
                                      value: _percent(cycle.serviceRate),
                                    ),
                                    _CycleMetric(
                                      label: 'Concepção',
                                      value: _percent(cycle.conceptionRate),
                                    ),
                                    _CycleMetric(
                                      label: 'Prenhez',
                                      value: _percent(cycle.pregnancyRate),
                                    ),
                                    _CycleMetric(
                                      label: 'Perda',
                                      value: _percent(cycle.pregnancyLoss),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${cycle.totalCount} animais · ${cycle.servedCount} servidas · '
                                  '${cycle.withoutDiagnosis} sem diagnóstico · ${cycle.pregnantCount} prenhas',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
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

class CycleDetailsPage extends StatefulWidget {
  const CycleDetailsPage({
    required this.cycle,
    required this.repository,
    super.key,
  });

  final ReproductiveCycle cycle;
  final AnimalCyclesRepository repository;

  @override
  State<CycleDetailsPage> createState() => _CycleDetailsPageState();
}

class _CycleDetailsPageState extends State<CycleDetailsPage> {
  List<CycleAnimalRecord> _animals = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final animals = await widget.repository.fetchCycleAnimals(
        widget.cycle.code,
      );
      if (!mounted) return;
      setState(() {
        _animals = animals;
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Ciclo ${widget.cycle.name}'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar animais',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${_animals.length} animal(is) no ciclo'),
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
            child: _loading && _animals.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _animals.isEmpty
                ? const Center(
                    child: Text('Nenhum animal encontrado neste ciclo.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: _animals.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final animal = _animals[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: animal.pregnancyLossDate.isEmpty
                                ? colors.secondaryContainer
                                : colors.errorContainer,
                            child: Icon(
                              animal.pregnancyLossDate.isEmpty
                                  ? Icons.pets_outlined
                                  : Icons.warning_amber_outlined,
                            ),
                          ),
                          title: Text(
                            'Brinco ${animal.tag}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Entrada ${animal.entryDate} · ${animal.serviceCount} serviço(s) · ${animal.lactations} lactação(ões)\n'
                            'Última servida: ${animal.servedDate.isEmpty ? 'não informada' : animal.servedDate}'
                            '${animal.inseminationStatus.isEmpty ? '' : ' · ${animal.inseminationStatus}'}'
                            '${animal.pregnancyLossDate.isEmpty ? '' : '\nPerda de prenhez: ${animal.pregnancyLossDate}'}',
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

class _CycleMetric extends StatelessWidget {
  const _CycleMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => InputChip(
    label: Text('$label  $value'),
    onPressed: null,
    visualDensity: VisualDensity.compact,
  );
}

String _percent(double value) => '${value.toStringAsFixed(1)}%';
