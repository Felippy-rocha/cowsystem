import 'package:flutter/material.dart';

import 'data/animal_birth_repository.dart' show BirthOption;
import 'data/animal_dry_off_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalDryOffPage extends StatefulWidget {
  const AnimalDryOffPage({super.key});

  @override
  State<AnimalDryOffPage> createState() => _AnimalDryOffPageState();
}

class _AnimalDryOffPageState extends State<AnimalDryOffPage> {
  late final SoapClient _client;
  late final AnimalDryOffRepository _repository;
  final _tagController = TextEditingController();
  List<AnimalDryOffCandidate> _animals = const [];
  List<BirthOption> _lots = const [];
  List<BirthOption> _medications = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalDryOffRepository(soapClient: _client);
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
        _repository.fetchCandidates(tag: _tagController.text),
        _repository.fetchLots(),
        _repository.fetchDryOffMedications(),
      ]);
      if (!mounted) return;
      setState(() {
        _animals = results[0] as List<AnimalDryOffCandidate>;
        _lots = results[1] as List<BirthOption>;
        _medications = results[2] as List<BirthOption>;
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

  Future<void> _openForm(AnimalDryOffCandidate animal) async {
    if (_lots.isEmpty || _medications.isEmpty) {
      _showMessage('Cadastre lot de destino e medicamento para secagem.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _DryOffForm(
        animal: animal,
        lots: _lots,
        medications: _medications,
        onSave: (draft) => _repository.dryOff(
          animalCode: animal.animalCode,
          date: draft.date,
          destinationLotCode: draft.lotCode,
          comment: draft.comment,
          medicationCode: draft.medicationCode,
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
        title: const Text('Registrar secagem'),
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
            child: TextField(
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
            child: _animals.isEmpty && !_loading
                ? const Center(child: Text('Nenhuma vaca em lactação.'))
                : ListView.separated(
                    itemCount: _animals.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _animalTile(_animals[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _animalTile(AnimalDryOffCandidate animal) {
    final overdue = _isPast(animal.predictedDate);
    return ListTile(
      onTap: () => _openForm(animal),
      leading: CircleAvatar(
        backgroundColor: overdue
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.water_drop_outlined,
          color: overdue ? Theme.of(context).colorScheme.error : null,
        ),
      ),
      title: Text(
        animal.tag,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'Previsão de secagem: ${animal.predictedDate.isEmpty ? 'N/D' : animal.predictedDate}'
        '${animal.lastCalving.isEmpty ? '' : ' · Último parto ${animal.lastCalving}'}'
        '${animal.inseminationCount == 0 ? '' : ' · ${animal.inseminationCount} IA'}'
        '${animal.lastInsemination.isEmpty ? '' : ' · Última IA ${animal.lastInsemination}'}'
        '${animal.lot.isEmpty ? '' : ' · Lote ${animal.lot}'}',
        style: TextStyle(
          color: overdue ? Theme.of(context).colorScheme.error : null,
        ),
      ),
      trailing: IconButton(
        tooltip: 'Registrar secagem',
        onPressed: () => _openForm(animal),
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }

  bool _isPast(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
    if (match == null) return false;
    final date = DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
    final today = DateTime.now();
    return date.isBefore(DateTime(today.year, today.month, today.day));
  }
}

class _DryOffDraft {
  const _DryOffDraft({
    required this.date,
    required this.lotCode,
    required this.comment,
    required this.medicationCode,
  });

  final String date;
  final int lotCode;
  final String comment;
  final int medicationCode;
}

class _DryOffForm extends StatefulWidget {
  const _DryOffForm({
    required this.animal,
    required this.lots,
    required this.medications,
    required this.onSave,
  });

  final AnimalDryOffCandidate animal;
  final List<BirthOption> lots;
  final List<BirthOption> medications;
  final Future<void> Function(_DryOffDraft draft) onSave;

  @override
  State<_DryOffForm> createState() => _DryOffFormState();
}

class _DryOffFormState extends State<_DryOffForm> {
  DateTime _date = DateTime.now();
  int? _lotCode;
  int? _medicationCode;
  String _comment = '';
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Secar brinco ${widget.animal.tag}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data da secagem'),
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
          _selectField(
            'Lote de destino',
            _lotCode,
            widget.lots,
            (value) => setState(() => _lotCode = value),
          ),
          const SizedBox(height: 12),
          _selectField(
            'Medicamento de secagem',
            _medicationCode,
            widget.medications,
            (value) => setState(() => _medicationCode = value),
          ),
          const SizedBox(height: 12),
          TextField(
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Comentário',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _comment = value,
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
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Salvando...' : 'Salvar secagem'),
      ),
    ],
  );

  Widget _selectField(
    String label,
    int? value,
    List<BirthOption> options,
    ValueChanged<int?> onChanged,
  ) => DropdownButtonFormField<int>(
    initialValue: options.any((item) => item.code == value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: options
        .map(
          (item) => DropdownMenuItem(value: item.code, child: Text(item.name)),
        )
        .toList(growable: false),
    onChanged: onChanged,
  );

  Future<void> _save() async {
    if (_lotCode == null || _medicationCode == null) {
      setState(() => _error = 'Selecione lote e medicamento.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _DryOffDraft(
          date: _formatDate(_date),
          lotCode: _lotCode!,
          comment: _comment,
          medicationCode: _medicationCode!,
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

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
