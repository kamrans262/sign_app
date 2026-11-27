import 'package:flutter/material.dart';

import 'app_strings.dart';

/// A const-compatible label for literal UI copy only. Never pass user content,
/// document data, or persisted business values to this widget.
/// English uses the original Text build; translations preserve every text
/// configuration, including the existing overflow and scaling policy.
class LocalizedUiText extends Text {
  const LocalizedUiText(
    super.data, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final translated = strings.tr(data!);
    if (translated == data && semanticsLabel == null) {
      return super.build(context);
    }
    return Text(
      translated,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null ? null : strings.tr(semanticsLabel!),
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
