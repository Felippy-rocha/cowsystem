import 'package:flutter/material.dart';

import 'data/animal_birth_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalWeaningPage extends StatefulWidget {
  const AnimalWeaningPage({super.key});

  @override
  State<AnimalWeaningPage> createState() => _AnimalWeaningPageState();
}

class _AnimalWeaningPageState extends State<AnimalWeaningPage> {
  late final SoapClient _client;
  late final AnimalBirthRepository _repository;
  final _tagController = TextEditingController();
  List<WeaningCandidate> _calves = const [];
  List<BirthOption> _lots = const [];
  bool _includeWeaned = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalBirthRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _repository.fetchWeaningCandidates(
          tag: _tagController.text,
          includeWeaned: _includeWeaned,
        ),
        _repository.fetchLots(),
      ]);
      if (!mounted) return;
      setState(() {
        _calves = results[0] as List<WeaningCandidate>;
        _lots = results[1] as List<BirthOption>;
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

  Future<void> _openForm(WeaningCandidate calf) async {
    if (_lots.isEmpty) {
      _showMessage('Cadastre um lote de destino antes de desmamar.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _WeaningForm(
        calf: calf,
        lots: _lots,
        onSave: (draft) => _repository.registerWeaning(
          calfCode: calf.animalCode,
          date: draft.date,
          weight: draft.weight,
          destinationLotCode: draft.lotCode,
        ),
      ),
    );
    if (mounted) _load();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desmame'),
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mostrar desmamados'),
                  value: _includeWeaned,
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _includeWeaned = value);
                          _load();
                        },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${_calves.length} bezerras'),
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
            child: _calves.isEmpty && !_loading
                ? const Center(child: Text('Nenhuma bezerra nesta seleção.'))
                : ListView.separated(
                    itemCount: _calves.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) => _calfTile(_calves[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _calfTile(WeaningCandidate calf) => ListTile(
    onTap: calf.weaned ? null : () => _openForm(calf),
    leading: CircleAvatar(
      child: Icon(calf.weaned ? Icons.check : Icons.child_care_outlined),
    ),
    title: Text(calf.tag, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(
      '${calf.daysOld} dias · Nascimento ${_displayDate(calf.birthDate)}'
      '${calf.lot.isEmpty ? '' : ' · Lote ${calf.lot}'}'
      '${calf.weaned ? ' · Desmamada' : ''}',
    ),
    trailing: calf.weaned
        ? null
        : IconButton(
            tooltip: 'Registrar desmame',
            onPressed: () => _openForm(calf),
            icon: const Icon(Icons.event_available_outlined),
          ),
  );

  String _displayDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return '${parsed.day.toString().padLeft(2, '0')}/'
          '${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    }
    return value;
  }
}

class _WeaningDraft {
  const _WeaningDraft({
    required this.date,
    required this.weight,
    required this.lotCode,
  });

  final String date;
  final double weight;
  final int lotCode;
}

class _WeaningForm extends StatefulWidget {
  const _WeaningForm({
    required this.calf,
    required this.lots,
    required this.onSave,
  });

  final WeaningCandidate calf;
  final List<BirthOption> lots;
  final Future<void> Function(_WeaningDraft draft) onSave;

  @override
  State<_WeaningForm> createState() => _WeaningFormState();
}

class _WeaningFormState extends State<_WeaningForm> {
  final _weightController = TextEditingController();
  DateTime _date = DateTime.now();
  int? _lotCode;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lotCode = widget.lots.any((item) => item.name == widget.calf.lot)
        ? widget.lots.firstWhere((item) => item.name == widget.calf.lot).code
        : null;
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final weight = double.tryParse(
      _weightController.text.trim().replaceAll(',', '.'),
    );
    if (weight == null || weight <= 0 || _lotCode == null) {
      setState(() => _error = 'Informe peso e lote de destino.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _WeaningDraft(
          date: _formatDate(_date),
          weight: weight,
          lotCode: _lotCode!,
        ),
      );
      if (mounted) Navigator.pop(context);
    } on SoapException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Desmamar brinco ${widget.calf.tag}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Data do desmame'),
          subtitle: Text(_displayDate(_date)),
          trailing: const Icon(Icons.calendar_month_outlined),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null) setState(() => _date = date);
          },
        ),
        TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Peso ao desmame',
            suffixText: 'kg',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: widget.lots.any((item) => item.code == _lotCode)
              ? _lotCode
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Lote de destino',
            border: OutlineInputBorder(),
          ),
          items: widget.lots
              .map(
                (item) =>
                    DropdownMenuItem(value: item.code, child: Text(item.name)),
              )
              .toList(growable: false),
          onChanged: (value) => setState(() => _lotCode = value),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Salvando...' : 'Salvar desmame'),
      ),
    ],
  );

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
