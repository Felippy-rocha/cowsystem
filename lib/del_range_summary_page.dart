import 'package:flutter/material.dart';

import 'data/client_routing.dart';
import 'data/del_range_summary_repository.dart';
import 'data/soap_client.dart';

class DelRangeSummaryPage extends StatefulWidget {
  const DelRangeSummaryPage({super.key});

  @override
  State<DelRangeSummaryPage> createState() => _DelRangeSummaryPageState();
}

class _DelRangeSummaryPageState extends State<DelRangeSummaryPage>
    with SingleTickerProviderStateMixin {
  late final SoapClient _client;
  late final DelRangeSummaryRepository _repository;
  late final TabController _tabs;
  List<String> _periods = const [];
  List<String> _years = const [];
  List<DelRangeSummaryRecord> _records = const [];
  String? _period;
  String? _year;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = DelRangeSummaryRepository(soapClient: _client);
    _tabs = TabController(length: 2, vsync: this)..addListener(_tabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_tabChanged)
      ..dispose();
    _client.close();
    super.dispose();
  }

  void _tabChanged() {
    if (_tabs.indexIsChanging || !mounted) return;
    setState(() {});
    _reload();
  }

  void _reload() {
    if (_tabs.index == 0) {
      final period = _period;
      if (period != null) _loadMonthly(period);
    } else {
      final year = _year;
      if (year != null) _loadAnnual(year);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final periods = await _repository.fetchPeriods();
      final years = await _repository.fetchYears();
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _years = years;
        _period = periods.firstOrNull;
        _year = years.firstOrNull;
        _loading = false;
      });
      _reload();
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMonthly(String period) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.fetchMonthly(period);
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

  Future<void> _loadAnnual(String year) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.fetchAnnual(int.tryParse(year) ?? 0);
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
    final total = _records.fold<double>(0, (sum, r) => sum + r.totalMilk);
    final monthly = _tabs.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo por faixa DEL'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Mensal'),
            Tab(text: 'Anual'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: monthly
                ? DropdownButtonFormField<String>(
                    initialValue: _periods.contains(_period) ? _period : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Período',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _periods
                        .map(
                          (period) => DropdownMenuItem(
                            value: period,
                            child: Text(period),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _loading
                        ? null
                        : (value) {
                            setState(() => _period = value);
                            if (value != null) _loadMonthly(value);
                          },
                  )
                : DropdownButtonFormField<String>(
                    initialValue: _years.contains(_year) ? _year : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ano',
                      prefixIcon: Icon(Icons.date_range_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _years
                        .map(
                          (year) =>
                              DropdownMenuItem(value: year, child: Text(year)),
                        )
                        .toList(growable: false),
                    onChanged: _loading
                        ? null
                        : (value) {
                            setState(() => _year = value);
                            if (value != null) _loadAnnual(value);
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
                  '${_records.length} faixa(s) · Total ${_quantity(total)} kg',
                ),
              ),
            ),
          Expanded(
            child: _loading && _records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                ? const Center(child: Text('Nenhum registro encontrado.'))
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
                            'DEL ${record.range}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${_quantity(record.totalMilk)} kg · '
                            '${record.animals} animais\n'
                            'Média ${_quantity(record.average)} kg/animal',
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
