import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:multicrop2/service/storage_service.dart';
import 'package:multicrop2/service/api_record_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class TreeSearchDelegate extends SearchDelegate<int?> {
  final List<int> treeNumbers;

  TreeSearchDelegate(this.treeNumbers);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => Container();

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = treeNumbers
        .where((n) => n.toString().contains(query))
        .toList();
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) => ListTile(
        title: Text(
          suggestions[index].toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () => close(context, suggestions[index]),
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        tileColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white70),
      ),
    );
  }
}

class NewDataEntryPage extends StatefulWidget {
  final String workerId;
  final Map<String, dynamic>? selectedTrialData;
  
  const NewDataEntryPage({
    super.key, 
    required this.workerId,
    this.selectedTrialData,
  });

  @override
  State<NewDataEntryPage> createState() => _NewDataEntryPageState();
}

class _NewDataEntryPageState extends State<NewDataEntryPage> {
  // ===== STATE VARIABLES =====
  DateTime selectedDate = DateTime.now();
  int? selectedPlotNumber;
  Map<String, dynamic>? selectedTrialData;
  int? selectedTreeNumber;
  final TextEditingController bunchNumberController = TextEditingController(
    text: '0',
  );
  final TextEditingController weightController = TextEditingController(
    text: '0.00',
  );
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  // Offline controllers
  final TextEditingController treeNumberController = TextEditingController();
  
  // Connectivity
  bool isOnline = true;
  bool isOfflineMode = false;
  bool manualOfflineMode = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool connectivityChecked = false;
  
  // Dynamic lists for API-driven data
  List<Map<String, dynamic>> plotObjects = [];
  List<int> plotNumbers = [];
  List<int> treeNumbers = [];
  bool isLoadingTrees = true;
  bool isLoadingPlots = true;
  bool plotsFailed = false;
  bool treesFailed = false;

  // Cached trials for offline mode
  List<Map<String, dynamic>> cachedTrials = [];

  // ===== LIFECYCLE =====
  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Set trial data if provided
    selectedTrialData = widget.selectedTrialData;
    
    // Set initial date and time
    _dateController.text = DateFormat('MMM dd, yyyy').format(DateTime.now());
    _timeController.text = DateFormat('HH:mm').format(DateTime.now());
    
    await _loadOfflineMode();
    _checkInitialConnectivity();
    _listenToConnectivityChanges();
    
