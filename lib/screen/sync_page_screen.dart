import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:multicrop2/bottomnav.dart';
import 'package:multicrop2/service/storage_service.dart';
import 'package:multicrop2/service/api_record_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SyncPage extends StatefulWidget {
  final String workerId;
  const SyncPage({super.key, required this.workerId}); // Update constructor

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  // ===== STATE VARIABLES =====
  bool isSyncing = false;
  bool syncCompleted = false;
  List<Map<String, dynamic>> allEntries = [];
  List<Map<String, dynamic>> entries = [];
  List<Map<String, dynamic>> syncStatuses = [];

  // ===== LIFECYCLE METHODS =====
  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  // ===== DATA FUNCTIONS =====
  
  Future<void> _loadEntries() async {
    final loadedEntries = await StorageHelper.loadEntries();
    final filteredEntries = loadedEntries.where((entry) {
      final status = entry['syncStatus']?.toString();
      final isEdited = entry['isEdited'] ?? false;
      final hasValidTrialId = entry['trial_id'] is int || entry['apiData']?['trial_id'] is int || status == 'offline';
      return (status == null || status != 'sync' || isEdited || status == 'offline') && (hasValidTrialId || status == 'offline');
    }).toList();

    setState(() {
      allEntries = loadedEntries;
      entries = filteredEntries;
    });
  }

  Future<void> _startSync() async {
    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    print('Connectivity result: $connectivityResult');
    final hasConnection = connectivityResult.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
    print('Has connection: $hasConnection');

    if (!hasConnection) {
      setState(() {
        isSyncing = false;
        syncCompleted = true;
        syncStatuses = entries.map((entry) => {"entry": entry, "status": "failed: No internet"}).toList();
      });
      return;
    }

    if (entries.isEmpty) return;

    setState(() {
      isSyncing = true;
      syncCompleted = false;
      syncStatuses = entries
          .map((entry) {
            final hasValidTrialId = entry['trial_id'] is int || entry['apiData']?['trial_id'] is int;
            entry['syncStatus'] = hasValidTrialId ? "unsync" : "offline";
            return {"entry": entry, "status": hasValidTrialId ? "unsync" : "offline"};
          })
          .toList();
    });

    for (var i = 0; i < syncStatuses.length; i++) {
      final entry = syncStatuses[i]["entry"] as Map<String, dynamic>;
      final hasValidTrialId = entry['trial_id'] is int || entry['apiData']?['trial_id'] is int;
      
      if (!hasValidTrialId) {
        // Skip entries without valid integer trial_id
        setState(() {
          syncStatuses[i]["status"] = "skipped: invalid trial_id";
        });
        continue;
      }

      // Submit to API
      try {
        final apiEntry = ApiRecordService.prepareApiEntry(
          trialId: entry['trial_id'] ?? entry["apiData"]?["trial_id"],
          plotId: entry["block"],
          treeNumber: entry["tree"],
          measurementDate: entry["date"] as DateTime,
          measurementTime: entry["submittedAt"] ?? DateTime.now(),
          weight: entry["weight"] as double,
          bunches: entry["bunches"] as int,
        );

        // Validate required fields
        if (apiEntry["plot_id"] == null || apiEntry["tree_number"] == null) {
          print('Entry $i has incomplete data: plot_id=${apiEntry["plot_id"]}, tree_number=${apiEntry["tree_number"]}');
          setState(() {
            syncStatuses[i]["status"] = "failed: Incomplete data";
            final entryMap = syncStatuses[i]["entry"] as Map<String, dynamic>;
            entryMap['syncStatus'] = "failed";
          });
          continue;
        }

        print('Attempting to sync entry $i with apiEntry: $apiEntry');
        final apiResponse = await ApiRecordService.submitRecord(apiEntry);
        print('Sync successful for entry $i: $apiResponse');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('trial_trees', json.encode(apiResponse));

        setState(() {
          syncStatuses[i]["status"] = "sync";
          final entryMap = syncStatuses[i]["entry"] as Map<String, dynamic>;
          entryMap['syncStatus'] = "sync";
          entryMap['isEdited'] = false;
        });
      } catch (e) {
        print('Sync failed for entry $i: $e');
        setState(() {
          syncStatuses[i]["status"] = "failed: ${e.toString()}";
          final entryMap = syncStatuses[i]["entry"] as Map<String, dynamic>;
          entryMap['syncStatus'] = "failed";
        });
      }
    }

    await StorageHelper.saveEntries(allEntries);

    setState(() {
      isSyncing = false;
      syncCompleted = true;
    });
  }

  // ===== HELPER FUNCTIONS =====
  
  // Group entries by trial and plot
  Map<String, List<Map<String, dynamic>>> _groupEntriesByTrialPlot(
      List<Map<String, dynamic>> entries) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (var entry in entries) {
      final trial = entry['entry']['stage'].toString();
      final plot = entry['entry']['block'].toString();
      final key = "${trial}_$plot"; // Group by trial + plot combination
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(entry);
    }
    
    // Sort entries within each trial-plot group by tree number
    grouped.forEach((key, entries) {
      entries.sort((a, b) => 
        (a['entry']['tree'] as int).compareTo(b['entry']['tree'] as int));
    });
    
    return grouped;
  }
  
  int get uploadedCount => syncStatuses.where((s) => s["status"] == "sync").length;
  int get failedCount => syncStatuses.where((s) => s["status"].toString().startsWith("failed")).length;
  int get pendingCount => syncStatuses.where((s) => s["status"] == "unsync").length;
  int get skippedCount => syncStatuses.where((s) => s["status"] == "skipped").length;

  // ===== UI BUILD METHODS =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color.fromARGB(255, 167, 229, 188),
              Color(0xFFE4F8EB),
              Color.fromARGB(255, 167, 229, 188),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Stack(
          children: [
            _buildBackgroundImage(),
            SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadEntries,
                color: Colors.green,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 45),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildStatsSection(),
                            const SizedBox(height: 30),
                            _buildSyncButton(),
                            _buildEntryList(),
                            _buildBackToHomeButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Background Image Widget
  Widget _buildBackgroundImage() {
    return Opacity(
      opacity: 0.15,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("lib/assets/plant.jpg"),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  // Header Widget
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 25),
          onPressed: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Sync Data to Cloud',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  // Stats Section Widget
  Widget _buildStatsSection() {
    if (!isSyncing && !syncCompleted) {
      return _buildReadyToSyncCard();
    } else {
      return _buildSyncProgressCard();
    }
  }

  // Ready to Sync Card Widget
  Widget _buildReadyToSyncCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${entries.length}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Entries Ready to Sync',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Sync Progress Card Widget
  Widget _buildSyncProgressCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('sync', uploadedCount, Colors.green),
              _buildStatItem('failed', failedCount, Colors.red),
              _buildStatItem('unsync', pendingCount, Colors.orange),
              _buildStatItem('skipped', skippedCount, Colors.blue),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: isSyncing
                ? (uploadedCount + failedCount + skippedCount) / (entries.isEmpty ? 1 : entries.length)
                : 1.0,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  // Stat Item Widget
  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            label == 'sync'
                ? Icons.check_circle
                : label == 'failed'
                    ? Icons.error
                    : label == 'skipped'
                        ? Icons.skip_next
                        : Icons.schedule,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // Sync Button Widget
  Widget _buildSyncButton() {
    if (!isSyncing && !syncCompleted) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.green, Colors.lightGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.5),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: entries.isEmpty ? null : _startSync,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: 38,
              vertical: 10,
            ),
            disabledBackgroundColor: Colors.transparent,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_upload, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'START SYNC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // Entry List Widget
  Widget _buildEntryList() {
    if (isSyncing || syncCompleted) {
      final groupedEntries = _groupEntriesByTrialPlot(syncStatuses);
      final sortedKeys = groupedEntries.keys.toList()
        ..sort((a, b) {
          final partsA = a.split('_');
          final partsB = b.split('_');
          final trialA = partsA[0];
          final trialB = partsB[0];
          final plotA = int.parse(partsA[1]);
          final plotB = int.parse(partsB[1]);
          
          // First sort by trial, then by plot number
          final trialCompare = trialA.compareTo(trialB);
          if (trialCompare != 0) return trialCompare;
          return plotA.compareTo(plotB);
        });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Entry Details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final key = sortedKeys[index];
              final trialPlotEntries = groupedEntries[key]!;
              return _buildTrialPlotCard(key, trialPlotEntries);
            },
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  // Trial-Plot Card Widget
  Widget _buildTrialPlotCard(String key, List<Map<String, dynamic>> trialPlotEntries) {
    // Parse trial and plot from key
    final parts = key.split('_');
    final trial = parts.length > 1 ? parts[0] : 'Unknown';
    final plot = parts.length > 1 ? parts.sublist(1).join('_') : key; // Handle if plot contains underscores
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Plot Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'P$plot',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        trial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${trialPlotEntries.length} trees',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tree Entries
          ...trialPlotEntries.map((statusEntry) => _buildTreeEntry(statusEntry)),
        ],
      ),
    );
  }

  // Tree Entry Widget
  Widget _buildTreeEntry(Map<String, dynamic> statusEntry) {
    final entry = statusEntry['entry'];
    final syncStatus = statusEntry['status'];
    final isEdited = entry['isEdited'] ?? false;
    
    Color statusColor;
    String statusText;
    
    switch (syncStatus) {
      case "sync":
        statusColor = isEdited ? Colors.grey : Colors.green;
        statusText = "sync";
        break;
      case "failed":
        statusColor = Colors.red;
        statusText = "failed";
        break;
      case "skipped":
        statusColor = Colors.blue;
        statusText = "skipped";
        break;
      case "offline":
        statusColor = Colors.grey;
        statusText = "offline";
        break;
      default:
        statusColor = Colors.orange;
        statusText = "unsync";
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tree number and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tree #${entry['tree']}',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    if (isEdited)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.edit,
                          size: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Date
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                entry['date'] is DateTime 
                    ? DateFormat('MMM dd, yyyy').format(entry['date'])
                    : entry['date']?.toString() ?? 'N/A',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Bunches and Weight
          Row(
            children: [
              Expanded(
                child: _buildTreeDetailItem(
                  Icons.local_florist,
                  'Bunches',
                  entry['bunches']?.toString() ?? '0',
                  Colors.purple.shade50,
                  Colors.purple.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTreeDetailItem(
                  Icons.scale,
                  'Weight',
                  '${entry['weight']?.toString() ?? '0'} kg',
                  Colors.orange.shade50,
                  Colors.orange.shade700,
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
    IconData icon,
    String label,
    String value,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Back to Home Button Widget
  Widget _buildBackToHomeButton() {
    if (syncCompleted) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.green, Colors.lightGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.5),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BottomNavBar(workerId: widget.workerId),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: 38,
              vertical: 10,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Back to Home',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}