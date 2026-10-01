import 'package:flutter/material.dart';

class LocationStatus extends StatelessWidget {
  final bool hasLocation;
  final String streetName;

  const LocationStatus({
    super.key,
    required this.hasLocation,
    required this.streetName,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topInset + 70,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.my_location,
              color: hasLocation ? Colors.blue : Colors.grey,
              size: 16,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                streetName,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
