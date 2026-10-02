import 'package:flutter/material.dart';

import 'data/bst_consumption_estimate_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class BstConsumptionEstimatePage extends StatefulWidget {
  const BstConsumptionEstimatePage({super.key});

  @override
  State<BstConsumptionEstimatePage> createState() =>
      _BstConsumptionEstimatePageState();
}

class _BstConsumptionEstimatePageState
    extends State<BstConsumptionEstimatePage> {
  late final SoapClient _client;
  late final BstConsumptionEstimateRepository _repository;
  List<BstEstimateDel> _dels = const [];
  List<BstConsumptionEstimateRecord> _records = const [];
  int? _del;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = BstConsumptionEstimateRepository(soapClient: _client);
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
      final dels = await _repository.fetchDels();
      if (!mounted) return;
      setState(() {
        _dels = dels;
        _del = dels.firstOrNull?.code;
        _loading = false;
      });
      final del = _del;
      if (del != null) await _loadRecords(del);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRecords(int del) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.fetchEstimate(del);
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
    final totalDoses = _records.fold<int>(0, (sum, r) => sum + r.total);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimativa de consumo de BST'),
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
            child: DropdownButtonFormField<int>(
              initialValue: _dels.any((d) => d.code == _del) ? _del : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'DEL',
                prefixIcon: Icon(Icons.timelapse_outlined),
                border: OutlineInputBorder(),
              ),
              items: _dels
                  .map(
                    (del) => DropdownMenuItem(
                      value: del.code,
                      child: Text(del.description),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _loading
                  ? null
                  : (value) {
                      setState(() => _del = value);
                      if (value != null) _loadRecords(value);
                    },
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
                  '${_records.length} animal(is) · Total $totalDoses dose(s)',
                ),
              ),
            ),
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(child: Text('Nenhum animal na faixa de DEL.'))
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
                            '${record.total} dose(s) · ${record.reproductiveStatus}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'DEL ${record.del} · DP ${record.dp} · '
                            'intervalo ${record.interval} d\n'
                            'Doses prenhes ${record.pregnantDoses} · '
                            'doses DEL ${record.doses} · '
                            'média 14d ${_quantity(record.average)} kg',
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
