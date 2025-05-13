import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/metric_provider.dart';
import '../main.dart';

class RunIntentionScreen extends StatefulWidget {
  const RunIntentionScreen({Key? key}) : super(key: key);

  @override
  _RunIntentionScreenState createState() => _RunIntentionScreenState();
}

class _RunIntentionScreenState extends State<RunIntentionScreen> {
  bool _isCustomRate = false;
  double _selectedRate = 1.0;
  bool _hasSelectedRate = false;
  final TextEditingController _customRateController = TextEditingController();
  final List<double> _rates = [0.25, 0.50, 1.00, 2.00, 5.00, 10.00, 20.00];

  @override
  void dispose() {
    _customRateController.dispose();
    super.dispose();
  }

  void _onRateSelected(double rate) {
    setState(() {
      _selectedRate = rate;
      _isCustomRate = false;
      _hasSelectedRate = true;
    });
  }

  void _showCustomRateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Custom Rate'),
        content: TextField(
          controller: _customRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Rate per km/mile',
            prefixText: '£',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final rate = double.tryParse(_customRateController.text);
              if (rate != null && rate > 0) {
                setState(() {
                  _selectedRate = rate;
                  _isCustomRate = true;
                  _hasSelectedRate = true;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMetric = Provider.of<MetricProvider>(context).isMetric;
    final currencySymbol = Provider.of<CurrencyProvider>(context).currencySymbol;
    final unitAbbr = isMetric ? 'km' : 'mile';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Donation Rate'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How much would you like to donate per $unitAbbr?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    ..._rates.map((rate) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildRateOption(
                        rate: rate,
                        currencySymbol: currencySymbol,
                        unitAbbr: unitAbbr,
                      ),
                    )),
                    const SizedBox(height: 8),
                    _buildCustomRateOption(
                      currencySymbol: currencySymbol,
                      unitAbbr: unitAbbr,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _hasSelectedRate
                    ? () => Navigator.pop(context, _selectedRate)
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Confirm Rate'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateOption({
    required double rate,
    required String currencySymbol,
    required String unitAbbr,
  }) {
    final bool isSelected = !_isCustomRate && _selectedRate == rate;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onRateSelected(rate),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey[300]!,
              width: 1.5,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    currencySymbol + rate.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'per $unitAbbr',
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomRateOption({
    required String currencySymbol,
    required String unitAbbr,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showCustomRateDialog,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isCustomRate ? Theme.of(context).primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isCustomRate 
                ? Theme.of(context).primaryColor 
                : Colors.grey[300]!,
              width: 1.5,
            ),
            boxShadow: _isCustomRate ? [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit,
                    size: 20,
                    color: _isCustomRate ? Colors.white : Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isCustomRate 
                      ? '${currencySymbol}${_selectedRate.toStringAsFixed(2)} per $unitAbbr'
                      : 'Enter custom amount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isCustomRate ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_isCustomRate)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 