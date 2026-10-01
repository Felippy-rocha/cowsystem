import 'package:flutter/material.dart';

import 'data/animal_comment_repository.dart';
import 'data/animal_record.dart';
import 'data/client_routing.dart';
import 'data/soap_client.dart';

class AnimalCommentsPage extends StatefulWidget {
  const AnimalCommentsPage({
    required this.animal,
    this.openCreateOnLoad = false,
    super.key,
  });

  final AnimalRecord animal;
  final bool openCreateOnLoad;

  @override
  State<AnimalCommentsPage> createState() => _AnimalCommentsPageState();
}

class _AnimalCommentsPageState extends State<AnimalCommentsPage> {
  late final SoapClient _client;
  late final AnimalCommentRepository _repository;
  List<AnimalCommentRecord> _comments = const [];
  List<AnimalCommentType> _types = const [];
  bool _loading = true;
  String? _error;
  bool _openCreateOnLoad = false;

  @override
  void initState() {
    super.initState();
    _openCreateOnLoad = widget.openCreateOnLoad;
    _client = SoapClient(suffix: ClientRoutingSession.suffix);
    _repository = AnimalCommentRepository(soapClient: _client);
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
      final results = await Future.wait([
        _repository.fetchComments(widget.animal.animalCode),
        _repository.fetchTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _comments = results[0] as List<AnimalCommentRecord>;
        _types = results[1] as List<AnimalCommentType>;
        _loading = false;
      });
      if (_openCreateOnLoad) {
        _openCreateOnLoad = false;
        await _editComment();
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

  Future<void> _editComment([AnimalCommentRecord? record]) async {
    if (_types.isEmpty) {
      _showMessage('Cadastre tipos de comentário antes de continuar.');
      return;
    }
    final draft = await showDialog<_AnimalCommentDraft>(
      context: context,
      builder: (context) => _AnimalCommentForm(types: _types, existing: record),
    );
    if (draft == null || !mounted) return;
    try {
      setState(() => _loading = true);
      await _repository.save(
        id: record?.id,
        animalCode: widget.animal.animalCode,
        date: draft.date,
        type: draft.type,
        comment: draft.comment,
      );
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Comentários · ${widget.animal.tag}'),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Incluir comentário',
            onPressed: _loading ? null : () => _editComment(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          : _comments.isEmpty
          ? const Center(child: Text('Nenhum comentário registrado.'))
          : ListView.separated(
              itemCount: _comments.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _commentTile(_comments[index]),
            ),
    );
  }

  Widget _commentTile(AnimalCommentRecord comment) => ListTile(
    onTap: () => _editComment(comment),
    title: Text(
      comment.comment,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Text('${_displayDate(comment.date)} · ${comment.type}'),
    trailing: const Icon(Icons.edit_outlined),
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

class _AnimalCommentDraft {
  const _AnimalCommentDraft({
    required this.date,
    required this.type,
    required this.comment,
  });

  final String date;
  final String type;
  final String comment;
}

class _AnimalCommentForm extends StatefulWidget {
  const _AnimalCommentForm({required this.types, this.existing});

  final List<AnimalCommentType> types;
  final AnimalCommentRecord? existing;

  @override
  State<_AnimalCommentForm> createState() => _AnimalCommentFormState();
}

class _AnimalCommentFormState extends State<_AnimalCommentForm> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  DateTime _date = DateTime.now();
  int? _typeCode;

  @override
  void initState() {
    super.initState();
    final record = widget.existing;
    if (record != null) {
      _commentController.text = record.comment;
      _date = _parseDate(record.date);
      final type = widget.types.where((item) => item.name == record.type);
      _typeCode = type.isEmpty ? null : type.first.code;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'Incluir comentário' : 'Alterar comentário',
    ),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
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
              initialValue: widget.types.any((item) => item.code == _typeCode)
                  ? _typeCode
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tipo de comentário',
                border: OutlineInputBorder(),
              ),
              items: widget.types
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.code,
                      child: Text(item.name),
                    ),
                  )
                  .toList(growable: false),
              validator: (value) => value == null ? 'Selecione o tipo' : null,
              onChanged: (value) => setState(() => _typeCode = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _commentController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Comentário',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Informe o comentário'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          final type = widget.types.firstWhere(
            (item) => item.code == _typeCode,
          );
          Navigator.pop(
            context,
            _AnimalCommentDraft(
              date: _formatDate(_date),
              type: type.name,
              comment: _commentController.text,
            ),
          );
        },
        child: const Text('Salvar'),
      ),
    ],
  );

  DateTime _parseDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
    if (match != null) {
      return DateTime(
        int.parse(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
      );
    }
    return DateTime.now();
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
