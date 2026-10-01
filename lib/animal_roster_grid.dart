import 'package:flutter/material.dart';

import 'data/animal_record.dart';
import 'data/number_format.dart';

class AnimalRosterGrid extends StatefulWidget {
  const AnimalRosterGrid({
    required this.animals,
    required this.selectedAnimalCodes,
    required this.onAnimalTap,
    super.key,
  });

  final List<AnimalRecord> animals;
  final Set<int> selectedAnimalCodes;
  final ValueChanged<AnimalRecord> onAnimalTap;

  @override
  State<AnimalRosterGrid> createState() => _AnimalRosterGridState();
}

class _AnimalRosterGridState extends State<AnimalRosterGrid> {
  static const _columnWidths = <double>[88, 118, 118, 86, 76, 180, 82, 120];
  static const _headers = <String>[
    'Brinco',
    'Produção',
    'Reprodução',
    'DP / DUI',
    'DEL',
    'Lote',
    'Núm. IAs',
    'Lactação',
  ];

  double get _tableWidth =>
      _columnWidths.fold<double>(0, (total, width) => total + width) + 4;

  int _sortColumn = 0;
  bool _ascending = true;

  void _sortBy(int column) {
    setState(() {
      if (_sortColumn == column) {
        _ascending = !_ascending;
      } else {
        _sortColumn = column;
        _ascending = true;
      }
    });
  }

  int _compareAnimals(AnimalRecord left, AnimalRecord right) {
    final comparison = switch (_sortColumn) {
      0 => _compareTags(left.tag, right.tag),
      1 => left.productionStatus.compareTo(right.productionStatus),
      2 => left.reproductiveStatus.compareTo(right.reproductiveStatus),
      3 => left.pregnancyDays.compareTo(right.pregnancyDays),
      4 => left.daysInMilk.compareTo(right.daysInMilk),
      5 => left.displayLot.compareTo(right.displayLot),
      6 => left.inseminationCount.compareTo(right.inseminationCount),
      7 => left.lactationCode.compareTo(right.lactationCode),
      _ => 0,
    };
    return _ascending ? comparison : -comparison;
  }

  int _compareTags(String left, String right) {
    final leftNumber = int.tryParse(left);
    final rightNumber = int.tryParse(right);
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }
    return left.compareTo(right);
  }

  List<AnimalRecord> get _aggregateAnimals {
    if (widget.selectedAnimalCodes.isEmpty) return widget.animals;
    return widget.animals
        .where(
          (animal) => widget.selectedAnimalCodes.contains(animal.animalCode),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final aggregate = _aggregateAnimals;
    final sortedAnimals = List<AnimalRecord>.of(widget.animals)
      ..sort(_compareAnimals);
    final averageDel = aggregate.isEmpty
        ? 0.0
        : aggregate.fold<int>(0, (sum, animal) => sum + animal.daysInMilk) /
              aggregate.length;
    final averageText = aggregate.isEmpty
        ? '0,0'
        : formatBrazilianNumber(averageDel);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _tableWidth,
        child: Column(
          children: [
            _buildHeaderRow(context),
            Expanded(
              child: ListView.builder(
                itemCount: sortedAnimals.length,
                itemBuilder: (context, index) {
                  final animal = sortedAnimals[index];
                  final selected = widget.selectedAnimalCodes.contains(
                    animal.animalCode,
                  );
                  return InkWell(
                    onTap: () => widget.onAnimalTap(animal),
                    child: _buildRow(
                      context,
                      [
                        animal.tag,
                        animal.productionStatus,
                        animal.reproductiveStatus,
                        '${animal.pregnancyDays}',
                        '${animal.daysInMilk}',
                        animal.displayLot,
                        '${animal.inseminationCount}',
                        animal.lactationCode,
                      ],
                      selected: selected,
                      selectable: true,
                    ),
                  );
                },
              ),
            ),
            _buildRow(context, [
              '${aggregate.length}',
              '',
              '',
              '',
              averageText,
              '',
              '',
              '',
            ], footer: true),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: Color(0xffe4e9e5),
        border: Border(bottom: BorderSide(color: Color(0xffb9c4bd))),
      ),
      child: Row(
        children: [
          for (var index = 0; index < _headers.length; index++)
            SizedBox(
              width: _columnWidths[index],
              child: InkWell(
                onTap: () => _sortBy(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _headers[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_sortColumn == index)
                        Icon(
                          _ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 13,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<String> values, {
    bool header = false,
    bool footer = false,
    bool selected = false,
    bool selectable = false,
  }) {
    final background = header || footer
        ? const Color(0xffe4e9e5)
        : selected
        ? const Color(0xffe4efff)
        : Colors.white;
    final foreground = header || footer ? Colors.black87 : Colors.black;
    return Container(
      height: header || footer ? 46 : 44,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: const BorderSide(color: Color(0xffb9c4bd)),
          left: BorderSide(
            color: selectable && selected
                ? const Color(0xff245fca)
                : Colors.transparent,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < values.length; index++)
            SizedBox(
              width: _columnWidths[index],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment:
                      index == 0 || index == 3 || index == 4 || index == 6
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: Text(
                    values[index].isEmpty ? '—' : values[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: header ? 13 : 14,
                      fontWeight: header || footer
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
