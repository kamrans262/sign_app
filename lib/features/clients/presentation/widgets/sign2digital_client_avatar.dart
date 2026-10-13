import 'package:flutter/material.dart';

import '../../../../core/theme/dashboard_colors.dart';
import '../../domain/client_profile.dart';

/// Shared client initials/logo presentation for details and list contexts.
class Sign2DigitalClientAvatar extends StatelessWidget {
  const Sign2DigitalClientAvatar({
    super.key,
    required this.client,
    this.diameter = 50,
  });

  final ClientProfile client;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: diameter / 2,
      backgroundColor: DashboardColors.paleBlue,
      backgroundImage: client.logoAsset == null
          ? null
          : AssetImage(client.logoAsset!),
      child: client.logoAsset == null
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                client.initials,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            )
          : null,
    );
  }
}
