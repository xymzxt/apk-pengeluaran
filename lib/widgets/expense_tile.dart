/// Baris item pengeluaran (dipakai riwayat & "pengeluaran terakhir"
/// di dashboard) — v1.0.0.
library;

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import '../utils/formatters.dart';
import '../utils/icon_map.dart';

class ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final CategoryModel? category;
  final VoidCallback? onTap;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        IconMap.colorFromHex(category?.colorHex, fallback: Colors.grey);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(IconMap.of(category?.iconKey),
                    color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${expense.date} • ${expense.time} • '
                      '${AppConstants.paymentLabel(expense.method)}'
                      '${category != null ? ' • ${category!.name}' : ''}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (expense.photoLocal != null ||
                  expense.photoRemote != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.receipt_rounded,
                    size: 16, color: theme.hintColor),
              ],
              const SizedBox(width: 8),
              Text(
                Formatters.currency(expense.nominal),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
