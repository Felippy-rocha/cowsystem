import 'package:flutter/material.dart';

import 'data/calving_forecast_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class CalvingForecastPage extends StatefulWidget {
  const CalvingForecastPage({super.key});

  @override
  State<CalvingForecastPage> createState() => _CalvingForecastPageState();
}

class _CalvingForecastPageState extends State<CalvingForecastPage> {
  late final SoapClient _client;
  late final CalvingForecastRepository _repository;
  List<CalvingForecastSummary> _records = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = CalvingForecastRepository(soapClient: _client);
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
      final records = await _repository.fetchSummary();
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

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repository.generate();
      await _load();
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openDetail(CalvingForecastSummary record) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CalvingForecastDetailPage(
          period: record.period,
          repository: _repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previsão de partos'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Gerar previsão',
            onPressed: _loading ? null : _generate,
            icon: const Icon(Icons.calculate_outlined),
          ),
        ],
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
          if (_records.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${_records.length} período(s)'),
              ),
            ),
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 42),
                        const SizedBox(height: 12),
                        const Text('Nenhuma previsão gerada.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _generate,
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('Gerar previsão'),
                        ),
                      ],
                    ),
                  )
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
                            backgroundColor: colors.primaryContainer,
                            child: Text(record.period.split('/').first),
                          ),
                          title: Text(
                            record.period,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${record.totalCows} vacas · ${record.totalHeifers} novilhas · ${record.total} total\n'
                            'IC ${record.ic} · Leite ${record.milk} kg · VP ${_quantity(record.vp)} · DPR ${_quantity(record.dpr)}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDetail(record),
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

class CalvingForecastDetailPage extends StatefulWidget {
  const CalvingForecastDetailPage({
    required this.period,
    required this.repository,
    super.key,
  });

  final String period;
  final CalvingForecastRepository repository;

  @override
  State<CalvingForecastDetailPage> createState() =>
      _CalvingForecastDetailPageState();
}

class _CalvingForecastDetailPageState extends State<CalvingForecastDetailPage> {
  List<CalvingForecastDetail> _records = const [];
  List<({int code, String name})> _lots = const [];
  final List<String> _categories = const ['NOVILHA', 'PRIMIPARA', 'MULTIPARA'];
  final Set<String> _selectedCategories = {'NOVILHA', 'PRIMIPARA', 'MULTIPARA'};
  int? _lotCode;
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
      final lots = await widget.repository.fetchLots();
      final records = await widget.repository.fetchDetails(
        period: widget.period,
        lotCode: _lotCode,
        categories: _selectedCategories.toList(),
      );
      if (!mounted) return;
      setState(() {
        _lots = lots;
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

  Future<void> _applyFilters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await widget.repository.fetchDetails(
        period: widget.period,
        lotCode: _lotCode,
        categories: _selectedCategories.toList(),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Previsão ${widget.period}'),
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
                  initialValue: _lots.any((lot) => lot.code == _lotCode)
                      ? _lotCode
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lote',
                    prefixIcon: Icon(Icons.grid_view_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Todos os lotes'),
                    ),
                    ..._lots.map(
                      (lot) => DropdownMenuItem(
                        value: lot.code,
                        child: Text(lot.name),
                      ),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _lotCode = value);
                          _applyFilters();
                        },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _categories.map((category) {
                    final selected = _selectedCategories.contains(category);
                    return FilterChip(
                      label: Text(category),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedCategories.add(category);
                          } else {
                            _selectedCategories.remove(category);
                          }
                        });
                        _applyFilters();
                      },
                    );
                  }).toList(),
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
          if (_records.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${_records.length} animal(is)'),
              ),
            ),
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(
                    child: Text('Nenhum animal no período selecionado.'),
                  )
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
                            backgroundColor: colors.secondaryContainer,
                            child: Text(record.tag),
                          ),
                          title: Text(
                            '${record.tag} · ${record.lot}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${record.date} · ${record.category}\n'
                            'Pai: ${record.bull} · IC ${record.ic} · Leite ${record.milk} kg · VP ${record.vp} · DPR ${record.dpr}'
                            '${record.betaCasein.isEmpty ? '' : ' · Beta ${record.betaCasein}'}',
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
