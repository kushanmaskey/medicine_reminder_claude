import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/vital.dart';
import '../services/storage_service.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum _Metric { bp, pulse, sugar, weight, cholesterol, insulin }
enum _Range { daily, weekly, monthly, yearly, custom }

// ── Chart data point ──────────────────────────────────────────────────────────

class _ChartPoint {
  final double x;
  final double y;   // systolic for BP, otherwise the single value
  final double? y2; // diastolic for BP only
  final DateTime date;
  final String note;
  final bool isPrevious; // DD mode: marks the pre-today comparison point
  const _ChartPoint({
    required this.x,
    required this.y,
    this.y2,
    required this.date,
    this.note = '',
    this.isPrevious = false,
  });
}

// ── Main widget ───────────────────────────────────────────────────────────────

class TrendsTab extends StatefulWidget {
  const TrendsTab({super.key});

  @override
  State<TrendsTab> createState() => TrendsTabState();
}

class TrendsTabState extends State<TrendsTab> {
  _Metric _metric = _Metric.bp;
  _Range _range = _Range.daily;
  List<Vital> _vitals = [];
  bool _loading = true;
  int? _touchedIndex;

  DateTime _customStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _customEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void reload() => _load();

  Future<void> _load() async {
    final list = await StorageService.getVitals();
    final daily = list.where((v) => v.category == 'daily').toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    if (mounted) setState(() { _vitals = daily; _loading = false; });
  }

  // ── Metric helpers ──────────────────────────────────────────────────────────

  Color get _metricColor {
    switch (_metric) {
      case _Metric.bp:          return const Color(0xFFEF4444);
      case _Metric.pulse:       return const Color(0xFFEC4899);
      case _Metric.sugar:       return const Color(0xFFF97316);
      case _Metric.weight:      return const Color(0xFF3B82F6);
      case _Metric.cholesterol: return const Color(0xFF8B5CF6);
      case _Metric.insulin:     return const Color(0xFF06B6D4);
    }
  }

  String get _unit {
    switch (_metric) {
      case _Metric.bp:    return 'mmHg';
      case _Metric.pulse: return 'bpm';
      case _Metric.sugar:
        for (final v in _vitals) { if (v.sugarReadings.isNotEmpty) return v.sugarUnit; }
        return 'mg/dL';
      case _Metric.weight:
        for (final v in _vitals) { if (v.weightReadings.isNotEmpty) return v.weightUnit; }
        return 'lbs';
      case _Metric.cholesterol:
        for (final v in _vitals) { if (v.cholesterolReadings.isNotEmpty) return v.cholesterolUnit; }
        return 'mg/dL';
      case _Metric.insulin: return 'units';
    }
  }

  // ── Value extraction ────────────────────────────────────────────────────────

  double? _extractY(Vital v) {
    switch (_metric) {
      case _Metric.bp:
        if (v.bpReadings.isEmpty) return null;
        return v.bpReadings.fold<double>(0, (s, r) => s + r.systolic) / v.bpReadings.length;
      case _Metric.pulse:
        if (v.pulseReadings.isEmpty) return null;
        return v.pulseReadings.fold<double>(0, (s, r) => s + r.value) / v.pulseReadings.length;
      case _Metric.sugar:
        if (v.sugarReadings.isEmpty) return null;
        return v.sugarReadings.fold<double>(0, (s, r) => s + r.value) / v.sugarReadings.length;
      case _Metric.weight:
        if (v.weightReadings.isEmpty) return null;
        return v.weightReadings.fold<double>(0, (s, r) => s + r.value) / v.weightReadings.length;
      case _Metric.cholesterol:
        if (v.cholesterolReadings.isEmpty) return null;
        return v.cholesterolReadings.fold<double>(0, (s, r) => s + r.value) / v.cholesterolReadings.length;
      case _Metric.insulin:
        if (v.insulinReadings.isEmpty) return null;
        return v.insulinReadings.fold<double>(0, (s, r) => s + r.value) / v.insulinReadings.length;
    }
  }

  double? _extractY2(Vital v) {
    if (_metric != _Metric.bp || v.bpReadings.isEmpty) return null;
    return v.bpReadings.fold<double>(0, (s, r) => s + r.diastolic) / v.bpReadings.length;
  }

  // ── Data building ───────────────────────────────────────────────────────────

  ({List<_ChartPoint> points, List<String> xLabels}) _buildData() {
    switch (_range) {
      case _Range.daily:   return _buildDailyData();
      case _Range.weekly:  return _buildWeeklyData();
      case _Range.monthly: return _buildMonthlyData();
      case _Range.yearly:  return _buildYearlyData();
      case _Range.custom:  return _buildCustomData();
    }
  }

