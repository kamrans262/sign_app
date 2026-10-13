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
      // Long labels may wrap on 320dp phones; allow a second line.
      height: MediaQuery.sizeOf(context).width < 360 ? 80 : 65,
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 24,
            right: 24,
            child: Row(children: [
              Expanded(child: Container(
                key: const Key('wizard-connector-0'),
                height: 1,
                color: currentStep >= 1
                    ? AppColors.primary : AppColors.lightBorder,
              )),
              Expanded(child: Container(
                key: const Key('wizard-connector-1'),
                height: 1,
                color: currentStep >= 2
                    ? AppColors.primary : AppColors.lightBorder,
              )),
            ]),
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
