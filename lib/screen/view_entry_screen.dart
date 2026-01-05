import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:multicrop2/screen/sync_page_screen.dart';
import 'package:multicrop2/service/storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentEntriesPage extends StatefulWidget {
  final String workerId;

  const RecentEntriesPage({super.key, required this.workerId});

  @override
  State<RecentEntriesPage> createState() => _RecentEntriesPageState();
}

class _RecentEntriesPageState extends State<RecentEntriesPage> {
  // ===== STATE VARIABLES =====
  String _textQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  final DateFormat _entryDateFormat = DateFormat("MMM dd, yyyy");
  List<Map<String, dynamic>> entries = [];
  bool isOnline = true;
  bool isOfflineMode = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // ===== LIFECYCLE METHODS =====
  @override
  void initState() {
    super.initState();
    _loadEntries();
    _loadOfflineMode();
    _checkInitialConnectivity();
    _listenToConnectivityChanges();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // Check connectivity on startup
  Future<void> _checkInitialConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
  }

  // Listen to connectivity changes
  void _listenToConnectivityChanges() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }

  // Update online/offline status
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);

    if (mounted && isOnline != hasConnection) {
      setState(() {
        isOnline = hasConnection;
      });
    }
  }

  // ===== DATA FUNCTIONS =====

  // Load entries from SharedPreferences
  Future<void> _loadEntries() async {
    entries = await StorageHelper.loadEntries();
    setState(() {});
  }

  // Load offline mode from SharedPreferences
  Future<void> _loadOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    isOfflineMode = prefs.getBool('isOfflineMode') ?? false;
    setState(() {});
  }

  // Refresh
  Future<void> _refreshData() async {
    await _loadEntries();
  }

  // Helper method to group entries by plot
  Map<String, List<Map<String, dynamic>>> _groupEntriesByPlot(
    List<Map<String, dynamic>> entries,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var entry in entries) {
      final trial = entry['stage'].toString();
      final plot = entry['block'].toString();
      final key = "${trial}_$plot"; // Group by trial + plot combination
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(entry);
    }

    // Sort entries within each group by tree number
    grouped.forEach((key, entries) {
      entries.sort((a, b) => (a['tree'] as int).compareTo(b['tree'] as int));
    });

    return grouped;
  }

  // Helper method to filter the entries
  List<Map<String, dynamic>> get _filteredEntries {
    final query = _textQuery.toLowerCase().trim();

    return entries.where((entry) {
      // Text Search Filter (on Stage or Plot)
      final stage = entry['stage'].toString().toLowerCase();
      final plot = entry['block'].toString().toLowerCase();
      final textMatches =
          query.isEmpty || stage.contains(query) || plot.contains(query);

      if (!textMatches) return false;

      // Date Range Filter
      final entryDate = entry['date'] as DateTime;
      bool dateMatches = true;

      if (_startDate != null) {
        dateMatches =
            dateMatches &&
            (entryDate.isAtSameMomentAs(_startDate!) ||
                entryDate.isAfter(_startDate!));
      }
      if (_endDate != null) {
        dateMatches =
            dateMatches &&
            (entryDate.isAtSameMomentAs(_endDate!) ||
                entryDate.isBefore(_endDate!.add(const Duration(days: 1))));
      }

      return dateMatches;
    }).toList();
  }

  // Function to show the date range picker
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      helpText: 'Select a Date Range',
      fieldStartHintText: 'Start Date',
      fieldEndHintText: 'End Date',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.green,
            colorScheme: const ColorScheme.light(primary: Colors.green),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // Function to clear the date filter
  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  // ===== DIALOG FUNCTIONS =====

  // Edit Dialog
  void _showEditDialog(Map<String, dynamic> cardEntry) {
    final originalEntryIndex = entries.indexWhere(
      (e) =>
          e["stage"] == cardEntry["stage"] &&
          e["block"] == cardEntry["block"] &&
          e["tree"] == cardEntry["tree"] &&
          _entryDateFormat.format(e["date"] as DateTime) == cardEntry["date"],
    );

    if (originalEntryIndex == -1) return;

    final originalEntry = entries[originalEntryIndex];

    final TextEditingController stageController = TextEditingController(
      text: originalEntry["stage"].toString(),
    );
    final TextEditingController plotController = TextEditingController(
      text: originalEntry["block"].toString(),
    );
    final TextEditingController treeController = TextEditingController(
      text: originalEntry["tree"].toString(),
    );
    final TextEditingController bunchController = TextEditingController(
      text: originalEntry["bunches"].toString(),
    );
    final TextEditingController weightController = TextEditingController(
      text: originalEntry["weight"].toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text("Edit Entry"),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: treeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Tree Number"),
                  ),
                  TextField(
                    controller: bunchController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Total Bunches",
                    ),
                  ),
                  TextField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Total Weight (kg)",
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  entries[originalEntryIndex]["stage"] = stageController.text
                      .trim();
                  entries[originalEntryIndex]["block"] = plotController.text
                      .trim();
                  entries[originalEntryIndex]["tree"] =
                      int.tryParse(treeController.text) ??
                      originalEntry["tree"];
                  entries[originalEntryIndex]["bunches"] =
                      int.tryParse(bunchController.text) ??
                      originalEntry["bunches"];
                  entries[originalEntryIndex]["weight"] =
                      double.tryParse(weightController.text) ??
                      originalEntry["weight"];
                  entries[originalEntryIndex]["isEdited"] = true;
                  entries[originalEntryIndex]["syncStatus"] = "Unsynced";
                });
                await StorageHelper.saveEntries(entries);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // Delete Dialog
  Future<void> _showDeleteDialog(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final originalEntry = entries.firstWhere(
        (e) =>
            e["stage"] == entry["stage"] &&
            e["block"] == entry["block"] &&
            e["tree"] == entry["tree"] &&
            _entryDateFormat.format(e["date"] as DateTime) == entry["date"],
        orElse: () => {},
      );

      if (originalEntry.isNotEmpty) {
        setState(() {
          entries.remove(originalEntry);
        });
        await StorageHelper.saveEntries(entries);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.transparent,
              elevation: 0,
              content: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Entry deleted successfully',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  // ===== UI BUILD METHODS =====

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _filteredEntries;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F9EE), Color(0xFFD6F5E3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  color: Colors.green,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: _buildMainContent(filteredEntries),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Header Bar Widget
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F8EE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SvgPicture.asset(
              'lib/assets/tree_palm.svg',
              colorFilter: const ColorFilter.mode(
                Colors.green,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "Recent Entries",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.sync, color: (isOnline && !isOfflineMode) ? Colors.green : Colors.grey),
            onPressed: (isOnline && !isOfflineMode) ? () async {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SyncPage(workerId: widget.workerId), // Pass workerId here
                ),
              );
            } : null,
          ),
        ],
      ),
    );
  }

  // Main Content Widget
  Widget _buildMainContent(List<Map<String, dynamic>> filteredEntries) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(filteredEntries),
          const SizedBox(height: 15),
          _buildSearchFilter(),
          const SizedBox(height: 10),
          _buildDateRangeFilter(),
          const SizedBox(height: 10),
          _buildEntryList(filteredEntries),
        ],
      ),
    );
  }

  // Title Widget
  Widget _buildTitle(List<Map<String, dynamic>> filteredEntries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, color: Colors.green),
            const SizedBox(width: 8),
            const Text(
              "All Tree Entries",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F8EE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${filteredEntries.length} entries",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          "Complete history of your tree data entries",
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }

  // Search Filter Widget
  Widget _buildSearchFilter() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Filter by Stage or Plot',
        hintText: 'e.g., SRF 5/13 or P3',
        prefixIcon: const Icon(Icons.search, color: Colors.green),
        floatingLabelStyle: const TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _textQuery = value;
        });
      },
    );
  }

  // Date Range Filter Widget
  Widget _buildDateRangeFilter() {
    return Column(
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(
            _startDate == null
                ? "Filter by Date Range"
                : "Date Range: ${_entryDateFormat.format(_startDate!)} - ${_entryDateFormat.format(_endDate!)}",
            style: const TextStyle(fontSize: 15),
          ),
          onPressed: () => _selectDateRange(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green,
            side: const BorderSide(color: Colors.transparent),
            minimumSize: const Size.fromHeight(45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_startDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.close, size: 18),
                label: const Text(
                  "Clear Date Filter",
                  style: TextStyle(fontSize: 14),
                ),
                onPressed: _clearDateFilter,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ),
      ],
    );
  }

  // Entry List Widget
  Widget _buildEntryList(List<Map<String, dynamic>> filteredEntries) {
    final groupedEntries = _groupEntriesByPlot(filteredEntries);
    final sortedKeys = groupedEntries.keys.toList()..sort();

    return Column(
      children: sortedKeys
          .map(
            (key) => Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: _buildPlotCard(key, groupedEntries[key]!),
            ),
          )
          .toList(),
    );
  }

  // Plot Card Widget - Groups all entries for a plot
  Widget _buildPlotCard(
    String key,
    List<Map<String, dynamic>> plotEntries,
  ) {
    // Parse trial and plot from key
    final parts = key.split('_');
    final trial = parts.length > 1 ? parts[0] : 'Unknown';
    final plot = parts.length > 1 ? parts.sublist(1).join('_') : key; // Handle if plot contains underscores
    
    const int maxVisibleTrees = 3;
    const double itemHeight = 170;
    final int totalTrees = plotEntries.length;
    final double listHeight = totalTrees == 0
        ? 0
        : (totalTrees <= maxVisibleTrees
              ? totalTrees * itemHeight
              : maxVisibleTrees * itemHeight);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE3F2E6)),
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plot Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (plotEntries.first['plotName'] ?? "P$plot").replaceFirst('Plot ', 'P'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trial,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${plotEntries.length} ${plotEntries.length == 1 ? 'tree' : 'trees'}",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Tree Entries (scroll if more than 3)
          if (totalTrees > 0)
            SizedBox(
              height: listHeight,
              child: ListView.builder(
                physics: totalTrees > maxVisibleTrees
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: totalTrees,
                itemBuilder: (context, index) =>
                    _buildTreeEntry(plotEntries[index]),
              ),
            ),
        ],
      ),
    );
  }

  // Tree Entry Widget - Individual tree entry within a plot
  Widget _buildTreeEntry(Map<String, dynamic> entry) {
    Color statusColor;
    String statusLabel = entry['syncStatus'] ?? 'Unsynced';
    bool isEdited = entry['isEdited'] ?? false;

    switch (statusLabel) {
      case 'sync':
        statusColor = isEdited ? Colors.grey : Colors.green;
        statusLabel = 'sync';
        break;
      case 'failed':
        statusColor = Colors.red;
        statusLabel = 'failed';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'unsync';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE3F2E6), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF0EA5E9).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        "Tree #${entry['tree']}",
                        style: const TextStyle(
                          color: Color(0xFF0EA5E9),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sync status dot with edited indicator
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (isEdited)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.edit,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _showEditDialog({
                      ...entry,
                      "date": _entryDateFormat.format(
                        entry["date"] as DateTime,
                      ),
                    }),
                    color: Colors.blue,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _showDeleteDialog({
                      ...entry,
                      "date": _entryDateFormat.format(
                        entry["date"] as DateTime,
                      ),
                    }),
                    color: Colors.red,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.black54, size: 14),
              const SizedBox(width: 6),
              Text(
                _entryDateFormat.format(entry["date"] as DateTime),
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTreeDetailItem(
                  "Bunches",
                  entry["bunches"].toString(),
                  Icons.local_florist_outlined,
                  Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTreeDetailItem(
                  "Weight",
                  "${entry["weight"]} kg",
                  Icons.scale_outlined,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tree Detail Item Widget
  Widget _buildTreeDetailItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