  // DD: the most recent record before today + all of today's readings
  ({List<_ChartPoint> points, List<String> xLabels}) _buildDailyData() {
    final now = DateTime.now().toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);

    final todayVitals = _vitals
        .where((v) => !v.recordedAt.toLocal().isBefore(todayStart))
        .toList();
    final beforeToday = _vitals
        .where((v) => v.recordedAt.toLocal().isBefore(todayStart))
        .toList();

    // Last record before today
    final previousRecord = beforeToday.isNotEmpty ? beforeToday.last : null;

    final points = <_ChartPoint>[];
    final labels = <String>[];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    if (previousRecord != null) {
      final y = _extractY(previousRecord);
      if (y != null) {
        final dt = previousRecord.recordedAt.toLocal();
        points.add(_ChartPoint(
          x: 0,
          y: y,
          y2: _extractY2(previousRecord),
          date: previousRecord.recordedAt,
          note: previousRecord.notes,
          isPrevious: true,
        ));
        labels.add('${months[dt.month - 1]} ${dt.day}');
      }
    }

    for (final v in todayVitals) {
      final y = _extractY(v);
      if (y == null) continue;
      final dt = v.recordedAt.toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      points.add(_ChartPoint(
        x: points.length.toDouble(),
        y: y,
        y2: _extractY2(v),
        date: v.recordedAt,
        note: v.notes,
      ));
      labels.add('$h:$min');
    }

