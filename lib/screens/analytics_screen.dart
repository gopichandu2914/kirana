import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../core/localization.dart';
import '../providers/sales_provider.dart';
import 'dashboard/home_screen.dart' show productEmoji;

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<SalesProvider>(context, listen: false).fetchRecentSales());
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final sales = Provider.of<SalesProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // ── Data Preparation (7-Day Scale) ─────────────────────
    final Map<String, int> grouped = sales.getSalesGroupedByProduct();
    final List<MapEntry<String, int>> leaderboard = grouped.entries.toList();
    final int maxUnits = leaderboard.isNotEmpty ? leaderboard.first.value : 1;

    final List<FlSpot> spots = [];
    final Map<String, double> dailyTotals = {};
    
    // 1. Initialize last 7 days with 0.0
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    for (var date in last7Days) {
      final dayKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      dailyTotals[dayKey] = 0.0;
    }

    // 2. Fill in actual sales data
    for (var sale in sales.todaySales) {
      final String fullDateStr = sale['sale_date'].toString(); 
      if (fullDateStr.length >= 10) {
        final String dateKey = fullDateStr.substring(0, 10); // Extract "YYYY-MM-DD"
        if (dailyTotals.containsKey(dateKey)) {
          dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + (sale['total_price'] as num).toDouble();
        }
      }
    }

    // 3. Create spots in date order
    final sortedDayKeys = dailyTotals.keys.toList()..sort();
    for (int i = 0; i < sortedDayKeys.length; i++) {
        spots.add(FlSpot(i.toDouble(), dailyTotals[sortedDayKeys[i]]!));
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isTablet ? 100 : 80,
        title: Text(loc.get('analytics') ?? "Analytics", 
            style: TextStyle(fontSize: isTablet ? 32 : 26, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: sales.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => sales.fetchRecentSales(),
              child: isTablet 
                  ? _buildTabletBody(loc, sales, leaderboard, maxUnits, spots)
                  : _buildPhoneBody(loc, sales, leaderboard, maxUnits, spots),
            ),
    );
  }

  Widget _buildPhoneBody(AppLocalizations loc, SalesProvider sales, List<MapEntry<String, int>> leaderboard, int maxUnits, List<FlSpot> spots) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          children: [
            _buildSummaryCard(loc.get('cash_in'), "₹${sales.todayRevenue.toStringAsFixed(0)}", Colors.green, false),
            const SizedBox(width: 12),
            _buildSummaryCard(loc.get('units_sold_label'), "${sales.totalUnitsInPeriod}", Colors.blue, false),
          ],
        ),
        const SizedBox(height: 20),
        if (leaderboard.isNotEmpty) ...[
          _sectionHeader(loc.get('store_superstar'), Colors.amber.shade900, false),
          const SizedBox(height: 8),
          _buildSuperstarCard(leaderboard.first, loc, false),
          const SizedBox(height: 24),
        ],
        _sectionHeader(loc.get('growth_trend'), Colors.blue.shade900, false),
        const SizedBox(height: 12),
        _buildSparkline(spots, loc, height: 200),
        const SizedBox(height: 24),
        _sectionHeader(loc.get('all_performance'), Colors.orange.shade900, false),
        const SizedBox(height: 12),
        ...leaderboard.map((e) => _buildLeaderboardTile(e, maxUnits, loc, false)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildTabletBody(AppLocalizations loc, SalesProvider sales, List<MapEntry<String, int>> leaderboard, int maxUnits, List<FlSpot> spots) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT COLUMN: Summary & Trends
        Expanded(
          flex: 1,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                   _buildSummaryCard(loc.get('cash_in'), "₹${sales.todayRevenue.toStringAsFixed(0)}", Colors.green, true),
                   const SizedBox(width: 16),
                   _buildSummaryCard(loc.get('units_sold_label'), "${sales.totalUnitsInPeriod}", Colors.blue, true),
                ],
              ),
              const SizedBox(height: 32),
              _sectionHeader(loc.get('growth_trend'), Colors.blue.shade900, true),
              const SizedBox(height: 16),
              _buildSparkline(spots, loc, height: 280),
              const SizedBox(height: 32),
              if (leaderboard.isNotEmpty) ...[
                _sectionHeader(loc.get('store_superstar'), Colors.amber.shade900, true),
                const SizedBox(height: 12),
                _buildSuperstarCard(leaderboard.first, loc, true),
              ],
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // RIGHT COLUMN: Performance List
        Expanded(
          flex: 1,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _sectionHeader(loc.get('all_performance'), Colors.orange.shade900, true),
              const SizedBox(height: 16),
              ...leaderboard.map((e) => _buildLeaderboardTile(e, maxUnits, loc, true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, Color color, bool isTablet) {
    return Text(title, style: TextStyle(fontSize: isTablet ? 24 : 19, fontWeight: FontWeight.bold, color: color));
  }

  Widget _buildSummaryCard(String title, String value, Color color, bool isTablet) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        constraints: BoxConstraints(minHeight: isTablet ? 140 : 100),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(title, 
                  style: TextStyle(fontSize: isTablet ? 18 : 14, color: color.withOpacity(0.8), fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 4),
            Text(value, 
              style: TextStyle(fontSize: isTablet ? 32 : 24, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuperstarCard(MapEntry<String, int> topItem, AppLocalizations loc, bool isTablet) {
    final emoji = productEmoji(topItem.key);
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.amber.shade300, Colors.amber.shade100]),
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: isTablet ? 64 : 48)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topItem.key, style: TextStyle(fontSize: isTablet ? 28 : 22, fontWeight: FontWeight.bold)),
                Text(loc.get('sold_count_template').replaceAll('{count}', topItem.value.toString()), 
                    style: TextStyle(fontSize: isTablet ? 18 : 16, color: Colors.amber.shade900)),
              ],
            ),
          ),
          Icon(Icons.star, color: Colors.amber, size: isTablet ? 48 : 32),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile(MapEntry<String, int> entry, int max, AppLocalizations loc, bool isTablet) {
    final emoji = productEmoji(entry.key);
    final percentage = entry.value / max;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: isTablet ? 40 : 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(entry.key, style: TextStyle(fontSize: isTablet ? 18 : 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Text("${entry.value} ${loc.get('units_sold_label').replaceAll('📦 ', '')}", 
                        style: TextStyle(fontSize: isTablet ? 16 : 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: isTablet ? 16 : 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(Colors.green.shade400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSparkline(List<FlSpot> spots, AppLocalizations loc, {double height = 120}) {
    if (spots.isEmpty) return Container(height: height, alignment: Alignment.center, child: const Text("Waiting for sales..."));
    
    // Find last 7 days for the labels
    final now = DateTime.now();
    final List<String> labels = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      return "${date.day}/${date.month}";
    });

    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.blue.shade100, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= labels.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(labels[index], style: TextStyle(fontSize: 10, color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                  );
                },
                interval: 1,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text("₹${value.toInt()}", style: TextStyle(fontSize: 10, color: Colors.blue.shade900), textAlign: TextAlign.right);
                },
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue.shade700,
              barWidth: 5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.blue.shade700,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.withOpacity(0.3), Colors.blue.withOpacity(0.01)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
