import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared responsive three-step progress indicator for staged forms.
class Sign2DigitalWizardStepper extends StatelessWidget {
  const Sign2DigitalWizardStepper({
    super.key,
    required this.labels,
    required this.currentStep,
  }) : assert(labels.length == 3);

  final List<String> labels;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('site-report-stepper'),
      height: 65,
      child: Stack(
        children: [
          const Positioned(
            top: 12,
            left: 24,
            right: 24,
            child: Divider(height: 1, thickness: 1,
              color: AppColors.lightBorder),
          ),
          Row(children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(child: Align(
                alignment: index == 0
                    ? Alignment.topLeft
                    : index == labels.length - 1
                      ? Alignment.topRight
                      : Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      key: Key('wizard-step-$index'),
                      width: 24, height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index <= currentStep
                            ? AppColors.primary
                            : const Color(0xFFD1D5DB),
                      ),
                      child: index < currentStep
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 17)
                          : Text('${index + 1}', style: const TextStyle(
                              fontFamily: 'Inter', color: Colors.white,
                              fontWeight: FontWeight.w500, fontSize: 14,
                            )),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      labels[index],
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                        color: index == currentStep
                            ? AppColors.primary : AppColors.dark,
                      ),
                    ),
                  ],
                ),
              )),
          ]),
        ],
      ),
    );
  }
}
