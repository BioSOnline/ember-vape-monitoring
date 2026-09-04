import 'package:flutter/material.dart';
import 'package:ember/core/config/supabase_config.dart';
import 'package:ember/core/constants/app_constants.dart';
import 'package:ember/core/theme/app_theme.dart';
import 'package:ember/models/puff_event.dart';
import 'package:ember/services/supabase_service.dart';
import 'package:uuid/uuid.dart';

class ManualEntryDialog extends StatefulWidget {
  final BuildContext? parentContext;
  const ManualEntryDialog({super.key, this.parentContext});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ManualEntryDialog(parentContext: context),
    );
  }

  @override
  State<ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<ManualEntryDialog> {
  final _service = SupabaseService();
  final _uuid = const Uuid();
  int _count = 1;
  DateTime _selectedTime = DateTime.now();
  bool _submitting = false;

  Future<void> _logPuff() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      bool success = true;
      for (int i = 0; i < _count; i++) {
        final event = PuffEvent(
          id: _uuid.v4(),
          userId: userId,
          detectedAt: _selectedTime.add(Duration(seconds: i)),
          inputMode: AppConstants.inputModeManual,
        );
        final inserted = await _service.insertPuffEvent(event);
        if (!inserted) success = false;
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logged $_count puff${_count > 1 ? 's' : ''} successfully'),
              backgroundColor: AppTheme.lowRiskColor,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save puff log'),
              backgroundColor: AppTheme.highRiskColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.highRiskColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedTime,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Log Usage Manually',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Record puffs taken outside camera detection',
            style: tt.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),

          // Count Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Number of Puffs',
                style: tt.titleMedium,
              ),
              Row(
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.remove),
                    onPressed: _count > 1 ? () => setState(() => _count--) : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$_count',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                    ),
                  ),
                  IconButton.outlined(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => _count++),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Time Selector
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Timestamp',
                        style: tt.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                      Text(
                        '${_selectedTime.day}/${_selectedTime.month}/${_selectedTime.year} at ${TimeOfDay.fromDateTime(_selectedTime).format(context)}',
                        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.edit, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          ElevatedButton(
            onPressed: _submitting ? null : _logPuff,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Save Log ($_count Puff${_count > 1 ? 's' : ''})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
