import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

/// Localizes only known fixed labels while retaining all original styling,
/// keys, interactions, form controls, layout and exact result values.
/// Never translates user-entered text or business data without a catalog match.
abstract final class Sign2DigitalModalCopy {
  static Widget render(BuildContext context, Widget source) {
    if (source is Text && source.data != null) {
      final translated = AppStrings.of(context).tr(source.data!);
      if (translated == source.data) return source;
      return Text(translated,
        key: source.key,
        style: source.style,
        strutStyle: source.strutStyle,
        textAlign: source.textAlign,
        textDirection: source.textDirection,
        locale: source.locale,
        softWrap: source.softWrap,
        overflow: source.overflow,
        textScaler: source.textScaler,
        maxLines: source.maxLines,
        semanticsLabel: source.semanticsLabel == null ? null
            : AppStrings.of(context).tr(source.semanticsLabel!),
        textWidthBasis: source.textWidthBasis,
        textHeightBehavior: source.textHeightBehavior,
        selectionColor: source.selectionColor,
      );
    }
    if (source is Column) {
      return Column(key: source.key,
        mainAxisAlignment: source.mainAxisAlignment,
        mainAxisSize: source.mainAxisSize,
        crossAxisAlignment: source.crossAxisAlignment,
        textDirection: source.textDirection,
        verticalDirection: source.verticalDirection,
        textBaseline: source.textBaseline,
        spacing: source.spacing,
        children: [for (final child in source.children) render(context, child)]);
    }
    if (source is Row) {
      return Row(key: source.key,
        mainAxisAlignment: source.mainAxisAlignment,
        mainAxisSize: source.mainAxisSize,
        crossAxisAlignment: source.crossAxisAlignment,
        textDirection: source.textDirection,
        verticalDirection: source.verticalDirection,
        textBaseline: source.textBaseline,
        spacing: source.spacing,
        children: [for (final child in source.children) render(context, child)]);
    }
    if (source is Padding) return Padding(key:source.key,padding:source.padding,
      child: source.child == null ? null : render(context,source.child!));
    if (source is Align && source.runtimeType == Align) {
      return Align(key:source.key,alignment:source.alignment,widthFactor:source.widthFactor,
        heightFactor:source.heightFactor,
        child:source.child==null?null:render(context,source.child!));
    }
    if (source is Center) {
      return Center(key:source.key,widthFactor:source.widthFactor,
        heightFactor:source.heightFactor,
        child:source.child==null?null:render(context,source.child!));
    }
    if (source is SizedBox) return SizedBox(key:source.key,
      width:source.width,height:source.height,
      child:source.child==null?null:render(context,source.child!));
    if (source is Expanded) return Expanded(key:source.key,flex:source.flex,
      child:render(context,source.child));
    if (source is Flexible) return Flexible(key:source.key,flex:source.flex,
      fit:source.fit,child:render(context,source.child));
    return source;
  }
}
