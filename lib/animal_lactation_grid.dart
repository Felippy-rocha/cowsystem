import 'package:flutter/material.dart';

import 'data/animal_details_repository.dart';
import 'data/number_format.dart';

class AnimalLactationGrid extends StatefulWidget {
  const AnimalLactationGrid({required this.lactations, super.key});

  final List<AnimalClosedLactation> lactations;

  @override
  State<AnimalLactationGrid> createState() => _AnimalLactationGridState();
}

class _AnimalLactationGridState extends State<AnimalLactationGrid> {
  int _sortColumn = 0;
  bool _ascending = true;
  final Set<String> _selectedCodes = {};

  List<AnimalClosedLactation> get _sortedLactations {
    final rows = List<AnimalClosedLactation>.of(widget.lactations);
    rows.sort(_compare);
    return rows;
  }

  List<AnimalClosedLactation> get _aggregateRows {
    if (_selectedCodes.isEmpty) return widget.lactations;
    return widget.lactations
        .where((row) => _selectedCodes.contains(row.code))
        .toList(growable: false);
  }

  void _toggleSelection(String code) {
    setState(() {
      if (!_selectedCodes.add(code)) _selectedCodes.remove(code);
    });
  }

  int _compare(AnimalClosedLactation left, AnimalClosedLactation right) {
    final result = switch (_sortColumn) {
      0 => left.code.compareTo(right.code),
      1 => left.daysInMilk.compareTo(right.daysInMilk),
      2 => left.total305.compareTo(right.total305),
      3 => left.average305.compareTo(right.average305),
      4 => left.totalMilk.compareTo(right.totalMilk),
      _ => 0,
    };
    return _ascending ? result : -result;
  }

  void _sortBy(int column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _ascending = ascending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final aggregate = _aggregateRows;
    final total305 = aggregate.fold<double>(
      0,
      (sum, row) => sum + row.total305,
    );
    final totalMilk = aggregate.fold<double>(
      0,
      (sum, row) => sum + row.totalMilk,
    );
    final average305 = aggregate.isEmpty
        ? 0.0
        : aggregate.fold<double>(0, (sum, row) => sum + row.average305) /
              aggregate.length;
    final sorted = _sortedLactations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedCodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_selectedCodes.length} '
              '${_selectedCodes.length == 1 ? 'lactação selecionada' : 'lactações selecionadas'}',
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            sortColumnIndex: _sortColumn,
            sortAscending: _ascending,
            headingRowHeight: 44,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 48,
            columns: [
              DataColumn(
                label: const Text('Lactação'),
                onSort: (index, ascending) => _sortBy(index, ascending),
              ),
              DataColumn(
                numeric: true,
                label: const Text('DEL'),
                onSort: (index, ascending) => _sortBy(index, ascending),
              ),
              DataColumn(
                numeric: true,
                label: const Text('Total 305'),
                onSort: (index, ascending) => _sortBy(index, ascending),
              ),
              DataColumn(
                numeric: true,
                label: const Text('Média 305'),
                onSort: (index, ascending) => _sortBy(index, ascending),
              ),
              DataColumn(
                numeric: true,
                label: const Text('Total geral'),
                onSort: (index, ascending) => _sortBy(index, ascending),
              ),
            ],
            rows: [
              for (final lactation in sorted)
                DataRow(
                  selected: _selectedCodes.contains(lactation.code),
                  color: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  cells: [
                    DataCell(
                      Text(lactation.code),
                      onTap: () => _toggleSelection(lactation.code),
                    ),
                    DataCell(
                      Text('${lactation.daysInMilk}'),
                      onTap: () => _toggleSelection(lactation.code),
                    ),
                    DataCell(
                      Text(formatBrazilianNumber(lactation.total305)),
                      onTap: () => _toggleSelection(lactation.code),
                    ),
                    DataCell(
                      Text(formatBrazilianNumber(lactation.average305)),
                      onTap: () => _toggleSelection(lactation.code),
                    ),
                    DataCell(
                      Text(formatBrazilianNumber(lactation.totalMilk)),
                      onTap: () => _toggleSelection(lactation.code),
                    ),
                  ],
                ),
              DataRow(
                color: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                cells: [
                  DataCell(Text('${aggregate.length} total')),
                  const DataCell(Text('')),
                  DataCell(Text(formatBrazilianNumber(total305))),
                  DataCell(Text(formatBrazilianNumber(average305))),
                  DataCell(Text(formatBrazilianNumber(totalMilk))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
