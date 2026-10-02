import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/daily_milk_summary_repository.dart';
import 'data/soap_client.dart';

class DailyMilkSummaryPage extends StatefulWidget {
  const DailyMilkSummaryPage({super.key});

  @override
  State<DailyMilkSummaryPage> createState() => _DailyMilkSummaryPageState();
}

class _DailyMilkSummaryPageState extends State<DailyMilkSummaryPage> {
  late final SoapClient _client;
  late final DailyMilkSummaryRepository _repository;
  List<DailyMilkSummaryRecord> _records = const [];
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = DailyMilkSummaryRepository(soapClient: _client);
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _load();
  }

  String get _dateLabel =>
      '${_date.day.toString().padLeft(2, '0')}/'
      '${_date.month.toString().padLeft(2, '0')}/'
      '${_date.year}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.fetchSummary(_dateLabel);
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
        _searched = true;
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
    final total = _records.fold<double>(0, (sum, r) => sum + r.total);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo leite diário'),
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
            child: InkWell(
              onTap: _loading ? null : _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(_dateLabel),
              ),
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
                child: Text(
                  '${_records.length} animal(is) · Total ${_quantity(total)} kg',
                ),
              ),
            ),
          Expanded(
            child: !_searched
                ? const Center(child: Text('Toque na data para consultar.'))
                : _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(child: Text('Nenhum registro na data.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    itemCount: _records.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(child: Text(record.tag)),
                          title: Text(
                            '${_quantity(record.total)} kg · Lote ${record.lot}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Pesagens ${_quantity(record.weight1)} / '
                            '${_quantity(record.weight2)} / '
                            '${_quantity(record.weight3)} kg\n'
                            'DEL ${record.del} · ${record.lactationCount} '
                            'lactação(ões) · ${record.reproductiveStatus}'
                            '${record.toDiscard == 1 ? ' · A descartar' : ''}',
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