    return (points: points, xLabels: labels);
  }

  // Weekly: last 7 days including today, grouped by day
  ({List<_ChartPoint> points, List<String> xLabels}) _buildWeeklyData() {
    final now = DateTime.now().toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));

    return _groupByDay(
      _vitals.where((v) => !v.recordedAt.toLocal().isBefore(weekStart)).toList(),
    );
  }

  // Monthly: last 30 days including today, grouped by day
  ({List<_ChartPoint> points, List<String> xLabels}) _buildMonthlyData() {
    final now = DateTime.now().toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = todayStart.subtract(const Duration(days: 29));

    return _groupByDay(
      _vitals.where((v) => !v.recordedAt.toLocal().isBefore(monthStart)).toList(),
    );
  }

  // Yearly: current calendar year, grouped by month
  ({List<_ChartPoint> points, List<String> xLabels}) _buildYearlyData() {
    final now = DateTime.now().toLocal();
    final yearStart = DateTime(now.year, 1, 1);

    final yearVitals = _vitals
        .where((v) => !v.recordedAt.toLocal().isBefore(yearStart))
        .toList();

    final monthMap = <String, List<Vital>>{};
    for (final v in yearVitals) {
      final dt = v.recordedAt.toLocal();
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      monthMap.putIfAbsent(key, () => []).add(v);
    }

    final sortedKeys = monthMap.keys.toList()..sort();
    final points = <_ChartPoint>[];
    final labels = <String>[];
    const monthNames = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    for (final key in sortedKeys) {
      final group = monthMap[key]!;
      final ys = group.map(_extractY).whereType<double>().toList();
      if (ys.isEmpty) continue;
      final avgY = ys.reduce((a, b) => a + b) / ys.length;
      double? avgY2;
      if (_metric == _Metric.bp) {
        final y2s = group.map(_extractY2).whereType<double>().toList();
        if (y2s.isNotEmpty) avgY2 = y2s.reduce((a, b) => a + b) / y2s.length;
      }
      final note = group.map((v) => v.notes.trim()).where((n) => n.isNotEmpty).toSet().join(', ');
      final parts = key.split('-');
      final mo = int.parse(parts[1]);
      final date = DateTime(int.parse(parts[0]), mo, 1);
      points.add(_ChartPoint(x: points.length.toDouble(), y: avgY, y2: avgY2, date: date, note: note));
      labels.add(monthNames[mo - 1]);
    }
    return (points: points, xLabels: labels);
  }

  // Shared helper: group vitals list into one averaged point per day
  ({List<_ChartPoint> points, List<String> xLabels}) _groupByDay(List<Vital> vitals) {
    final dayMap = <String, List<Vital>>{};
    for (final v in vitals) {
      final dt = v.recordedAt.toLocal();
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      dayMap.putIfAbsent(key, () => []).add(v);
    }
    final sortedKeys = dayMap.keys.toList()..sort();
    final points = <_ChartPoint>[];
    final labels = <String>[];
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    for (final key in sortedKeys) {
      final group = dayMap[key]!;
      final ys = group.map(_extractY).whereType<double>().toList();
      if (ys.isEmpty) continue;
      final avgY = ys.reduce((a, b) => a + b) / ys.length;
      double? avgY2;
      if (_metric == _Metric.bp) {
        final y2s = group.map(_extractY2).whereType<double>().toList();
        if (y2s.isNotEmpty) avgY2 = y2s.reduce((a, b) => a + b) / y2s.length;
      }
      final note = group.map((v) => v.notes.trim()).where((n) => n.isNotEmpty).toSet().join(', ');
      final date = DateTime.parse(key);
      points.add(_ChartPoint(x: points.length.toDouble(), y: avgY, y2: avgY2, date: date, note: note));
      labels.add('${months[date.month - 1]} ${date.day}');
    }
    return (points: points, xLabels: labels);
  }

  ({List<_ChartPoint> points, List<String> xLabels}) _buildCustomData() {
    final start = DateTime(_customStart.year, _customStart.month, _customStart.day);
    final end = DateTime(_customEnd.year, _customEnd.month, _customEnd.day).add(const Duration(days: 1));
    return _groupByDay(_vitals.where((v) {
      final dt = v.recordedAt.toLocal();
      return !dt.isBefore(start) && dt.isBefore(end);
    }).toList());
  }

  // ── Date pickers ────────────────────────────────────────────────────────────

  Future<void> _pickCustomStart() async {
    final earliestAllowed = _customEnd.subtract(const Duration(days: 365));
    final firstDate = earliestAllowed.isAfter(DateTime.now().subtract(const Duration(days: 365 * 2)))
        ? earliestAllowed
        : DateTime.now().subtract(const Duration(days: 365 * 2));
    DateTime? picked;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CalendarDatePicker(
            initialDate: _customStart.isBefore(firstDate) ? firstDate : _customStart,
            firstDate: firstDate,
            lastDate: _customEnd,
            onDateChanged: (d) { picked = d; Navigator.pop(ctx); },
          ),
        ),
      ),
    );
    if (picked != null) setState(() { _customStart = picked!; _touchedIndex = null; });
  }

  Future<void> _pickCustomEnd() async {
    final latestAllowed = _customStart.add(const Duration(days: 365));
    final lastDate = latestAllowed.isBefore(DateTime.now()) ? latestAllowed : DateTime.now();
    DateTime? picked;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CalendarDatePicker(
            initialDate: _customEnd.isAfter(lastDate) ? lastDate : _customEnd,
            firstDate: _customStart,
            lastDate: lastDate,
            onDateChanged: (d) { picked = d; Navigator.pop(ctx); },
          ),
        ),
      ),
    );
    if (picked != null) setState(() { _customEnd = picked!; _touchedIndex = null; });
  }

  // ── Formatting helpers ──────────────────────────────────────────────────────

  String _fmtDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  String _fmtVal(double v, double? v2) {
    final unit = _unit;
    if (_metric == _Metric.bp && v2 != null) return '${v.toInt()}/${v2.toInt()} $unit';
    if (_metric == _Metric.pulse) return '${v.toInt()} $unit';
    return '${v.toStringAsFixed(1)} $unit';
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)));
    }

    final (:points, :xLabels) = _buildData();

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFFFF6B6B),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildMetricSelector(),
          const SizedBox(height: 12),
          _buildRangeSelector(),
          if (_range == _Range.custom) ...[
            const SizedBox(height: 10),
            _buildCustomHeader(),
          ],
          const SizedBox(height: 16),
          _buildChart(points, xLabels),
          const SizedBox(height: 16),
          _buildStats(points),
        ],
      ),
    );
  }

  Widget _buildMetricSelector() {
    const items = [
      (_Metric.bp,          'Blood Pressure', Color(0xFFEF4444)),
      (_Metric.pulse,       'Pulse',          Color(0xFFEC4899)),
      (_Metric.sugar,       'Blood Sugar',    Color(0xFFF97316)),
      (_Metric.weight,      'Weight',         Color(0xFF3B82F6)),
      (_Metric.cholesterol, 'Cholesterol',    Color(0xFF8B5CF6)),
      (_Metric.insulin,     'Insulin',        Color(0xFF06B6D4)),
    ];
    final currentLabel = items.firstWhere((i) => i.$1 == _metric).$2;
    final color = _metricColor;

    return PopupMenuButton<_Metric>(
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      onSelected: (m) => setState(() { _metric = m; _touchedIndex = null; }),
      itemBuilder: (ctx) => items.map((item) {
        final (m, label, c) = item;
        final selected = _metric == m;
        return PopupMenuItem<_Metric>(
          value: m,
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              if (selected) ...[const Spacer(), Icon(Icons.check, size: 14, color: c)],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu, size: 16, color: color),
            const SizedBox(width: 8),
            Text(currentLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSelector() {
    const items = [
      (_Range.daily,   'DD'),
      (_Range.weekly,  'Weekly'),
      (_Range.monthly, 'Monthly'),
      (_Range.yearly,  'Yearly'),
      (_Range.custom,  'Custom'),
    ];
    final color = _metricColor;
    return Row(
      children: items.asMap().entries.map((entry) {
        final (r, label) = entry.value;
        final isLast = entry.key == items.length - 1;
        final selected = _range == r;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 4),
            child: GestureDetector(
              onTap: () => setState(() { _range = r; _touchedIndex = null; }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? color : Colors.grey.shade200),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomHeader() {
    final color = _metricColor;
    return Row(
      children: [
        Expanded(child: _DateChip(label: _fmtDate(_customStart), onTap: _pickCustomStart, color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('to', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ),
        Expanded(child: _DateChip(label: _fmtDate(_customEnd), onTap: _pickCustomEnd, color: color)),
      ],
    );
  }

  Widget _buildChart(List<_ChartPoint> points, List<String> xLabels) {
    if (points.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No data for this period', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }

    final color = _metricColor;
    final n = points.length;
    final interval = n <= 7 ? 1.0 : n <= 15 ? 2.0 : n <= 30 ? 5.0 : 7.0;

    final allYs = [
      ...points.map((p) => p.y),
      ...points.where((p) => p.y2 != null).map((p) => p.y2!),
    ];
    final rawMin = allYs.reduce(math.min);
    final rawMax = allYs.reduce(math.max);
    final pad = math.max((rawMax - rawMin) * 0.15, 5.0);
    final chartMinY = (rawMin - pad).floorToDouble();
    final chartMaxY = (rawMax + pad).ceilToDouble();

    final bars = <LineChartBarData>[
      LineChartBarData(
        spots: points.map((p) => FlSpot(p.x, p.y)).toList(),
        isCurved: n > 3,
        color: color,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, bar, index) {
            final touched = index == _touchedIndex;
            final isPrev = index < points.length && points[index].isPrevious;
            return FlDotCirclePainter(
              radius: touched ? 5.5 : 3.5,
              color: isPrev
                  ? Colors.grey.shade400.withValues(alpha: touched ? 1.0 : 0.85)
                  : color.withValues(alpha: touched ? 1.0 : 0.85),
              strokeWidth: touched ? 2 : 1.5,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.06)),
      ),
      if (_metric == _Metric.bp && points.any((p) => p.y2 != null))
        LineChartBarData(
          spots: points.where((p) => p.y2 != null).map((p) => FlSpot(p.x, p.y2!)).toList(),
          isCurved: n > 3,
          color: const Color(0xFFF97316),
          barWidth: 2,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, bar, index) {
              final touched = index == _touchedIndex;
              return FlDotCirclePainter(
                radius: touched ? 5.5 : 3.5,
                color: const Color(0xFFF97316).withValues(alpha: touched ? 1.0 : 0.85),
                strokeWidth: touched ? 2 : 1.5,
                strokeColor: Colors.white,
              );
            },
          ),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(4, 20, 20, 8),
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minX: -0.5,
            maxX: points.last.x + 0.5,
            minY: chartMinY,
            maxY: chartMaxY,
            lineBarsData: bars,
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchCallback: (event, response) {
                if (response?.lineBarSpots?.isNotEmpty ?? false) {
                  setState(() => _touchedIndex = response!.lineBarSpots![0].spotIndex);
                }
              },
              getTouchedSpotIndicator: (barData, spotIndexes) {
                return spotIndexes.map((i) => TouchedSpotIndicatorData(
                  FlLine(color: color.withValues(alpha: 0.25), strokeWidth: 1, dashArray: [4, 3]),
                  FlDotData(show: false),
                )).toList();
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.white,
                tooltipBorder: BorderSide(color: color.withValues(alpha: 0.25)),
                tooltipRoundedRadius: 8,
                tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                getTooltipItems: (spots) {
                  return spots.map((spot) {
                    if (_metric == _Metric.bp) {
                      if (spot.barIndex == 0) {
                        final diastolicSpot = spots.where((s) => s.barIndex == 1).firstOrNull;
                        final label = diastolicSpot != null
                            ? '${spot.y.toInt()}/${diastolicSpot.y.toInt()} $_unit'
                            : '${spot.y.toInt()} $_unit';
                        return LineTooltipItem(
                          label,
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                        );
                      }
                      return null;
                    }
                    final label = _metric == _Metric.pulse
                        ? '${spot.y.toInt()} $_unit'
                        : '${spot.y.toStringAsFixed(1)} $_unit';
                    return LineTooltipItem(
                      label,
                      TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
                left: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (value, meta) {
                    if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  interval: interval,
                  getTitlesWidget: (value, meta) {
                    final idx = value.round();
                    if (idx < 0 || idx >= xLabels.length) return const SizedBox.shrink();
                    if ((value - idx.toDouble()).abs() > 0.01) return const SizedBox.shrink();
                    if (idx % interval.toInt() != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Transform.rotate(
                        angle: -0.5,
                        child: Text(
                          xLabels[idx],
                          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats(List<_ChartPoint> points) {
    if (points.isEmpty) return const SizedBox.shrink();

    if (_range == _Range.daily) return _buildDailyStats(points);

    final color = _metricColor;
    final ys = points.map((p) => p.y).toList();
    final avgY = ys.reduce((a, b) => a + b) / ys.length;
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);

    final isBP = _metric == _Metric.bp;
    final y2s = isBP ? points.where((p) => p.y2 != null).map((p) => p.y2!).toList() : <double>[];
    final avgY2 = y2s.isNotEmpty ? y2s.reduce((a, b) => a + b) / y2s.length : null;
    final minY2 = y2s.isNotEmpty ? y2s.reduce(math.min) : null;
    final maxY2 = y2s.isNotEmpty ? y2s.reduce(math.max) : null;

    final touched = (_touchedIndex != null && _touchedIndex! < points.length)
        ? points[_touchedIndex!]
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (touched != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    'Selected: ${_fmtDate(touched.date.toLocal())}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                  ),
                  const Spacer(),
                  Text(
                    _fmtVal(touched.y, touched.y2),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _StatRow('Average', _fmtVal(avgY, avgY2), color),
                const SizedBox(height: 8),
                _StatRow('Min', _fmtVal(minY, minY2), color),
                const SizedBox(height: 8),
                _StatRow('Max', _fmtVal(maxY, maxY2), color),
                const SizedBox(height: 8),
                _StatRow('Readings', '${points.length}', color),
                if (touched != null) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text('Notes', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        child: Text(
                          touched.note.isNotEmpty ? touched.note : '—',
                          style: TextStyle(
                            fontSize: 13,
                            color: touched.note.isNotEmpty ? Colors.grey[700] : Colors.grey[400],
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Stats panel specific to DD mode: shows previous vs today + delta
  Widget _buildDailyStats(List<_ChartPoint> points) {
    final color = _metricColor;
    final prev = points.where((p) => p.isPrevious).firstOrNull;
    final todayPoints = points.where((p) => !p.isPrevious).toList();
    final latest = todayPoints.isNotEmpty ? todayPoints.last : null;

    final delta = (prev != null && latest != null) ? latest.y - prev.y : null;

    final touched = (_touchedIndex != null && _touchedIndex! < points.length)
        ? points[_touchedIndex!]
        : null;

    Color deltaColor(double d) {
      if (d == 0) return Colors.grey.shade500;
      return d > 0 ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    }

    IconData deltaIcon(double d) {
      if (d == 0) return Icons.remove;
      return d > 0 ? Icons.arrow_upward : Icons.arrow_downward;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (touched != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    touched.isPrevious
                        ? 'Previous: ${_fmtDate(touched.date.toLocal())}'
                        : 'Today ${_fmtTime(touched.date.toLocal())}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                  ),
                  const Spacer(),
                  Text(
                    _fmtVal(touched.y, touched.y2),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (prev != null) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text('Previous', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fmtVal(prev.y, prev.y2),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
                            ),
                            Text(
                              _fmtDate(prev.date.toLocal()),
                              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (latest != null) ...[
                  _StatRow('Today', _fmtVal(latest.y, latest.y2), color),
                  const SizedBox(height: 8),
                ],
                if (delta != null) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text('Change', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                      ),
                      Icon(deltaIcon(delta), size: 13, color: deltaColor(delta)),
                      const SizedBox(width: 3),
                      Text(
                        '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: deltaColor(delta)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                _StatRow('Readings', '${todayPoints.length} today', color),
                if (touched != null) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text('Notes', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        child: Text(
                          touched.note.isNotEmpty ? touched.note : '—',
                          style: TextStyle(
                            fontSize: 13,
                            color: touched.note.isNotEmpty ? Colors.grey[700] : Colors.grey[400],
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _DateChip({required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 13, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
