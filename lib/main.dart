import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CapstoneBudgetApp());
}

class CapstoneBudgetApp extends StatefulWidget {
  const CapstoneBudgetApp({super.key});

  @override
  State<CapstoneBudgetApp> createState() => _CapstoneBudgetAppState();
}

class _CapstoneBudgetAppState extends State<CapstoneBudgetApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode');
    if (isDark != null) {
      setState(() {
        _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      });
    }
  }

  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }
    });
    await prefs.setBool('is_dark_mode', _themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Capstone Budget',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
        ),
      ),
      themeMode: _themeMode,
      home: BudgetDashboard(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class ExpenseItem {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String paidBy;
  final String category;
  bool isReimbursed;

  ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.paidBy,
    required this.category,
    this.isReimbursed = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'paidBy': paidBy,
        'category': category,
        'isReimbursed': isReimbursed,
      };

  factory ExpenseItem.fromMap(Map<String, dynamic> map) => ExpenseItem(
        id: map['id'],
        title: map['title'],
        amount: (map['amount'] as num).toDouble(),
        date: DateTime.parse(map['date']),
        paidBy: map['paidBy'] ?? 'Unknown',
        category: map['category'] ?? 'General',
        isReimbursed: map['isReimbursed'] ?? false,
      );
}

class BudgetDashboard extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const BudgetDashboard({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<BudgetDashboard> createState() => _BudgetDashboardState();
}

class _BudgetDashboardState extends State<BudgetDashboard> {
  double _totalBudget = 9000.0;
  List<ExpenseItem> _expenses = [];
  bool _isLoading = true;

  String _activeFilterCategory = 'All';
  String _activeFilterMember = 'All';
  String _selectedMonthYear = 'All Time';
  bool _sortNewestFirst = true;

  List<String> _categories = [
    'Hardware/Components',
    'Printing/Docs',
    'Tools/Materials',
    'Food/Meeting',
    'General',
  ];

  List<String> _members = [
    'Me (Advance)',
    'Direct Fund',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBudget = prefs.getDouble('capstone_budget') ?? 9000.0;
    final savedExpensesJson = prefs.getString('capstone_expenses');
    final savedCategories = prefs.getStringList('custom_categories');
    final savedMembers = prefs.getStringList('custom_members');

    List<ExpenseItem> loadedList = [];
    if (savedExpensesJson != null) {
      try {
        final List decoded = jsonDecode(savedExpensesJson);
        loadedList = decoded.map((item) => ExpenseItem.fromMap(item)).toList();
      } catch (e) {
        debugPrint('Error parsing stored expenses: $e');
      }
    }

    setState(() {
      _totalBudget = savedBudget;
      _expenses = loadedList;
      if (savedCategories != null && savedCategories.isNotEmpty) {
        _categories = savedCategories;
      }
      if (savedMembers != null && savedMembers.isNotEmpty) {
        _members = savedMembers
            .where((m) => m != 'Member A' && m != 'Member B')
            .toList();
      }

      if (!_members.contains('Me (Advance)')) {
        _members.insert(0, 'Me (Advance)');
      }
      if (!_members.contains('Direct Fund')) {
        _members.add('Direct Fund');
      }

      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('capstone_budget', _totalBudget);
    final encoded = jsonEncode(_expenses.map((e) => e.toMap()).toList());
    await prefs.setString('capstone_expenses', encoded);
    await prefs.setStringList('custom_categories', _categories);
    await prefs.setStringList('custom_members', _members);
  }

  double get _totalSpent =>
      _expenses.fold(0.0, (sum, item) => sum + item.amount);

  double get _remainingBalance => _totalBudget - _totalSpent;

  double get _owedToMe {
    return _expenses
        .where((e) => !e.isReimbursed && e.paidBy == 'Me (Advance)')
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  Map<String, double> get _debtsToTeammates {
    final Map<String, double> debts = {};
    for (var expense in _expenses) {
      if (!expense.isReimbursed &&
          expense.paidBy != 'Direct Fund' &&
          expense.paidBy != 'Me (Advance)') {
        debts[expense.paidBy] = (debts[expense.paidBy] ?? 0.0) + expense.amount;
      }
    }
    return debts;
  }

  List<String> get _availableMonthYears {
    final Set<String> sets = {'All Time'};
    for (var exp in _expenses) {
      sets.add('${_getMonthName(exp.date.month)} ${exp.date.year}');
    }
    return sets.toList();
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  List<ExpenseItem> get _filteredAndSortedExpenses {
    var list = _expenses.where((e) {
      final matchesCategory = (_activeFilterCategory == 'All') ||
          (e.category == _activeFilterCategory);
      final matchesMember =
          (_activeFilterMember == 'All') || (e.paidBy == _activeFilterMember);
      final itemMonthYear =
          '${_getMonthName(e.date.month)} ${e.date.year}';
      final matchesMonth = (_selectedMonthYear == 'All Time') ||
          (itemMonthYear == _selectedMonthYear);

      return matchesCategory && matchesMember && matchesMonth;
    }).toList();

    list.sort((a, b) {
      return _sortNewestFirst
          ? b.date.compareTo(a.date)
          : a.date.compareTo(b.date);
    });

    return list;
  }

  void _addExpense(String title, double amount, String paidBy, String category, DateTime date) {
    setState(() {
      _expenses.insert(
        0,
        ExpenseItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          amount: amount,
          date: date,
          paidBy: paidBy,
          category: category,
          isReimbursed: paidBy == 'Direct Fund',
        ),
      );
    });
    _saveData();
  }

  void _toggleReimbursement(ExpenseItem item) {
    if (item.paidBy == 'Direct Fund') return;
    setState(() {
      item.isReimbursed = !item.isReimbursed;
    });
    _saveData();
  }

  void _confirmDeleteExpense(ExpenseItem item) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text(
          'Are you sure you want to remove "${item.title}" (₱${item.amount.toStringAsFixed(2)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dCtx);
              _deleteExpense(item);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteExpense(ExpenseItem item) {
    final index = _expenses.indexOf(item);
    if (index == -1) return;

    setState(() {
      _expenses.removeAt(index);
    });
    _saveData();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${item.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _expenses.insert(index, item);
            });
            _saveData();
          },
        ),
      ),
    );
  }

  void _promptAddCategory(StateSetter setModalState, Function(String) onAdded) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newCat = textController.text.trim();
              if (newCat.isNotEmpty && !_categories.contains(newCat)) {
                setState(() {
                  _categories.add(newCat);
                });
                setModalState(() {});
                _saveData();
                onAdded(newCat);
              }
              Navigator.pop(dCtx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(
    String category,
    StateSetter setModalState,
    Function(String) onCategoryUpdated,
  ) {
    final int usageCount =
        _expenses.where((e) => e.category == category).length;

    if (usageCount > 0) {
      showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
          title: const Text('Cannot Delete Category'),
          content: Text(
            'Cannot delete "$category" because $usageCount recorded expense(s) are using it.\n\nPlease delete or reassign those expenses first.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "$category"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dCtx);
              setState(() {
                _categories.remove(category);
                if (_activeFilterCategory == category) {
                  _activeFilterCategory = 'All';
                }
              });
              setModalState(() {
                onCategoryUpdated(
                    _categories.isNotEmpty ? _categories.first : 'General');
              });
              _saveData();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _promptAddMember(StateSetter setModalState, Function(String) onAdded) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Add Team Member'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newMember = textController.text.trim();
              if (newMember.isNotEmpty && !_members.contains(newMember)) {
                setState(() {
                  _members.add(newMember);
                });
                setModalState(() {});
                _saveData();
                onAdded(newMember);
              }
              Navigator.pop(dCtx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMember(
    String member,
    StateSetter setModalState,
    String currentSelectedPayer,
  ) {
    final int usageCount =
        _expenses.where((e) => e.paidBy == member).length;

    if (usageCount > 0) {
      showDialog(
        context: context,
        builder: (dCtx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
          title: const Text('Cannot Remove Member'),
          content: Text(
            'Cannot remove "$member" because they are listed as the payer for $usageCount recorded expense(s).\n\nPlease delete those records first.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Remove "$member" from your team list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dCtx);
              setState(() {
                _members.remove(member);
                if (_activeFilterMember == member) {
                  _activeFilterMember = 'All';
                }
              });
              setModalState(() {});
              _saveData();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _openAddExpenseModal() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String selectedPayer = _members.first;
    String selectedCategory = _categories.isNotEmpty ? _categories.first : 'General';
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Capstone Expense',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                        labelText: 'Item or Purpose (e.g. Acrylic, Sensor)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date Picker in Modal
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month),
                      title: Text(
                        'Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _promptAddCategory(setModalState, (newCat) {
                              setModalState(() {
                                selectedCategory = newCat;
                              });
                            });
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New Category'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _categories.contains(selectedCategory)
                          ? selectedCategory
                          : (_categories.isNotEmpty ? _categories.first : 'General'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(cat),
                              if (_categories.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: Colors.redAccent),
                                  tooltip: 'Delete Category',
                                  onPressed: () {
                                    _confirmDeleteCategory(
                                      cat,
                                      setModalState,
                                      (updatedCat) {
                                        selectedCategory = updatedCat;
                                      },
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedCategory = val);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Members Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Who paid for this?',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _promptAddMember(setModalState, (newMember) {
                              setModalState(() {
                                selectedPayer = newMember;
                              });
                            });
                          },
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Add Member'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _members.map((payer) {
                        final isSelected = selectedPayer == payer;
                        final bool isProtectedPayer =
                            (payer == 'Direct Fund' || payer == 'Me (Advance)');

                        return InputChip(
                          label: Text(payer),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedPayer = payer);
                            }
                          },
                          onDeleted: (!isProtectedPayer)
                              ? () {
                                  _confirmDeleteMember(
                                    payer,
                                    setModalState,
                                    selectedPayer,
                                  );
                                }
                              : null,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          final double? amount =
                              double.tryParse(amountController.text);
                          final String title = titleController.text.trim();

                          if (amount == null || amount <= 0 || title.isEmpty) {
                            return;
                          }
                          _addExpense(
                            title,
                            amount,
                            selectedPayer,
                            selectedCategory,
                            selectedDate,
                          );
                          Navigator.pop(ctx);
                        },
                        child: const Text('Save Expense'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('hardware') || lower.contains('component')) {
      return Icons.memory;
    } else if (lower.contains('print') || lower.contains('doc')) {
      return Icons.print;
    } else if (lower.contains('tool') || lower.contains('material')) {
      return Icons.build;
    } else if (lower.contains('food') || lower.contains('meeting')) {
      return Icons.fastfood;
    }
    return Icons.receipt_long;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double progress = (_totalBudget > 0)
        ? (_totalSpent / _totalBudget).clamp(0.0, 1.0)
        : 0.0;
    final bool isOverBudget = _remainingBalance < 0;
    final displayedList = _filteredAndSortedExpenses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capstone Project Budget'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: widget.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Adjust Budget Pool',
            onPressed: () {
              final budgetController =
                  TextEditingController(text: _totalBudget.toStringAsFixed(0));
              showDialog(
                context: context,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Set Total Capstone Budget'),
                  content: TextField(
                    controller: budgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixText: '₱ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final val = double.tryParse(budgetController.text);
                        if (val != null) {
                          setState(() => _totalBudget = val);
                          _saveData();
                        }
                        Navigator.pop(dCtx);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Budget Summary Card
          Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                            'Remaining Balance',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱ ${_remainingBalance.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isOverBudget
                                      ? Colors.redAccent
                                      : (isDark
                                          ? Colors.indigo.shade200
                                          : Theme.of(context).colorScheme.primary),
                                ),
                          ),
                        ],
                      ),
                      Chip(
                        label: Text(
                          'Pool: ₱ ${_totalBudget.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      color: isOverBudget
                          ? Colors.redAccent
                          : (isDark ? Colors.indigoAccent : Colors.indigo),
                      backgroundColor:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Spent: ₱ ${_totalSpent.toStringAsFixed(2)}'),
                      Text('${(progress * 100).toStringAsFixed(1)}% burned'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Banner 1: Blue Card - ONLY for Me (Advance)
          if (_owedToMe > 0)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet,
                            color: isDark ? Colors.lightBlueAccent : Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'To Collect for Yourself:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.lightBlue.shade100 : Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₱ ${_owedToMe.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.lightBlueAccent : Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Banner 2: Amber Card - For actual teammates
          if (_debtsToTeammates.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: isDark ? const Color(0xFF33200D) : Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pending_actions,
                            size: 20, color: isDark ? Colors.amberAccent : Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Debts to Repay Teammates',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber.shade100 : Colors.brown,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._debtsToTeammates.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pay ${entry.key}:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey.shade300 : Colors.black87,
                              ),
                            ),
                            Text(
                              '₱ ${entry.value.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amberAccent : Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          // Month Dropdown + Date Sort Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isDense: true,
                        value: _availableMonthYears.contains(_selectedMonthYear)
                            ? _selectedMonthYear
                            : 'All Time',
                        items: _availableMonthYears.map((month) {
                          return DropdownMenuItem(
                            value: month,
                            child: Text(month, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMonthYear = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: Icon(
                    _sortNewestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 16,
                  ),
                  label: Text(_sortNewestFirst ? 'Newest' : 'Oldest'),
                  onPressed: () {
                    setState(() {
                      _sortNewestFirst = !_sortNewestFirst;
                    });
                  },
                ),
              ],
            ),
          ),

          // Filter by Member Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                const Text('Payer: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ...['All', ..._members].map((member) {
                  final isSelected = _activeFilterMember == member;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(member, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      onSelected: (selected) {
                        setState(() {
                          _activeFilterMember = selected ? member : 'All';
                        });
                      },
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // Filter by Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                const Text('Category: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ...['All', ..._categories].map((category) {
                  final isSelected = _activeFilterCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(category, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      onSelected: (selected) {
                        setState(() {
                          _activeFilterCategory = selected ? category : 'All';
                        });
                      },
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // Header for List
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Audit Trail',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '${displayedList.length} items',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Expense List
          Expanded(
            child: displayedList.isEmpty
                ? Center(
                    child: Text(
                      _expenses.isEmpty
                          ? 'No expenses recorded yet.\nTap + to add your first purchase.'
                          : 'No expenses match the current filter/month.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: displayedList.length,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemBuilder: (context, index) {
                      final item = displayedList[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Delete Expense?'),
                              content: Text('Remove "${item.title}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          color: Colors.red.shade400,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteExpense(item),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: item.paidBy == 'Direct Fund'
                                ? (isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade100)
                                : (item.isReimbursed
                                    ? (isDark ? Colors.green.shade900 : Colors.green.shade100)
                                    : (isDark ? Colors.indigo.shade900 : Colors.indigo.shade50)),
                            child: Icon(
                              item.paidBy == 'Direct Fund'
                                  ? Icons.account_balance
                                  : (item.isReimbursed
                                      ? Icons.check
                                      : _getCategoryIcon(item.category)),
                              color: item.paidBy == 'Direct Fund'
                                  ? (isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade800)
                                  : (item.isReimbursed
                                      ? (isDark ? Colors.greenAccent : Colors.green)
                                      : (isDark ? Colors.indigo.shade200 : Colors.indigo)),
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item.category} • ${item.paidBy} • ${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.black54,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₱ ${item.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (item.paidBy != 'Direct Fund')
                                IconButton(
                                  icon: Icon(
                                    item.isReimbursed
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: item.isReimbursed
                                        ? (isDark ? Colors.greenAccent : Colors.green)
                                        : Colors.grey,
                                  ),
                                  tooltip: item.isReimbursed
                                      ? 'Reimbursed (Settled)'
                                      : 'Mark as Reimbursed',
                                  onPressed: () => _toggleReimbursement(item),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Icon(
                                    Icons.account_balance,
                                    size: 20,
                                    color: isDark ? Colors.blueGrey.shade400 : Colors.blueGrey,
                                  ),
                                ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 20,
                                    color: isDark ? Colors.white38 : Colors.black45),
                                tooltip: 'Delete Expense',
                                onPressed: () => _confirmDeleteExpense(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpenseModal,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}