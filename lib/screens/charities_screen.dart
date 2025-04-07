import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

// Use the AppColors class from main.dart
import '../main.dart';

class CharitiesScreen extends StatefulWidget {
  final Function(int) onTabChange;
  final Function(Map<String, dynamic>)? onCharitySelected;

  const CharitiesScreen({
    super.key,
    required this.onTabChange,
    this.onCharitySelected,
  });

  @override
  State<CharitiesScreen> createState() => _CharitiesScreenState();
}

class _CharitiesScreenState extends State<CharitiesScreen> {
  int? _selectedCharityIndex;
  final math.Random _random = math.Random();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedCountry;

  final List<String> categories = [
    'Health',
    'Education',
    'Environmental',
    'Humanitarian',
    'Animal Welfare',
    'Children',
    'Arts',
    'International Aid',
  ];

  final List<String> countries = [
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Global',
  ];

  // List of charities with their details
  final List<Map<String, dynamic>> charities = [
    {
      'name': 'Save the Children',
      'description': 'Supporting children\'s rights and providing emergency aid',
      'image': 'assets/images/save_children.png',
      'goal': 50000,
      'raised': 32450,
      'color': Color(0xFFE91E63),
      'icon': Icons.child_care,
      'category': 'Children',
      'country': 'Global',
    },
    {
      'name': 'World Wildlife Fund',
      'description': 'Conservation organization working to reduce human impact on the environment',
      'image': 'assets/images/wwf.png',
      'goal': 75000,
      'raised': 45680,
      'color': Color(0xFF4CAF50),
      'icon': Icons.pets,
      'category': 'Animal Welfare',
      'country': 'Global',
    },
    {
      'name': 'Doctors Without Borders',
      'description': 'Medical humanitarian organization helping people in crisis',
      'image': 'assets/images/doctors.png',
      'goal': 100000,
      'raised': 67890,
      'color': Color(0xFF2196F3),
      'icon': Icons.medical_services,
      'category': 'Health',
      'country': 'Global',
    },
    {
      'name': 'Red Cross',
      'description': 'Providing emergency assistance and disaster relief',
      'image': 'assets/images/red_cross.png',
      'goal': 80000,
      'raised': 52340,
      'color': Color(0xFFE53935),
      'icon': Icons.favorite,
      'category': 'Humanitarian',
      'country': 'Global',
    },
    {
      'name': 'UNICEF',
      'description': 'Working to protect the rights of every child worldwide',
      'image': 'assets/images/unicef.png',
      'goal': 90000,
      'raised': 61250,
      'color': Color(0xFF1565C0),
      'icon': Icons.school,
      'category': 'Children',
      'country': 'Global',
    },
    {
      'name': 'Greenpeace',
      'description': 'Independent global campaigning organization for environmental protection',
      'image': 'assets/images/greenpeace.png',
      'goal': 65000,
      'raised': 34800,
      'color': Color(0xFF43A047),
      'icon': Icons.eco,
      'category': 'Environmental',
      'country': 'Global',
    },
    {
      'name': 'Feeding America',
      'description': 'Nationwide network of food banks fighting hunger',
      'image': 'assets/images/feeding_america.png',
      'goal': 70000,
      'raised': 42600,
      'color': Color(0xFFFFA000),
      'icon': Icons.restaurant,
      'category': 'Humanitarian',
      'country': 'United States',
    },
    {
      'name': 'Cancer Research Institute',
      'description': 'Supporting innovative clinical research to treat and cure cancer',
      'image': 'assets/images/cancer_research.png',
      'goal': 120000,
      'raised': 83500,
      'color': Color(0xFF9C27B0),
      'icon': Icons.biotech,
      'category': 'Health',
      'country': 'United States',
    },
    {
      'name': 'Water.org',
      'description': 'Working to bring water and sanitation to the world',
      'image': 'assets/images/water_org.png',
      'goal': 55000,
      'raised': 29000,
      'color': Color(0xFF00BCD4),
      'icon': Icons.water_drop,
      'category': 'Humanitarian',
      'country': 'Global',
    },
  ];

  List<Map<String, dynamic>> get filteredCharities => charities
      .where((charity) =>
          charity['name']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) &&
          (_selectedCategory == null ||
              charity['category'] == _selectedCategory) &&
          (_selectedCountry == null || charity['country'] == _selectedCountry))
      .toList();

  Color _getRandomColor() {
    return Color.fromRGBO(
      _random.nextInt(255),
      _random.nextInt(255),
      _random.nextInt(255),
      1.0,
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryBlue,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.primaryBlue,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectCharity(Map<String, dynamic> charity) async {
    setState(() {
      _selectedCharityIndex = charities.indexOf(charity);
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedCharity', charity['name'] as String);
    
    // Call the callback to notify the parent about the selection
    if (widget.onCharitySelected != null) {
      widget.onCharitySelected!(charity);
    }
    
    // Navigate back to home screen
    widget.onTabChange(0);
  }

  void _showConfirmationDialog(Map<String, dynamic> charity) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirm Selection'),
        content: Text('You have selected ${charity['name']} as your charity. All your runs will contribute to this cause.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              _selectCharity(charity); // Then select the charity
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Charity'),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: Column(
        children: [
          // Search and filters section
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search bar
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search charities',
                      hintStyle: TextStyle(
                        color: Colors.black.withOpacity(0.3),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.black.withOpacity(0.3),
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Category filters
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip(
                        'All Categories',
                        _selectedCategory == null,
                        () => setState(() => _selectedCategory = null),
                      ),
                      const SizedBox(width: 8),
                      ...categories.map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip(
                            category,
                            _selectedCategory == category,
                            () => setState(() => _selectedCategory = category),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Country filters
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip(
                        'All Countries',
                        _selectedCountry == null,
                        () => setState(() => _selectedCountry = null),
                      ),
                      const SizedBox(width: 8),
                      ...countries.map((country) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip(
                            country,
                            _selectedCountry == country,
                            () => setState(() => _selectedCountry = country),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Charity list
          Expanded(
            child: filteredCharities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No charities found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: filteredCharities.length,
                    itemBuilder: (context, index) {
                      final charity = filteredCharities[index];
                      final progress = charity['raised'] / charity['goal'];
                      final isSelected = _selectedCharityIndex == charities.indexOf(charity);
                      final color = charity['color'] as Color;
                      final icon = charity['icon'] as IconData;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCharityIndex = charities.indexOf(charity);
                          });
                        },
                        child: Card(
                          elevation: 4,
                          margin: const EdgeInsets.only(bottom: 16.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            side: BorderSide(
                              color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                              width: 2.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Selection Indicator
                              if (isSelected)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  color: AppColors.primaryBlue.withOpacity(0.1),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: AppColors.primaryBlue,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Selected',
                                        style: TextStyle(
                                          color: AppColors.primaryBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Charity Image/Logo
                              Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(isSelected ? 0 : 8.0),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(0.5),
                                            blurRadius: 10,
                                            spreadRadius: 3,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        icon,
                                        size: 80,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      charity['name'],
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: color.withOpacity(0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            charity['category'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            charity['country'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Charity Description
                                    Text(
                                      charity['description'],
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Progress Bar and Amount
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: Colors.grey[200],
                                          valueColor: AlwaysStoppedAnimation<Color>(color),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '\$${charity['raised'].toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Goal: \$${charity['goal'].toStringAsFixed(0)}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Confirm selection button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedCharityIndex != null
                    ? () {
                        final selectedCharity = charities[_selectedCharityIndex!];
                        _showConfirmationDialog(selectedCharity);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: const Text(
                  'Confirm Selection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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