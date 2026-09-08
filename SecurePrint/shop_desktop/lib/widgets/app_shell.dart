import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);

  @override
  _AppShellState createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const Center(child: Text('Print Jobs Placeholder')),
    const Center(child: Text('Documents Placeholder')),
    const Center(child: Text('Printing Placeholder')),
    const Center(child: Text('History Placeholder')),
    const Center(child: Text('Settings Placeholder')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SecurePrint Shop'),
        elevation: 2,
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.print_outlined),
                selectedIcon: Icon(Icons.print),
                label: Text('Print Jobs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.folder_outlined),
                selectedIcon: Icon(Icons.folder),
                label: Text('Documents'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_printshop_outlined),
                selectedIcon: Icon(Icons.local_printshop),
                label: Text('Printing'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('History'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
