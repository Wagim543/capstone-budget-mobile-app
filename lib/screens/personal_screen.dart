import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/personal_models.dart';

class PersonalScreen extends StatefulWidget {
  const PersonalScreen({super.key});

  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  bool _isCampusDay = true;
  double _campusDailyRate = 250.0;
  double _onlineDailyRate = 75.0;

  double _vaultBalance = 0.0;
  final double _vaultGoal = 16000.0;
  bool _hideVaultBalance = false;
  List<PersonalExpense> _todayExpenses = [];
  bool _isLoading = true;

  double get _dailyTarget =>
      _isCampusDay ? _campusDailyRate : _onlineDailyRate;

  double get _todaySpent =>
      _todayExpenses.fold(0.0, (sum, item) => sum + item.amount);

  double get _todayRemaining => _dailyTarget - _todaySpent;

  @override
  void initState() {
    super.initState();
    _loadPersonalData();
  }

  String _todayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadPersonalData() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _todayDateKey();

    final savedVault = prefs.getDouble('personal_vault_balance') ?? 0.0;
    final savedMode = prefs.getBool('personal_is_campus_day') ?? true;
    final savedHide = prefs.getBool('personal_hide_vault') ?? false;
    final savedCampusRate = prefs.getDouble('personal_campus_rate') ?? 250.0;
    final savedOnlineRate = prefs.getDouble('personal_online_rate') ?? 75.0;
    final savedExpensesJson = prefs.getString('personal_expenses_$todayKey');

    List<PersonalExpense> loadedExpenses = [];
    if (savedExpensesJson != null) {
      try {
        final List decoded = jsonDecode(savedExpensesJson);
        loadedExpenses = decoded
            .map((item) => PersonalExpense.fromMap(item))
            .toList();
      } catch (e) {
        debugPrint('Error parsing personal expenses: $e');
      }
    }

