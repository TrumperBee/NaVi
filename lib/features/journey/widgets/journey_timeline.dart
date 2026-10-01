import 'package:flutter/material.dart';
import 'package:navi_app/core/constants.dart';
import 'package:navi_app/features/journey/models/journey_models.dart';

class JourneyTimeline extends StatelessWidget {
  final List<TimelineItem> items;
  final bool highContrast;

  const JourneyTimeline({
    super.key,
    required this.items,
    this.highContrast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemBuilder: (context, index) {
        return _TimelineRow(
          item: items[index],
          isFirst: index == 0,
          isLast: index == items.length - 1,
          highContrast: highContrast,
        );
      },
    );
  }
}

IconData _iconFromName(String name) {
  switch (name) {
    case 'directions_walk':
      return Icons.directions_walk;
    case 'directions_bus':
      return Icons.directions_bus;
    case 'flag':
      return Icons.flag;
    case 'check_circle':
      return Icons.check_circle;
    case 'location_on':
    default:
      return Icons.location_on;
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineItem item;
  final bool isFirst;
  final bool isLast;
  final bool highContrast;

  const _TimelineRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.highContrast,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.status == TimelineItemStatus.completed;
    final isCurrent = item.status == TimelineItemStatus.current;

    final nodeColor = isCompleted
        ? AppConstants.nairobiGreen
        : isCurrent
            ? AppConstants.nairobiGreen
            : highContrast ? Colors.grey[700] : Colors.grey[400];

    final bgColor = isCompleted
        ? AppConstants.nairobiGreen
        : isCurrent
            ? Colors.white
            : highContrast ? Colors.grey[300] : Colors.grey[200];

    final textColor = isCompleted
        ? Colors.grey[600]
        : isCurrent
            ? Colors.black
            : highContrast ? Colors.grey[700] : Colors.grey[500];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: nodeColor?.withValues(alpha: 0.4),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
                Container(
                  width: isCurrent ? 28 : 24,
                  height: isCurrent ? 28 : 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? nodeColor : bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: nodeColor ?? Colors.grey,
                      width: isCurrent ? 3 : 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : Icon(
                            _iconFromName(item.iconName),
                            size: isCurrent ? 14 : 12,
                            color: isCurrent
                                ? AppConstants.nairobiGreen
                                : nodeColor,
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted
                          ? AppConstants.nairobiGreen.withValues(alpha: 0.4)
                          : Colors.grey[300],
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isCurrent ? 4 : 5,
                bottom: isLast ? 4 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: highContrast ? 16 : 14,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: highContrast ? 13 : 12,
                        color: highContrast ? Colors.grey[700] : Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppConstants.nairobiGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'NOW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.nairobiGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