    // Loading will be set based on connectivity
    // Don't fetch trees initially - wait for plot selection
  }

  @override
  void dispose() {
    bunchNumberController.dispose();
    weightController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    treeNumberController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // Load offline mode from SharedPreferences
  Future<void> _loadOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    manualOfflineMode = prefs.getBool('isOfflineMode') ?? false;
    setState(() {});
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

  // Load offline trial data from cache or static
  Future<void> _loadOfflineTrialData() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_trials_list');
    if (cached != null) {
      try {
        final trials = json.decode(cached) as List;
        cachedTrials = trials.map((t) => t as Map<String, dynamic>).toList();
      } catch (e) {
        // If cache is corrupted, leave empty
        cachedTrials = [];
      }
    } else {
      // No cached data, leave empty
      cachedTrials = [];
    }

    // Load cached plots
    final cachedPlots = prefs.getString('cached_plots');
    if (cachedPlots != null) {
      try {
        plotObjects = (json.decode(cachedPlots) as List).map((p) => p as Map<String, dynamic>).toList();
        plotNumbers = plotObjects.map((plot) => plot['id'] as int).toList();
        selectedPlotNumber = plotNumbers.isNotEmpty ? plotNumbers.first : null;
      } catch (e) {
        plotObjects = [];
        plotNumbers = [];
      }
    }

    // Load cached trees
    final cachedTrees = prefs.getString('cached_trees');
    if (cachedTrees != null) {
      try {
        treeNumbers = (json.decode(cachedTrees) as List).cast<int>();
        selectedTreeNumber = treeNumbers.isNotEmpty ? treeNumbers.first : null;
      } catch (e) {
        treeNumbers = [];
      }
    }
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
        isOfflineMode = manualOfflineMode || !hasConnection;
        if (isOfflineMode) {
          // Load offline trial data
          _loadOfflineTrialData();
          isLoadingPlots = false;
          isLoadingTrees = false;
        } else if (connectivityChecked) {
          // If back online and connectivity was already checked, load plots
          if (selectedTrialData != null) {
            _loadPlotsFromTrialData();
          }
        }
      });

      // Show notification when connection changes, but not if in manual offline mode
      if (!manualOfflineMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            content: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    hasConnection
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                    color: hasConnection ? Colors.green : Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasConnection
                          ? "Back Online"
                          : "No Internet - Switched to Offline Mode",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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
    if (!connectivityChecked) {
      connectivityChecked = true;
      if (isOfflineMode) {
        setState(() {
          isLoadingPlots = false;
          isLoadingTrees = false;
        });
      } else if (selectedTrialData != null) {
        _loadPlotsFromTrialData();
      }
    }
  }

  bool _isFormValid() {
    if (isOfflineMode) {
      return selectedTrialData != null &&
             selectedPlotNumber != null &&
             treeNumberController.text.isNotEmpty &&
             _dateController.text.isNotEmpty &&
             _timeController.text.isNotEmpty;
    }
    return selectedTrialData != null &&
           selectedPlotNumber != null &&
           selectedTreeNumber != null &&
           _dateController.text.isNotEmpty &&
           _timeController.text.isNotEmpty;
  }

  /// Load plots directly from the selected trial data
  Future<void> _loadPlotsFromTrialData() async {
    if (selectedTrialData == null) return;

    try {
      setState(() => isLoadingPlots = true);

      // Extract unique plots from trial_plot_batches
      final plotBatches = selectedTrialData!['trial_plot_batches'] as List<dynamic>? ?? [];
      final plots = <Map<String, dynamic>>[];

      for (var batch in plotBatches) {
        if (batch['plot'] != null) {
          final plot = batch['plot'] as Map<String, dynamic>;
          // Avoid duplicates
          if (!plots.any((p) => p['id'] == plot['id'])) {
            plots.add(plot);
          }
        }
      }

      setState(() {
        plotObjects = plots;
        plotNumbers = plots.map((plot) => plot['id'] as int).toList();
        selectedPlotNumber = plotNumbers.isNotEmpty ? plotNumbers.first : null;
        isLoadingPlots = false;
      });

      // Cache the plots for offline use
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('cached_plots', json.encode(plotObjects));

      // Fetch trees for the first plot if available
      if (selectedPlotNumber != null) {
        _loadTreesFromPlotData(selectedPlotNumber);
      }
    } catch (e) {
      // Fallback to empty data
      setState(() {
        plotObjects = [];
        plotNumbers = [];
        selectedPlotNumber = null;
        isLoadingPlots = false;
        plotsFailed = true;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Failed to Load Plots'),
          content: const Text('Unable to fetch plot data from the server. The app will switch to offline mode for plot entry.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _showPopup(false, 'Failed to load plot data: ${e.toString()}');
    }
  }

  /// Load tree numbers for a specific plot from trial data
  Future<void> _loadTreesFromPlotData(int? plotId) async {
    if (selectedTrialData == null || plotId == null) return;

    try {
      setState(() => isLoadingTrees = true);

      // Find the plot batch for the specific plot
      final plotBatches = selectedTrialData!['trial_plot_batches'] as List<dynamic>? ?? [];
      final plotBatch = plotBatches.firstWhere(
        (batch) => batch['plot_id'] == plotId,
        orElse: () => null,
      );

      if (plotBatch == null) {
        throw Exception('Plot not found in trial');
      }

      final numberOfTrees = plotBatch['number_of_trees'] as int? ?? 0;

      // Generate tree numbers from 1 to number_of_trees
      final trees = List.generate(numberOfTrees, (index) => index + 1);

      setState(() {
        treeNumbers = trees;
        selectedTreeNumber = trees.isNotEmpty ? trees.first : null;
        isLoadingTrees = false;
      });

      // Cache the tree numbers for offline use
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('cached_trees', json.encode(treeNumbers));
    } catch (e) {
      // Fallback to default values on error
      setState(() {
        treeNumbers = List.generate(12, (i) => i + 1);
        selectedTreeNumber = 1;
        isLoadingTrees = false;
        treesFailed = true;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Failed to Load Trees'),
          content: const Text('Unable to fetch tree data. Using default tree numbers (1-12).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _showPopup(false, 'Failed to load tree numbers: ${e.toString()}');
    }
  }
  
  /// Fetch available tree numbers from API for a specific plot
  Future<void> _fetchTreeNumbers([int? plotId]) async {
    _loadTreesFromPlotData(plotId);
  }

  // ===== HELPERS =====
  String _formatDate(DateTime date) =>
      "${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}, ${date.year}";

  String _weekday(int w) =>
      ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][w - 1];

  String _month(int m) => [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ]
  [m - 1];

  void _showPopup(bool success, String message) {
    final Color base = success ? Colors.green : Colors.red;
    final Color bg = success ? Colors.green.shade50 : Colors.red.shade50;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(16),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: base.withOpacity(0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(color: base, shape: BoxShape.circle),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  success ? Icons.check : Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
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

  Future<void> _resetForm({required bool keepPlot}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      if (!keepPlot) {
        selectedPlotNumber = plotNumbers.isNotEmpty ? plotNumbers.first : null;
      }
      bunchNumberController.text = '0';
      weightController.text = '0.00';
      selectedDate = DateTime.now();
      selectedTreeNumber = 1;
    });
  }

  Future<void> _resetFormAfterSubmit({required bool keepPlot, required bool keepDate}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      if (!keepDate) {
        selectedDate = DateTime.now();
      }
      if (!keepPlot) {
        selectedPlotNumber = plotNumbers.isNotEmpty ? plotNumbers.first : null;
      }
      bunchNumberController.text = '0';
      weightController.text = '0.00';
      if (isOfflineMode) {
        treeNumberController.text = '';
      } else {
        selectedTreeNumber = treeNumbers.isNotEmpty ? treeNumbers.first : 1;
      }
    });
  }

  Future<void> _submitEntry(String action) async {
    if (_isFormValid()) {
      final submittedAt = DateTime.now();
      final entry = {
        "date": selectedDate,
        "submittedAt": submittedAt,
        "trial_id": isOfflineMode ? 1 : selectedTrialData?['id'],
        "stage": isOfflineMode ? "SRF 5/13" : (selectedTrialData?['name'] ?? 'Unknown Trial'),
        "block": isOfflineMode ? selectedPlotNumber : selectedPlotNumber,
        "plotName": isOfflineMode ? "P$selectedPlotNumber" : (plotObjects.firstWhere((p) => p['id'] == selectedPlotNumber, orElse: () => {'name': 'P$selectedPlotNumber'})['name']),
        "tree": isOfflineMode ? int.tryParse(treeNumberController.text) ?? 0 : selectedTreeNumber,
        "bunches": int.tryParse(bunchNumberController.text) ?? 0,
        "weight": double.tryParse(weightController.text) ?? 0.0,
        "workerId": widget.workerId,
      };

      final entries = await StorageHelper.loadEntries();
      
      // Check if entry with same trial, plot, tree already exists
      final existingIndex = entries.indexWhere((e) => 
        e["stage"] == entry["stage"] && 
        e["block"] == entry["block"] && 
        e["tree"] == entry["tree"]
      );
      
      bool isUpdate = existingIndex != -1;
      if (isUpdate) {
        // Update existing entry
        entries[existingIndex] = entry;
      } else {
        // Add new entry
        entries.add(entry);
      }
      
      await StorageHelper.saveEntries(entries);
      
      // Only attempt to submit to API if online and trial data is available
      if (!isOfflineMode && selectedTrialData != null) {
        // Prepare API data
        final apiEntry = ApiRecordService.prepareApiEntry(
          trialId: selectedTrialData!['id'],
          plotId: selectedPlotNumber,
          treeNumber: selectedTreeNumber,
          measurementDate: selectedDate,
          measurementTime: submittedAt,
          weight: double.tryParse(weightController.text) ?? 0.0,
          bunches: int.tryParse(bunchNumberController.text) ?? 0,
        );

        entry["apiData"] = apiEntry;

        try {
          final apiResponse = await ApiRecordService.submitRecord(apiEntry);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('trial_trees', json.encode(apiResponse));
          _showPopup(true, apiResponse['message'] ?? (isUpdate ? "Entry updated and synced successfully" : "Entry added and synced successfully"));
          entry['syncStatus'] = "sync";
        } catch (e) {
          _showPopup(false, "Entry saved locally, but failed to sync: ${e.toString()}");
          entry['syncStatus'] = "failed";
        }
      } else {
        // Offline mode or no trial data - save locally only
        entry['syncStatus'] = "offline";
        _showPopup(true, isUpdate ? "Entry updated locally (offline mode)" : "Entry saved locally (offline mode)");
      }
      
      // Save again with syncStatus
      await StorageHelper.saveEntries(entries);

      // Reset form based on action
      if (action == 'continue') {
        _resetFormAfterSubmit(keepPlot: true, keepDate: true);
      } else if (action == 'done') {
        _resetFormAfterSubmit(keepPlot: false, keepDate: true);
      }
    } else {
      _showPopup(false, "Please fill all fields correctly");
    }
  }

  void _showSubmitDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildConfirmationDialog(),
    );
  }

  void _changeNumberValue({
    required TextEditingController controller,
    required bool increase,
    required double step,
    required bool isDecimal,
  }) {
    final current = double.tryParse(controller.text) ?? 0.0;
    final next = increase ? current + step : current - step;
    if (isDecimal) {
      final decimals = step.toString().contains('.')
          ? step.toString().split('.')[1].length
          : 0;
      controller.text = (next > 0 ? next : 0).toStringAsFixed(decimals);
    } else {
      controller.text = (next > 0 ? next : 0).toInt().toString();
    }
    setState(() {});
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    const double inputHeight = 58;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF1FFF5), Color(0xFFE6F7EE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _resetForm(keepPlot: false),
                  color: const Color(0xFF16A34A),
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: Column(
                      children: [
                        _buildDateField(inputHeight),
                        const SizedBox(height: 12),
                        _buildTrialField(inputHeight),
                        const SizedBox(height: 12),
                        _buildPlotAndTreeRow(inputHeight),
                        const SizedBox(height: 12),
                        _buildBunchesAndWeightRow(),
                        const SizedBox(height: 12),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () async {
      //     final connectivityResult = await Connectivity().checkConnectivity();
      //     final hasConnection = connectivityResult.any((result) =>
      //         result == ConnectivityResult.mobile ||
      //         result == ConnectivityResult.wifi ||
      //         result == ConnectivityResult.ethernet);
      //     if (!manualOfflineMode && hasConnection) {
      //       await _fetchLatestTrial();
      //     }
      //     final prefs = await SharedPreferences.getInstance();
      //     await prefs.setBool('isOfflineMode', !manualOfflineMode);
      //     setState(() {
      //       manualOfflineMode = !manualOfflineMode;
      //     });
      //     _updateConnectionStatus(connectivityResult);
      //   },
      //   child: Icon(manualOfflineMode ? Icons.wifi_off : Icons.wifi),
      //   tooltip: manualOfflineMode ? 'Switch to Online' : 'Switch to Offline',
      // ),
    );
  }

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Data Entry",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16, // larger title
                    color: Colors.black87,
                  ),
                ),
                Text(
                  "ID ${widget.workerId}",
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(double h) {
    return _formGroup(
      label: "Date of Entry",
      icon: Icons.calendar_today_outlined,
      iconColor: const Color(0xFF16A34A),
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => selectedDate = picked);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black87,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFBBF7D0), width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            _formatDate(selectedDate),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrialField(double h) {
    if (isOfflineMode) {
      return _formGroup(
        label: "Trial",
        icon: Icons.science_outlined,
        iconColor: const Color(0xFF16A34A),
        child: SizedBox(
          height: h,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              selectedTrialData?['name'] ?? 'Please select trial from dashboard',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
        ),
      );
    }
    return _formGroup(
      label: "Trial",
      icon: Icons.science_outlined,
      iconColor: const Color(0xFF16A34A),
      child: SizedBox(
        height: h,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            selectedTrialData?['name'] ?? 'No trial selected',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlotAndTreeRow(double h) {
    return Row(
      children: [
        Expanded(
          child: _formGroup(
            label: "Plot",
            icon: Icons.map_outlined,
            iconColor: const Color(0xFF0F9A62),
            child: SizedBox(height: h, child: _plotField()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _formGroup(
            label: "Tree Number",
            icon: Icons.nature_outlined,
            iconColor: const Color(0xFF0EA5E9),
            child: SizedBox(height: h, child: _treeDropdown()),
          ),
        ),
      ],
    );
  }

  Widget _buildBunchesAndWeightRow() {
    return Row(
      children: [
        Expanded(
          child: _formGroup(
            label: "Bunches",
            icon: Icons.local_florist_outlined,
            iconColor: const Color(0xFF10B981),
            child: _numberInput(
              controller: bunchNumberController,
              unit: "Bunches",
              step: 1,
              isDecimal: false,
              accent: const Color(0xFF10B981),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _formGroup(
            label: "Weight (kg)",
            icon: Icons.scale_outlined,
            iconColor: const Color(0xFF0EA5E9),
            child: _numberInput(
              controller: weightController,
              unit: "kg",
              step: 0.01,
              isDecimal: true,
              accent: const Color(0xFF0EA5E9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _formGroup({
    required String label,
    required Widget child,
    IconData? icon,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null)
              Icon(icon, size: 18, color: iconColor ?? Colors.black54),
            if (icon != null) const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _plotField() {
    if (isLoadingPlots) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Loading plots...',
                style: TextStyle(color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (plotsFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Failed to load plots',
                style: TextStyle(color: Colors.red),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    
    final items = plotObjects.isNotEmpty
        ? plotObjects.map((plot) => DropdownMenuItem<int>(
            value: plot['id'] as int,
            child: Text(plot['name'] as String),
          )).toList()
        : plotNumbers.map((n) => DropdownMenuItem<int>(
            value: n,
            child: Text('P$n'),
          )).toList();
    
    // Ensure the initial value is valid
    final validInitialValue = items.any((item) => item.value == selectedPlotNumber) 
        ? selectedPlotNumber 
        : (items.isNotEmpty ? items.first.value : null);
    
    return DropdownButtonFormField<int>(
      initialValue: validInitialValue,
      isDense: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0F9A62), width: 1.6),
        ),
      ),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
      icon: const Icon(Icons.expand_more, color: Colors.black54, size: 20),
      items: items,
      onChanged: (v) {
        setState(() => selectedPlotNumber = v);
        if (v != null) {
          _fetchTreeNumbers(v);
        }
      },
    );
  }

  Widget _treeDropdown() {
    if (isOfflineMode) {
      return TextField(
        controller: treeNumberController,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: 'Enter tree number',
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0F9A62), width: 1.6),
          ),
        ),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        keyboardType: TextInputType.number,
      );
    }

    if (isLoadingTrees) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Loading trees...',
                style: TextStyle(color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (treesFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Failed to load trees',
                style: TextStyle(color: Colors.red),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    
    return InkWell(
      onTap: () async {
        final result = await showSearch<int?>(
          context: context,
          delegate: TreeSearchDelegate(treeNumbers),
        );
        if (result != null) {
          setState(() => selectedTreeNumber = result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedTreeNumber?.toString() ?? 'Select tree number',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selectedTreeNumber != null ? Colors.black87 : Colors.black54,
                ),
              ),
            ),
            const Icon(Icons.search, color: Colors.black54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _numberInput({
    required TextEditingController controller,
    required String unit,
    required double step,
    required bool isDecimal,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.32), width: 1.3),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            keyboardType: isDecimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
            decoration: const InputDecoration(
              hintText: '0',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _roundBtn(
                icon: Icons.remove,
                accent: accent,
                onTap: () => _changeNumberValue(
                  controller: controller,
                  increase: false,
                  step: step,
                  isDecimal: isDecimal,
                ),
              ),
              const SizedBox(width: 22),
              _roundBtn(
                icon: Icons.add,
                accent: accent,
                onTap: () => _changeNumberValue(
                  controller: controller,
                  increase: true,
                  step: step,
                  isDecimal: isDecimal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: accent.withOpacity(0.38), width: 1),
        ),
        child: Icon(icon, color: accent, size: 22),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isLoading = isLoadingTrees || isLoadingPlots;
    final hasFailed = plotsFailed;
    final isEnabled = !isLoading && !hasFailed && _isFormValid();
    
    return SizedBox(
      width: double.infinity,
      height: 50, // taller button
      child: ElevatedButton(
        onPressed: isEnabled ? _showSubmitDialog : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? const Color(0xFF16A34A) : Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else if (hasFailed)
              const Icon(Icons.error_outline, color: Colors.red, size: 22)
            else
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              hasFailed ? "Plots failed to load" : (isLoading ? "Loading..." : "Submit Entry"),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Confirmation Dialog Widget
  Widget _buildConfirmationDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Confirm Submission",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Icon(
              Icons.help_outline,
              size: 64,
              color: Color(0xFF16A34A),
            ),
            const SizedBox(height: 16),
            const Text(
              "Are you sure you want to submit this entry?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _submitEntry('done');
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "Done",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _submitEntry('continue');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "Continue",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
