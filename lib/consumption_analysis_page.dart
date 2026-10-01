import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/consumption_analysis_repository.dart';
import 'data/soap_client.dart';

class ConsumptionAnalysisPage extends StatefulWidget {
  const ConsumptionAnalysisPage({super.key});

  @override
  State<ConsumptionAnalysisPage> createState() =>
      _ConsumptionAnalysisPageState();
}

class _ConsumptionAnalysisPageState extends State<ConsumptionAnalysisPage> {
  late final SoapClient _client;
  late final ConsumptionAnalysisRepository _repository;
  final _periodController = TextEditingController();
  List<({int code, String name})> _diets = const [];
  List<({int code, String name})> _lots = const [];
  List<ConsumptionAnalysisRecord> _records = const [];
  int? _dietCode;
  int? _lotCode;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = ConsumptionAnalysisRepository(soapClient: _client);
    _periodController.text = '05/2026';
    _load();
  }

  @override
  void dispose() {
    _periodController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final diets = await _repository.fetchDiets();
      final lots = await _repository.fetchLots();
      if (!mounted) return;
      setState(() {
        _diets = diets;
        _lots = lots;
        _dietCode = diets.firstOrNull?.code;
        _lotCode = lots.firstOrNull?.code;
        _loading = false;
      });
      final diet = _dietCode;
      final lot = _lotCode;
      if (diet != null && lot != null) {
        await _loadRecords(diet, _periodController.text, lot);
      }
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRecords(int dietCode, String period, int lotCode) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.fetchMonthly(
        dietCode: dietCode,
        period: period,
        lotCode: lotCode,
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

  Future<void> _openDailyDetail(ConsumptionAnalysisRecord record) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ConsumptionDailyDetailPage(
          date: record.date,
          dietCode: record.dietCode,
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
        title: const Text('Análise de consumo'),
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
                  initialValue: _diets.any((diet) => diet.code == _dietCode)
                      ? _dietCode
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Dieta',
                    border: OutlineInputBorder(),
                  ),
                  items: _diets
                      .map(
                        (diet) => DropdownMenuItem(
                          value: diet.code,
                          child: Text(diet.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _dietCode = value);
                          final lot = _lotCode;
                          if (value != null && lot != null) {
                            _loadRecords(value, _periodController.text, lot);
                          }
                        },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _periodController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Período (mm/aaaa)',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    final diet = _dietCode;
                    final lot = _lotCode;
                    if (diet != null && lot != null) {
                      _loadRecords(diet, _periodController.text, lot);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _lots.any((lot) => lot.code == _lotCode)
                      ? _lotCode
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lote',
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
                      : (value) {
                          setState(() => _lotCode = value);
                          final diet = _dietCode;
                          if (value != null && diet != null) {
                            _loadRecords(diet, _periodController.text, value);
                          }
                        },
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
                child: Text('${_records.length} registro(s)'),
              ),
            ),
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(
                    child: Text('Nenhum consumo no período selecionado.'),
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
                          leading: CircleAvatar(child: Text(record.date)),
                          title: Text(
                            record.diet,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${record.consumption.toStringAsFixed(1)} kg consumidos · ${record.animalCount} animais\n'
                            'Diferença ${_quantity(record.consumedQuantity - record.consumption)} kg · MS ${_quantity(record.dryMatter)}%',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openDailyDetail(record),
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

class ConsumptionDailyDetailPage extends StatefulWidget {
  const ConsumptionDailyDetailPage({
    required this.date,
    required this.dietCode,
    required this.repository,
    super.key,
  });

  final String date;
  final int dietCode;
  final ConsumptionAnalysisRepository repository;

  @override
  State<ConsumptionDailyDetailPage> createState() =>
      _ConsumptionDailyDetailPageState();
}

class _ConsumptionDailyDetailPageState
    extends State<ConsumptionDailyDetailPage> {
  List<ConsumptionAnalysisRecord> _records = const [];
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
      final records = await widget.repository.fetchDaily(
        dietCode: widget.dietCode,
        date: widget.date,
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
        title: Text(widget.date),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: TextStyle(color: colors.error)),
            )
          : _records.isEmpty
          ? const Center(child: Text('Nenhum consumo nesta data.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length,
              separatorBuilder: (_, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final record = _records[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(record.diet),
                    subtitle: Text(
                      '${record.consumption.toStringAsFixed(1)} kg · ${record.animalCount} animais',
                    ),
                    trailing: Text(
                      _quantity(record.consumedQuantity - record.consumption),
                    ),
                  ),
                );
              },
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
