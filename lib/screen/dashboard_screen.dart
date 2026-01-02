import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multicrop/auth/login_auth.dart';
import 'package:multicrop/screen/sync_page_screen.dart';
import 'package:multicrop/service/storage_service.dart';
import 'package:multicrop/service/api_auth_service.dart';
import 'package:multicrop/service/api_trial_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  final String workerId;
  final Function(Map<String, dynamic>)? onTrialSelected;
  
  const ProfilePage({
    super.key,
    required this.workerId,
    this.onTrialSelected,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ===== STATE VARIABLES =====
  List<Map<String, dynamic>> entries = [];
  List<Map<String, dynamic>> trials = [];
  bool isLoadingTrials = true;
  String userName = "Loading...";
  String userEmail = "Loading...";
  String userPhone = "Loading...";
  String userLocation = "Loading...";
  String userPosition = "Loading...";
  String userStaffNo = "Loading...";
  int? userId;

  // Connectivity and offline mode
  bool isOnline = true;
  List<Map<String, dynamic>> cachedTrials = [];

  // ===== LIFECYCLE METHODS =====
  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _loadUserData();
    _loadEntries();
    _loadCachedTrials();
    _loadTrials();
  }

  // ===== DATA FUNCTIONS =====
  
  Future<void> _loadUserData() async {
    final name = await ApiAuthService.getUserName();
    final staffNo = await ApiAuthService.getStaffNo();
    final position = await ApiAuthService.getUserPosition();
    final id = await ApiAuthService.getUserId();

    setState(() {
      userName = name ?? "Guest";
      userStaffNo = staffNo ?? "N/A";
      userPosition = position ?? "";
      userId = id;
    });
  }

  Future<void> _loadTrials() async {
    setState(() => isLoadingTrials = true);
    
    if (isOnline) {
      try {
        final fetchedTrials = await ApiTrialService.getTrials();
        // Cache the fetched trials for offline use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_trials_list', json.encode(fetchedTrials));
        cachedTrials = fetchedTrials; // Update cached trials
        setState(() {
          trials = fetchedTrials;
          isLoadingTrials = false;
        });
      } catch (e) {
        // If API fails, fall back to cached trials
        setState(() {
          trials = cachedTrials;
          isLoadingTrials = false;
        });
      }
    } else {
      // Offline mode: use cached trials as master data
      setState(() {
        trials = cachedTrials;
        isLoadingTrials = false;
      });
    }
  }
  
  Future<void> _loadEntries() async {
    final loadedEntries = await StorageHelper.loadEntries();
    setState(() {
      entries = loadedEntries;
    });
  }

  // Check initial connectivity
  Future<void> _checkInitialConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = connectivityResult.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet);
    });
  }

  // Load cached trials from SharedPreferences
  Future<void> _loadCachedTrials() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_trials_list');
    if (cached != null) {
      try {
        final trialsList = json.decode(cached) as List;
        cachedTrials = trialsList.map((t) => t as Map<String, dynamic>).toList();
      } catch (e) {
        cachedTrials = [];
      }
    }
  }

  // ===== HELPER FUNCTIONS =====
  
  int get totalEntries => entries.length;

  int get unsyncedCount => entries.where((e) => (e['syncStatus'] ?? 'unsync') != 'sync').length;

  int get monthlyRecords {
    final now = DateTime.now();
    return entries.where((e) {
      final date = e['date'] as DateTime;
      return date.year == now.year && date.month == now.month;
    }).length;
  }

  String get plotsRange {
    final plots = entries.map((e) => e['block'].toString()).toSet().toList();
    plots.sort();
    return plots.isEmpty ? "-" : "${plots.first}-${plots.last}";
  }

  double get avgBunches {
    if (entries.isEmpty) return 0.0;
    final totalBunches = entries.fold<int>(
      0,
      (prev, item) => prev + (item['bunches'] as int? ?? 0),
    );
    return totalBunches / entries.length;
  }

  // ===== UI BUILD METHODS =====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBackgroundGradient(),
          _buildBackgroundImage(),
          _buildMainContent(),
        ],
      ),
    );
  }

  // Background Gradient Widget
  Widget _buildBackgroundGradient() {
    return Container(
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
    );
  }

  // Background Image Widget
  Widget _buildBackgroundImage() {
    return Opacity(
      opacity: 0.2,
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

  // Main Content Widget
  Widget _buildMainContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 15),
            _buildUserInfo(),
            const SizedBox(height: 18),
            _buildStatsSection(),
            const SizedBox(height: 10),
            _buildTrialsHeader(),
            const SizedBox(height: 10),
            _buildTrialsSection(),
            const SizedBox(height: 10),
            _buildAccountInfoHeader(),
            const SizedBox(height: 10),
            _buildAccountInfoCard(),
            const SizedBox(height: 10),
            _buildLogoutButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // App Bar Widget
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      title: Text(
        "MultiCrop",
        style: const TextStyle(
          fontFamily: 'Satisfy',
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1B5E20),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // User Info Widget
  Widget _buildUserInfo() {
    return Column(
      children: [
        Center(
          child: Text(
            userName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Center(
          child: Text(
            userPosition,
            style: const TextStyle(
              fontFamily: 'Satisfy',
              fontWeight: FontWeight.bold, 
              color: Colors.black54, 
              fontSize: 20),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            "ID ${widget.workerId}",
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
      ],
    );
  }

  // Stats Section Widget with Horizontal Scroll
  Widget _buildStatsSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatBox(
            "Total of Tree",
            totalEntries.toString(),
            Icons.list_alt_rounded,
            Colors.green.shade700,
          ),
          const SizedBox(width: 10),
          _buildStatBox(
            "Plots",
            plotsRange,
            Icons.grid_view,
            Colors.blue.shade700,
          ),
          const SizedBox(width: 10),
          _buildStatBox(
            "Avg Bunches",
            avgBunches.toStringAsFixed(1),
            Icons.eco,
            Colors.orange.shade700,
          ),
        ],
      ),
    );
  }

  // Stat Box Widget with Fixed Width 
  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      width: 105,
      height: 100, 
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6), 
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 4), 
          Flexible( 
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible( 
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9, 
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Trials Header Widget
  Widget _buildTrialsHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.science_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "Available Trials",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // Trials Section Widget - Single button that opens modal
  Widget _buildTrialsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.science, color: Colors.blue.shade700, size: 19),
          ),
          title: Text(
            "Trial",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            isLoadingTrials 
              ? "Loading trials..." 
              : trials.isEmpty 
                ? (!isOnline ? "No cached trials available" : "No trials available")
                : "${trials.length} trials available${!isOnline ? ' (offline)' : ''}",
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios, 
            size: 16, 
            color: trials.isEmpty ? Colors.grey : Colors.black54
          ),
          onTap: trials.isEmpty ? null : _showTrialsModal,
        ),
      ),
    );
  }

  // Show trials in a modal/bottom sheet
  void _showTrialsModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select a Trial",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...trials.map((trial) => _buildTrialOption(trial)),
          ],
        ),
      ),
    );
  }

  // Trial option in modal
  Widget _buildTrialOption(Map<String, dynamic> trial) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        child: InkWell(
          onTap: () {
            Navigator.pop(context); // Close modal
            // Use callback to navigate to data entry page
            if (widget.onTrialSelected != null) {
              widget.onTrialSelected!(trial);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.science,
                    color: Colors.blue.shade700,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trial['name'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      if (trial['crop'] != null)
                        Text(
                          "Crop: ${trial['crop']['name']}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.blue.shade700,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Account Info Header Widget
  Widget _buildAccountInfoHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "Account Information",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // Account Info Card Widget
  Widget _buildAccountInfoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            _buildInfoTile(
              Icons.sync_problem_outlined,
              "Unsynced Entries",
              "$unsyncedCount/$totalEntries",
            ),
            const Divider(height: 1, indent: 64, endIndent: 16),
            _buildInfoTile(
              Icons.calendar_month_outlined,
              "Monthly Records",
              "$monthlyRecords entries",
            ),
            const Divider(height: 1, indent: 64, endIndent: 16),
            _buildSyncButtonTile(),
          ],
        ),
      ),
    );
  }

  // Info Tile Widget
  Widget _buildInfoTile(IconData icon, String title, String value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 5,
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.green.shade700, size: 19),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  // Sync Button Tile Widget
  Widget _buildSyncButtonTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 5,
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.sync, color: Colors.blue.shade700, size: 19),
      ),
      title: const Text(
        "Sync Data",
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SyncPage(workerId: widget.workerId),
          ),
        );
      },
    );
  }

  // Logout Button Widget
  Widget _buildLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade600, Colors.red.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.logout, color: Colors.white, size: 19),
        label: const Text(
          "Logout",
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        onPressed: () async {
          await ApiAuthService.logout(context);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        },
      ),
    );
  }
}
