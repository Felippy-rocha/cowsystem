import 'package:flutter/material.dart';

import 'data/annual_milk_summary_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnnualMilkSummaryPage extends StatefulWidget {
  const AnnualMilkSummaryPage({super.key});

  @override
  State<AnnualMilkSummaryPage> createState() => _AnnualMilkSummaryPageState();
}

class _AnnualMilkSummaryPageState extends State<AnnualMilkSummaryPage>
    with SingleTickerProviderStateMixin {
  late final SoapClient _client;
  late final AnnualMilkSummaryRepository _repository;
  late final TabController _tabs;
  List<String> _years = const [];
  List<AnnualMilkSummaryRecord> _records = const [];
  List<AnnualMilkComparisonRecord> _comparisons = const [];
  String? _year;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnnualMilkSummaryRepository(soapClient: _client);
    _tabs = TabController(length: 3, vsync: this)..addListener(_tabChanged);
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
    final year = _year;
    if (year != null) _loadRecords(year);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final years = await _repository.fetchYears();
      if (!mounted) return;
      setState(() {
        _years = years;
        _year = years.firstOrNull;
        _loading = false;
      });
      final year = _year;
      if (year != null) await _loadRecords(year);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRecords(String year) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final parsed = int.tryParse(year) ?? 0;
    try {
      if (_tabs.index == 0) {
        final records = await _repository.fetchSummary(parsed);
        if (!mounted) return;
        setState(() {
          _records = records;
          _loading = false;
        });
      } else {
        final comparisons = _tabs.index == 1
            ? await _repository.fetchByLactation(parsed)
            : await _repository.fetchByBreed(parsed);
        if (!mounted) return;
        setState(() {
          _comparisons = comparisons;
          _loading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo leite anual'),
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
            Tab(text: 'Lactações'),
            Tab(text: 'Raça'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: DropdownButtonFormField<String>(
              initialValue: _years.contains(_year) ? _year : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ano',
                prefixIcon: Icon(Icons.calendar_month_outlined),
                border: OutlineInputBorder(),
              ),
              items: _years
                  .map(
                    (year) => DropdownMenuItem(value: year, child: Text(year)),
                  )
                  .toList(growable: false),
              onChanged: _loading
                  ? null
                  : (value) {
                      setState(() => _year = value);
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
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_tabs.index == 0) return _buildMonthly();
    return _buildComparison();
  }

  Widget _buildMonthly() {
    if (_loading && _records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_records.isEmpty) {
      return const Center(child: Text('Nenhum registro no ano selecionado.'));
    }
    final total = _records.fold<double>(0, (sum, r) => sum + r.totalMilk);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_records.length} período(s) · Total ${_quantity(total)} kg',
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            itemCount: _records.length,
            separatorBuilder: (_, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final record = _records[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(
                    record.period,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${_quantity(record.totalMilk)} kg · '
                    '${record.animals} animais\n'
                    'Média ${_quantity(record.average)} kg · DEL ${record.del}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComparison() {
    if (_loading && _comparisons.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_comparisons.isEmpty) {
      return const Center(child: Text('Nenhum registro no ano selecionado.'));
    }
    final byLactation = _tabs.index == 1;
    final year = int.tryParse(_year ?? '') ?? 0;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: _comparisons.length,
      separatorBuilder: (_, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final record = _comparisons[index];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            title: Text(
              byLactation ? '${record.label}ª lactação' : record.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '$year: ${_quantity(record.totalMilk)} kg · '
              'média ${_quantity(record.average)} kg\n'
              '${year - 1}: ${_quantity(record.previousTotalMilk)} kg · '
              'média ${_quantity(record.previousAverage)} kg',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  String _quantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
}
