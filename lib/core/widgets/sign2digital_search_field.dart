import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/dashboard_assets.dart';
import '../theme/app_colors.dart';

class Sign2DigitalSearchField extends StatelessWidget {
  const Sign2DigitalSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onTrailingTap,
    this.maxLength,
    this.hintText = 'Search jobs,clients, refrences',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onTrailingTap;
  final int? maxLength;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.lightBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 18, right: 12),
            child: Icon(Icons.search, color: AppColors.placeholder, size: 25),
          ),
          Expanded(
            child: TextField(
              key: const Key('clients-search-input'),
              controller: controller,
              onChanged: onChanged,
              inputFormatters: maxLength == null ? null :
                [LengthLimitingTextInputFormatter(maxLength)],
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.dark,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintMaxLines: 1,
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.placeholder,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              icon: const Icon(
                Icons.close,
                color: AppColors.secondaryText,
                size: 20,
              ),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            ),
          IconButton(
            tooltip: 'Search action',
            onPressed: onTrailingTap,
            icon: SvgPicture.asset(
              DashboardAssets.searchActionIcon,
              width: 24,
              height: 24,
              semanticsLabel: 'Search action',
            ),
          ),
          const SizedBox(width: 7),
        ],
      ),
    );
  }
}
