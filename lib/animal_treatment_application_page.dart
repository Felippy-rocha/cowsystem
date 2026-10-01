import 'package:flutter/material.dart';

import 'data/animal_record.dart';
import 'data/animal_treatment_repository.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalTreatmentApplicationPage extends StatefulWidget {
  const AnimalTreatmentApplicationPage({this.selectedAnimal, super.key});

  final AnimalRecord? selectedAnimal;

  @override
  State<AnimalTreatmentApplicationPage> createState() =>
      _AnimalTreatmentApplicationPageState();
}

class _AnimalTreatmentApplicationPageState
    extends State<AnimalTreatmentApplicationPage> {
  late final SoapClient _client;
  late final AnimalTreatmentRepository _repository;
  final _tagController = TextEditingController();
  List<TreatmentOption> _treatments = const [];
  AnimalRecord? _animal;
  DateTime _date = DateTime.now();
  TimeOfDay? _time;
  int? _treatmentCode;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animal = widget.selectedAnimal;
    if (_animal != null) _tagController.text = _animal!.tag;
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalTreatmentRepository(soapClient: _client);
    _load();
  }

  @override
  void dispose() {
    _tagController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final treatments = await _repository.fetchTreatments();
      if (!mounted) return;
      setState(() {
        _treatments = treatments;
        _treatmentCode = treatments.isEmpty ? null : treatments.first.code;
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

  Future<void> _findAnimal() async {
    final tag = _tagController.text.trim();
    if (tag.isEmpty) return;
    try {
      final animal = await _repository.findAnimal(tag);
      if (!mounted) return;
      setState(() {
        _animal = animal;
        _error = animal == null ? 'Brinco não encontrado.' : null;
      });
    } on SoapException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected != null) setState(() => _time = selected);
  }

  Future<void> _save() async {
    final animal = _animal;
    final time = _time;
    if (animal == null || _treatmentCode == null || time == null) {
      setState(() => _error = 'Informe brinco, tratamento, data e horário.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.createApplicationTask(
        date: _formatDate(_date),
        time:
            '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}',
        treatmentCode: _treatmentCode!,
        animalCode: animal.animalCode,
      );
      if (!mounted) return;
      _showMessage('Tratamento programado para ${animal.tag}.');
      if (widget.selectedAnimal == null) {
        setState(() {
          _animal = null;
          _tagController.clear();
          _time = null;
          _saving = false;
        });
      } else {
        Navigator.of(context).pop(true);
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aplicar tratamento'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        readOnly: widget.selectedAnimal != null,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Brinco',
                          prefixIcon: Icon(Icons.pets_outlined),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _findAnimal(),
                      ),
                    ),
                    if (widget.selectedAnimal == null)
                      IconButton(
                        tooltip: 'Buscar animal',
                        onPressed: _findAnimal,
                        icon: const Icon(Icons.search),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data da tarefa'),
                  subtitle: Text(_displayDate(_date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _chooseDate,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Horário'),
                  subtitle: Text(
                    _time == null
                        ? 'Selecionar horário'
                        : '${_time!.hour.toString().padLeft(2, '0')}:'
                              '${_time!.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.schedule_outlined),
                  onTap: _chooseTime,
                ),
                DropdownButtonFormField<int>(
                  initialValue:
                      _treatments.any((item) => item.code == _treatmentCode)
                      ? _treatmentCode
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tratamento',
                    border: OutlineInputBorder(),
                  ),
                  items: _treatments
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.code,
                          child: Text(item.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _treatmentCode = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: TextStyle(color: colors.error)),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Salvando...' : 'Programar tratamento'),
                ),
              ],
            ),
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
