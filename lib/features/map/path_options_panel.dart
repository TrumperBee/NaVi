import 'package:flutter/material.dart';
import 'package:navi_app/core/constants.dart';
import 'package:navi_app/models/transport_models.dart';

class PathOptionsPanel extends StatelessWidget {
  final List<PathOption> pathOptions;
  final PathOption? selectedPath;
  final ValueChanged<PathOption> onSelectPath;

  const PathOptionsPanel({
    super.key,
    required this.pathOptions,
    required this.selectedPath,
    required this.onSelectPath,
  });

  @override
  Widget build(BuildContext context) {
    if (pathOptions.isEmpty || selectedPath == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 140,
      left: 16,
      right: 16,
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: pathOptions.length,
          itemBuilder: (context, index) {
            final option = pathOptions[index];
            final isSelected = selectedPath == option;

            return GestureDetector(
              onTap: () => onSelectPath(option),
              child: Container(
                width: 150,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppConstants.nairobiGreen : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppConstants.nairobiGreen
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          option.formattedTime,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 14,
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          option.formattedFare,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${option.transferCount} transfers',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
