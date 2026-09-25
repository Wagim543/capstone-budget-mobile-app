import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/capstone_expense.dart';
import '../main.dart'; // import global themeNotifier

class CapstoneScreen extends StatefulWidget {
  const CapstoneScreen({super.key});

  @override
  State<CapstoneScreen> createState() => _CapstoneScreenState();
}

class _CapstoneScreenState extends State<CapstoneScreen> {
  double _totalBudget = 9000.0;
  List<ExpenseItem> _expenses = [];
  bool _isLoading = true;
  String _activeFilterCategory = 'All';

  List<String> _categories = [
    'Hardware/Components',
    'Printing/Docs',
    'Tools/Materials',
    'Food/Meeting',
    'Miscellaneous',
  ];

  // Only real baseline options - no placeholder members
  List<String> _members = ['Me (Advance)', 'Direct Fund'];

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
        // Purge any old placeholder 'Member A' or 'Member B' from earlier runs
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

    // Save cleaned list back to disk
    await _saveData();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('capstone_budget', _totalBudget);
    final encoded = jsonEncode(_expenses.map((e) => e.toMap()).toList());
    await prefs.setString('capstone_expenses', encoded);
    await prefs.setStringList('custom_categories', _categories);
    await prefs.setStringList('custom_members', _members);
  }

  Future<void> _toggleAppTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark =
        themeNotifier.value == ThemeMode.dark ||
        (themeNotifier.value == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);

    final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
    themeNotifier.value = nextMode;
    await prefs.setString(
      'app_theme_mode',
      nextMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  double get _totalSpent =>
      _expenses.fold(0.0, (sum, item) => sum + item.amount);

  double get _remainingBalance => _totalBudget - _totalSpent;

  double get _owedToMe {
    return _expenses
        .where((e) => !e.isReimbursed && e.paidBy.toLowerCase().contains('me'))
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  Map<String, double> get _debtsToTeammates {
    final Map<String, double> debts = {};
    for (var expense in _expenses) {
      if (!expense.isReimbursed &&
          expense.paidBy != 'Direct Fund' &&
          !expense.paidBy.toLowerCase().contains('me')) {
        debts[expense.paidBy] = (debts[expense.paidBy] ?? 0.0) + expense.amount;
      }
    }
    return debts;
  }

  List<ExpenseItem> get _filteredExpenses {
    if (_activeFilterCategory == 'All') {
      return _expenses;
    }
    return _expenses.where((e) => e.category == _activeFilterCategory).toList();
  }

  Future<void> _addExpense(
    String title,
    double amount,
    String paidBy,
    String category,
  ) async {
    setState(() {
      _expenses.insert(
        0,
        ExpenseItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          amount: amount,
          date: DateTime.now(),
          paidBy: paidBy,
          category: category,
          isReimbursed: paidBy == 'Direct Fund',
        ),
      );
    });
    await _saveData();
  }

  Future<void> _toggleReimbursement(ExpenseItem item) async {
    if (item.paidBy == 'Direct Fund') return;
    setState(() {
      item.isReimbursed = !item.isReimbursed;
    });
    await _saveData();
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

  Future<void> _deleteExpense(ExpenseItem item) async {
    final index = _expenses.indexOf(item);
    if (index == -1) return;

    setState(() {
      _expenses.removeAt(index);
    });
    await _saveData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${item.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            setState(() {
              _expenses.insert(index, item);
            });
            await _saveData();
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
            onPressed: () async {
              final newCat = textController.text.trim();
              if (newCat.isNotEmpty && !_categories.contains(newCat)) {
                setState(() {
                  _categories.add(newCat);
                });
                setModalState(() {});
                await _saveData();
                onAdded(newCat);
              }
              if (dCtx.mounted) Navigator.pop(dCtx);
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
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'Are you sure you want to delete "$category"?\nExisting expenses under this category will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dCtx);
              setState(() {
                _categories.remove(category);
                if (_activeFilterCategory == category) {
                  _activeFilterCategory = 'All';
                }
              });
              setModalState(() {
                onCategoryUpdated(_categories.first);
              });
              await _saveData();
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
            labelText: 'Name (e.g. Dexter, John)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newMember = textController.text.trim();
              if (newMember.isNotEmpty && !_members.contains(newMember)) {
                setState(() {
                  _members.add(newMember);
                });
                setModalState(() {});
                await _saveData();
                onAdded(newMember);
              }
              if (dCtx.mounted) Navigator.pop(dCtx);
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
            onPressed: () async {
              Navigator.pop(dCtx);
              setState(() {
                _members.remove(member);
              });
              setModalState(() {});
              await _saveData();
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
    String selectedCategory = _categories.first;

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
                      style: Theme.of(context).textTheme.titleLarge
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
                        labelText: 'Item or Purpose (e.g. Acrylic, Sensor)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
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
                      initialValue: _categories.contains(selectedCategory)
      ? selectedCategory
      : _categories.first,
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
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Delete Category',
                                  onPressed: () {
                                    _confirmDeleteCategory(cat, setModalState, (
                                      updatedCat,
                                    ) {
                                      selectedCategory = updatedCat;
                                    });
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Who paid for this?',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
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
                          onDeleted: (_members.length > 1 && !isProtectedPayer)
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
                          final double? amount = double.tryParse(
                            amountController.text,
                          );
                          final String title = titleController.text.trim();

                          if (amount == null || amount <= 0 || title.isEmpty) {
                            return;
                          }
                          _addExpense(
                            title,
                            amount,
                            selectedPayer,
                            selectedCategory,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final double progress = (_totalBudget > 0)
        ? (_totalSpent / _totalBudget).clamp(0.0, 1.0)
        : 0.0;
    final bool isOverBudget = _remainingBalance < 0;
    final displayedList = _filteredExpenses;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capstone Project Budget'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: _toggleAppTheme,
          ),
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Adjust Budget Pool',
            onPressed: () {
              final budgetController = TextEditingController(
                text: _totalBudget.toStringAsFixed(0),
              );
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
                      onPressed: () async {
                        final val = double.tryParse(budgetController.text);
                        if (val != null) {
                          setState(() => _totalBudget = val);
                          await _saveData();
                        }
                        if (dCtx.mounted) Navigator.pop(dCtx);
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
          Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                            'Remaining Balance',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱ ${_remainingBalance.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isOverBudget
                                      ? Colors.red
                                      : Theme.of(context).colorScheme.primary,
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
                      color: isOverBudget ? Colors.red : Colors.indigo,
                      backgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
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
          if (_owedToMe > 0)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: isDark ? Colors.blueGrey.shade900 : Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: isDark
                              ? Colors.lightBlueAccent
                              : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'To Collect for Yourself:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₱ ${_owedToMe.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark
                            ? Colors.lightBlueAccent
                            : Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_debtsToTeammates.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: isDark ? Colors.brown.shade900 : Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.pending_actions,
                          size: 20,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Debts to Repay Teammates',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.orange.shade200
                                : Colors.brown,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₱ ${entry.value.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['All', ..._categories].map((category) {
                final isSelected = _activeFilterCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _activeFilterCategory = category;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expense Audit Trail',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${displayedList.length} shown',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: displayedList.isEmpty
                ? Center(
                    child: Text(
                      _expenses.isEmpty
                          ? 'No expenses recorded yet.\nTap + to add your first purchase.'
                          : 'No expenses match the "$_activeFilterCategory" filter.',
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
                                    backgroundColor: Colors.red,
                                  ),
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
                                ? (isDark
                                      ? Colors.blueGrey.shade800
                                      : Colors.blueGrey.shade100)
                                : (item.isReimbursed
                                      ? (isDark
                                            ? Colors.green.shade900
                                            : Colors.green.shade100)
                                      : (isDark
                                            ? Colors.indigo.shade900
                                            : Colors.indigo.shade50)),
                            child: Icon(
                              item.paidBy == 'Direct Fund'
                                  ? Icons.account_balance
                                  : (item.isReimbursed
                                        ? Icons.check
                                        : _getCategoryIcon(item.category)),
                              color: item.paidBy == 'Direct Fund'
                                  ? (isDark
                                        ? Colors.white70
                                        : Colors.blueGrey.shade800)
                                  : (item.isReimbursed
                                        ? Colors.green
                                        : Colors.indigo),
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item.category} • ${item.paidBy} • ${item.date.month}/${item.date.day}',
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
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                  tooltip: item.isReimbursed
                                      ? 'Reimbursed (Settled)'
                                      : 'Mark as Reimbursed',
                                  onPressed: () => _toggleReimbursement(item),
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Icon(
                                    Icons.account_balance,
                                    size: 20,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.black45,
                                ),
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
