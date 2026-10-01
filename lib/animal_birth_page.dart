import 'package:flutter/material.dart';

import 'data/animal_birth_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalBirthPage extends StatefulWidget {
  const AnimalBirthPage({super.key});

  @override
  State<AnimalBirthPage> createState() => _AnimalBirthPageState();
}

class _AnimalBirthPageState extends State<AnimalBirthPage> {
  late final SoapClient _client;
  late final AnimalBirthRepository _repository;
  final _searchController = TextEditingController();
  List<AnimalBirthCandidate> _candidates = const [];
  List<BirthOption> _sexes = const [];
  List<BirthOption> _lots = const [];
  List<BirthOption> _breeds = const [];
  List<BirthOption> _birthTypes = const [];
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
      final results = await Future.wait<dynamic>([
        _repository.fetchCandidates(tag: _searchController.text),
        _repository.fetchSexes(),
        _repository.fetchLots(),
        _repository.fetchBreeds(),
        _repository.fetchBirthTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _candidates = results[0] as List<AnimalBirthCandidate>;
        _sexes = results[1] as List<BirthOption>;
        _lots = results[2] as List<BirthOption>;
        _breeds = results[3] as List<BirthOption>;
        _birthTypes = results[4] as List<BirthOption>;
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

  Future<void> _openCandidate(AnimalBirthCandidate candidate) async {
    if (candidate.animal.reproductiveStatus.toUpperCase() == 'INDUCAO') {
      await _induce(candidate);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _AnimalBirthForm(
        candidate: candidate,
        sexes: _sexes,
        lots: _lots,
        breeds: _breeds,
        birthTypes: _birthTypes,
        onSave: (draft) => _repository.insertBirth(
          date: draft.date,
          motherCode: candidate.animal.animalCode,
          sexCode: draft.sexCode,
          calfTag: draft.calfTag,
          calfLotCode: draft.calfLotCode,
          motherLotCode: draft.motherLotCode,
          breedCode: draft.breedCode,
          calfWeight: draft.calfWeight,
          comment: draft.comment,
          birthTypeCode: draft.birthTypeCode,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _induce(AnimalBirthCandidate candidate) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _InductionForm(
        candidate: candidate,
        lots: _lots,
        onSave: (draft) => _repository.induceLactation(
          animalCode: candidate.animal.animalCode,
          date: draft.date,
          destinationLotCode: draft.lotCode,
          comment: draft.comment,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partos'),
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
              controller: _searchController,
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
            child: _candidates.isEmpty && !_loading
                ? const Center(child: Text('Nenhum animal apto a parir.'))
                : ListView.separated(
                    itemCount: _candidates.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _candidateTile(_candidates[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _candidateTile(AnimalBirthCandidate candidate) {
    final animal = candidate.animal;
    final induction = animal.reproductiveStatus.toUpperCase() == 'INDUCAO';
    return ListTile(
      onTap: () => _openCandidate(candidate),
      leading: CircleAvatar(
        child: Icon(
          induction ? Icons.medical_services_outlined : Icons.child_friendly,
        ),
      ),
      title: Text(
        animal.tag,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${induction ? 'Indução' : 'Prev. parto ${candidate.expectedDate}'}'
        ' · ${animal.reproductiveStatus} · ${animal.productionStatus}'
        '${candidate.lastInsemination.isEmpty ? '' : ' · Última IA ${candidate.lastInsemination}'}'
        '${animal.displayLot.isEmpty ? '' : ' · Lote ${animal.displayLot}'}',
      ),
      trailing: IconButton(
        tooltip: induction ? 'Induzir lactação' : 'Registrar parto',
        onPressed: () => _openCandidate(candidate),
        icon: Icon(induction ? Icons.arrow_forward : Icons.add_circle_outline),
      ),
    );
  }
}

class _BirthDraft {
  const _BirthDraft({
    required this.date,
    required this.sexCode,
    required this.calfTag,
    required this.calfLotCode,
    required this.motherLotCode,
    required this.breedCode,
    required this.calfWeight,
    required this.comment,
    required this.birthTypeCode,
  });

  final String date;
  final int sexCode;
  final String calfTag;
  final int calfLotCode;
  final int motherLotCode;
  final int breedCode;
  final double calfWeight;
  final String comment;
  final int birthTypeCode;
}

class _AnimalBirthForm extends StatefulWidget {
  const _AnimalBirthForm({
    required this.candidate,
    required this.sexes,
    required this.lots,
    required this.breeds,
    required this.birthTypes,
    required this.onSave,
  });

  final AnimalBirthCandidate candidate;
  final List<BirthOption> sexes;
  final List<BirthOption> lots;
  final List<BirthOption> breeds;
  final List<BirthOption> birthTypes;
  final Future<void> Function(_BirthDraft draft) onSave;

  @override
  State<_AnimalBirthForm> createState() => _AnimalBirthFormState();
}

class _AnimalBirthFormState extends State<_AnimalBirthForm> {
  final _tagController = TextEditingController();
  final _weightController = TextEditingController();
  int? _sexCode;
  int? _calfLotCode;
  int? _motherLotCode;
  int? _breedCode;
  int? _birthTypeCode;
  DateTime _date = DateTime.now();
  String _comment = '';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final maternalLot = widget.candidate.animal.lotCode;
    _motherLotCode = widget.lots.any((item) => item.code == maternalLot)
        ? maternalLot
        : null;
    final breedName = widget.candidate.animal.breed.toUpperCase();
    final matchingBreed = widget.breeds.where(
      (item) => item.name.toUpperCase() == breedName,
    );
    _breedCode = matchingBreed.isEmpty ? null : matchingBreed.first.code;
  }

  @override
  void dispose() {
    _tagController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  BirthOption? get _selectedType {
    final matches = widget.birthTypes.where(
      (item) => item.code == _birthTypeCode,
    );
    return matches.isEmpty ? null : matches.first;
  }

  bool get _stillborn => _selectedType?.name.toUpperCase() == 'NATIMORTO';
  bool get _twins => _selectedType?.name.toUpperCase() == 'GEMELAR';

  Future<void> _save({required bool addAnother}) async {
    final type = _selectedType;
    final sexCode = _sexCode;
    final motherLotCode = _motherLotCode;
    if (type == null || sexCode == null || motherLotCode == null) {
      setState(() => _error = 'Informe tipo de parto, sexo e lote da mãe.');
      return;
    }
    final calfTag = _stillborn ? '' : _tagController.text.trim();
    final calfLotCode = _stillborn ? 0 : _calfLotCode;
    final breedCode = _stillborn ? 0 : _breedCode;
    final calfWeight = _stillborn
        ? 0.0
        : double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    if (!_stillborn &&
        (calfTag.isEmpty ||
            calfLotCode == null ||
            breedCode == null ||
            calfWeight == null ||
            calfWeight <= 0)) {
      setState(() => _error = 'Preencha brinco, lote, raça e peso do bezerro.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _BirthDraft(
          date: _formatDate(_date),
          sexCode: sexCode,
          calfTag: calfTag,
          calfLotCode: calfLotCode ?? 0,
          motherLotCode: motherLotCode,
          breedCode: breedCode ?? 0,
          calfWeight: calfWeight ?? 0,
          comment: _comment,
          birthTypeCode: type.code,
        ),
      );
      if (!mounted) return;
      if (addAnother) {
        _tagController.clear();
        _weightController.clear();
        setState(() => _saving = false);
      } else {
        Navigator.pop(context);
      }
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Parto · brinco ${widget.candidate.animal.tag}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data do parto'),
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
              _dropdown(
                label: 'Tipo de parto',
                value: _birthTypeCode,
                options: widget.birthTypes,
                onChanged: (value) => setState(() => _birthTypeCode = value),
              ),
              const SizedBox(height: 12),
              _dropdown(
                label: 'Sexo do bezerro',
                value: _sexCode,
                options: widget.sexes,
                onChanged: (value) => setState(() => _sexCode = value),
              ),
              const SizedBox(height: 12),
              if (!_stillborn) ...[
                TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    labelText: 'Brinco do bezerro',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _dropdown(
                  label: 'Lote do bezerro',
                  value: _calfLotCode,
                  options: widget.lots,
                  onChanged: (value) => setState(() => _calfLotCode = value),
                ),
                const SizedBox(height: 12),
                _dropdown(
                  label: 'Raça do bezerro',
                  value: _breedCode,
                  options: widget.breeds,
                  onChanged: (value) => setState(() => _breedCode = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Peso do bezerro',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _dropdown(
                label: 'Lote da mãe',
                value: _motherLotCode,
                options: widget.lots,
                onChanged: (value) => setState(() => _motherLotCode = value),
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
              if (_error != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (_twins && !_stillborn)
          TextButton(
            onPressed: _saving ? null : () => _save(addAnother: true),
            child: const Text('Salvar e incluir outro'),
          ),
        FilledButton(
          onPressed: _saving ? null : () => _save(addAnother: false),
          child: Text(_saving ? 'Salvando...' : 'Salvar parto'),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required int? value,
    required List<BirthOption> options,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: options.any((item) => item.code == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (item) =>
                DropdownMenuItem(value: item.code, child: Text(item.name)),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _InductionForm extends StatefulWidget {
  const _InductionForm({
    required this.candidate,
    required this.lots,
    required this.onSave,
  });

  final AnimalBirthCandidate candidate;
  final List<BirthOption> lots;
  final Future<void> Function(_InductionDraft draft) onSave;

  @override
  State<_InductionForm> createState() => _InductionFormState();
}

class _InductionFormState extends State<_InductionForm> {
  DateTime _date = DateTime.now();
  int? _lotCode;
  String _comment = '';
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_lotCode == null) {
      setState(() => _error = 'Selecione o lote de destino.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        _InductionDraft(
          date: _formatDate(_date),
          lotCode: _lotCode!,
          comment: _comment,
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
    title: Text('Induzir lactação · ${widget.candidate.animal.tag}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Data'),
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
        DropdownButtonFormField<int>(
          initialValue: widget.lots.any((item) => item.code == _lotCode)
              ? _lotCode
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Lote de destino'),
          items: widget.lots
              .map(
                (item) =>
                    DropdownMenuItem(value: item.code, child: Text(item.name)),
              )
              .toList(growable: false),
          onChanged: (value) => setState(() => _lotCode = value),
        ),
        const SizedBox(height: 12),
        TextField(
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
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Salvando...' : 'Salvar indução'),
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

class _InductionDraft {
  const _InductionDraft({
    required this.date,
    required this.lotCode,
    required this.comment,
  });

  final String date;
  final int lotCode;
  final String comment;
}
