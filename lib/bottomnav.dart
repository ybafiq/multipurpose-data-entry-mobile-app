import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:multicrop2/screen/trial_entry_screen.dart';
import 'package:multicrop2/screen/dashboard_screen.dart';
import 'package:multicrop2/screen/view_entry_screen.dart';

class BottomNavBar extends StatefulWidget {
  final String workerId;
  const BottomNavBar({super.key, required this.workerId});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _currentIndex = 0; // Start with profile page
  Map<String, dynamic>? _selectedTrialData;

  final List<Widget> pages = [];
  
  @override
  void initState() {
    super.initState();
    _rebuildPages();
  }

  void _rebuildPages() {
    pages.clear();
    pages.addAll([
      ProfilePage(workerId: widget.workerId, onTrialSelected: _navigateToDataEntry),
      NewDataEntryPage(workerId: widget.workerId, selectedTrialData: _selectedTrialData),
      RecentEntriesPage(workerId: widget.workerId),
    ]);
  }

  void _navigateToDataEntry(Map<String, dynamic> trialData) {
    setState(() {
      _selectedTrialData = trialData;
      _currentIndex = 1; // Navigate to Data Entry page (index 1)
      _rebuildPages(); // Rebuild pages with the selected trial
    });
  }

  static const Color _primaryGreen = Color(0xFF4CAF50);

  List<Widget> _buildItems() {
    return [
      Icon(
        Icons.account_circle_outlined,
        size: 28,
        color: _currentIndex == 0 ? Colors.white : Colors.black,
      ),
      Icon(
        Icons.add_circle_outline,
        size: 30,
        color: _currentIndex == 1 ? Colors.white : Colors.black,
      ),
      Icon(
        Icons.analytics_outlined,
        size: 28,
        color: _currentIndex == 2 ? Colors.white : Colors.black,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFDF9FD),
      body: pages[_currentIndex],

      bottomNavigationBar: CurvedNavigationBar(
        key: const ValueKey('CurvedNavBar'),
        index: _currentIndex,
        height: 65,

        color: Colors.white,

        buttonBackgroundColor: _primaryGreen,

        backgroundColor: Colors.transparent,

        animationCurve: Curves.easeOutQuad,
        animationDuration: const Duration(milliseconds: 400),

        items: _buildItems(),

        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}