    setState(() {
      _vaultBalance = savedVault;
      _isCampusDay = savedMode;
      _hideVaultBalance = savedHide;
      _campusDailyRate = savedCampusRate;
      _onlineDailyRate = savedOnlineRate;
      _todayExpenses = loadedExpenses;
      _isLoading = false;
    });
  }

  Future<void> _savePersonalData() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _todayDateKey();

    await prefs.setDouble('personal_vault_balance', _vaultBalance);
    await prefs.setBool('personal_is_campus_day', _isCampusDay);
    await prefs.setBool('personal_hide_vault', _hideVaultBalance);
    await prefs.setDouble('personal_campus_rate', _campusDailyRate);
    await prefs.setDouble('personal_online_rate', _onlineDailyRate);

    final encoded = jsonEncode(_todayExpenses.map((e) => e.toMap()).toList());
    await prefs.setString('personal_expenses_$todayKey', encoded);
  }

  Future<void> _toggleAppTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = themeNotifier.value == ThemeMode.dark ||
        (themeNotifier.value == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);

    final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
    themeNotifier.value = nextMode;
    await prefs.setString(
        'app_theme_mode', nextMode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> _quickLog(String title, double amount, String category) async {
    setState(() {
      _todayExpenses.insert(
        0,
        PersonalExpense(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          amount: amount,
          timestamp: DateTime.now(),
          category: category,
        ),
      );
    });
    await _savePersonalData();
  }

  Future<void> _sweepToVault() async {
    if (_todayRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No remaining allowance left to sweep today!'),
        ),
      );
      return;
    }

    final sweepAmount = _todayRemaining;
    setState(() {
      _vaultBalance += sweepAmount;
      _todayExpenses.insert(
        0,
        PersonalExpense(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Swept to Savings Vault',
          amount: sweepAmount,
          timestamp: DateTime.now(),
          category: 'Vault Sweep',
        ),
      );
    });
    await _savePersonalData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.teal,
        content: Text(
          'Swept ₱${sweepAmount.toStringAsFixed(2)} directly into Emergency Vault!',
        ),
      ),
    );
  }

  Future<void> _deletePersonalExpense(PersonalExpense item) async {
    final index = _todayExpenses.indexOf(item);
    if (index == -1) return;

    setState(() {
      if (item.category == 'Vault Sweep') {
        _vaultBalance = (_vaultBalance - item.amount).clamp(
          0.0,
          double.infinity,
        );
      }
      _todayExpenses.removeAt(index);
    });
    await _savePersonalData();
  }

  void _openDailyRateSettings() {
    final campusController = TextEditingController(
      text: _campusDailyRate.toStringAsFixed(0),
    );
    final onlineController = TextEditingController(
      text: _onlineDailyRate.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Set Daily Allowances'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: campusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Campus Day Allowance (FTF)',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: onlineController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Online / Home Allowance',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newCampus = double.tryParse(campusController.text);
              final newOnline = double.tryParse(onlineController.text);
              if (newCampus != null && newOnline != null) {
                setState(() {
                  _campusDailyRate = newCampus;
                  _onlineDailyRate = newOnline;
                });
                await _savePersonalData();
              }
              if (dCtx.mounted) Navigator.pop(dCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openManualVaultAdjustment() {
    final textController = TextEditingController();
    bool isDeposit = true;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text('Adjust Vault Balance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Deposit'),
                      icon: Icon(Icons.arrow_downward, size: 16),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Withdraw'),
                      icon: Icon(Icons.arrow_upward, size: 16),
                    ),
                  ],
                  selected: {isDeposit},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setDState(() {
                      isDeposit = newSelection.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: '₱ ',
                  labelText: isDeposit ? 'Deposit Amount' : 'Withdraw Amount',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final val = double.tryParse(textController.text);
                if (val != null && val > 0) {
                  setState(() {
                    if (isDeposit) {
                      _vaultBalance += val;
                    } else {
                      _vaultBalance = (_vaultBalance - val).clamp(
                        0.0,
                        double.infinity,
                      );
                    }
                  });
                  await _savePersonalData();
                }
                if (dCtx.mounted) Navigator.pop(dCtx);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _openCustomExpenseModal() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom Personal Expense',
              style: Theme.of(ctx).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount (PHP)',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'What was this for?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  final double? amount = double.tryParse(amountController.text);
                  final String title = titleController.text.trim();
                  if (amount == null || amount <= 0 || title.isEmpty) return;
                  _quickLog(title, amount, 'Custom');
                  Navigator.pop(ctx);
                },
                child: const Text('Log Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Jeep':
        return Icons.directions_bus;
      case 'Lunch':
        return Icons.restaurant;
      case 'Snack':
        return Icons.local_cafe;
      case 'Print':
        return Icons.print;
      case 'Vault Sweep':
        return Icons.savings;
      default:
        return Icons.shopping_bag;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final double vaultProgress = (_vaultGoal > 0)
        ? (_vaultBalance / _vaultGoal).clamp(0.0, 1.0)
        : 0.0;
    final bool isOverDaily = _todayRemaining < 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Wallet & Vault'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: _toggleAppTheme,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Configure Daily Rates',
            onPressed: _openDailyRateSettings,
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Adjust Vault Balance',
            onPressed: _openManualVaultAdjustment,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(
                      'Campus (₱${_campusDailyRate.toStringAsFixed(0)})',
                    ),
                    icon: const Icon(Icons.school),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(
                      'Online (₱${_onlineDailyRate.toStringAsFixed(0)})',
                    ),
                    icon: const Icon(Icons.home),
                  ),
                ],
                selected: {_isCampusDay},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _isCampusDay = newSelection.first;
                  });
                  _savePersonalData();
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's Remaining Cash",
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱ ${_todayRemaining.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isOverDaily
                                        ? Colors.red
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _todayRemaining > 0 ? _sweepToVault : null,
                          icon: const Icon(Icons.savings_outlined, size: 18),
                          label: const Text('Sweep Leftover'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Spent ₱${_todaySpent.toStringAsFixed(2)} of ₱${_dailyTarget.toStringAsFixed(0)} allowance',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick 1-Tap Log',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.directions_bus, size: 16),
                        label: const Text('+₱15 Jeep'),
                        onPressed: () =>
                            _quickLog('Jeepney Fare', 15.0, 'Jeep'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.restaurant, size: 16),
                        label: const Text('+₱80 Lunch'),
                        onPressed: () =>
                            _quickLog('Canteen Lunch', 80.0, 'Lunch'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.local_cafe, size: 16),
                        label: const Text('+₱35 Snack'),
                        onPressed: () =>
                            _quickLog('Snack / Drinks', 35.0, 'Snack'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.print, size: 16),
                        label: const Text('+₱10 Print'),
                        onPressed: () =>
                            _quickLog('Photocopy/Print', 10.0, 'Print'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('Custom...'),
                        onPressed: _openCustomExpenseModal,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              color: isDark ? Colors.teal.shade900 : Colors.teal.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.shield,
                              color: isDark
                                  ? Colors.tealAccent
                                  : Colors.teal.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Emergency Delay Vault',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.teal.shade900,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            _hideVaultBalance
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: isDark
                                ? Colors.tealAccent
                                : Colors.teal.shade800,
                          ),
                          tooltip: 'Toggle Privacy',
                          onPressed: () {
                            setState(() {
                              _hideVaultBalance = !_hideVaultBalance;
                            });
                            _savePersonalData();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hideVaultBalance
                          ? '₱ ••••••••'
                          : '₱ ${_vaultBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.tealAccent : Colors.teal.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: vaultProgress,
                        minHeight: 8,
                        color: isDark ? Colors.tealAccent : Colors.teal.shade700,
                        backgroundColor: isDark
                            ? Colors.teal.shade800
                            : Colors.teal.shade100,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(vaultProgress * 100).toStringAsFixed(0)}% of ₱16,000 Target',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.teal.shade200
                                : Colors.teal.shade900,
                          ),
                        ),
                        Text(
                          '2-Mo. Buffer Cushion',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.teal.shade300
                                : Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Living Purchases",
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_todayExpenses.length} logged',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (_todayExpenses.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Text(
                  'No purchases recorded yet today.\nTap one of the quick chips above to log your commute or food.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _todayExpenses.length,
                padding: const EdgeInsets.only(bottom: 24),
                itemBuilder: (context, index) {
                  final item = _todayExpenses[index];
                  final isSweep = item.category == 'Vault Sweep';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSweep
                          ? (isDark
                              ? Colors.teal.shade800
                              : Colors.teal.shade100)
                          : (isDark
                              ? Colors.indigo.shade900
                              : Colors.indigo.shade50),
                      child: Icon(
                        _getCategoryIcon(item.category),
                        color: isSweep
                            ? (isDark ? Colors.tealAccent : Colors.teal)
                            : (isDark ? Colors.indigoAccent : Colors.indigo),
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')} • ${item.category}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₱ ${item.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isSweep
                                ? (isDark ? Colors.tealAccent : Colors.teal)
                                : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.black45,
                          ),
                          onPressed: () => _deletePersonalExpense(item),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}