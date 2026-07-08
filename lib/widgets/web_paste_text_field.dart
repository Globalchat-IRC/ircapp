import 'package:flutter/material.dart';

import '../utils/platform_utils.dart';
import '../utils/web_text_input.dart';

/// TextField con Ctrl/Cmd+V funcional en web.
class WebPasteTextField extends StatefulWidget {
  const WebPasteTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.decoration,
    this.style,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled,
    this.autofocus = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool readOnly;
  final bool? enabled;
  final bool autofocus;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;

  @override
  State<WebPasteTextField> createState() => _WebPasteTextFieldState();
}

class _WebPasteTextFieldState extends State<WebPasteTextField> {
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null &&
        (PlatformUtils.isWeb || PlatformUtils.isDesktop)) {
      _ownedFocusNode = FocusNode(onKeyEvent: _onKeyEvent);
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    return WebTextInput.handlePasteKey(
      event,
      widget.controller,
      hasFocus: node.hasFocus,
    );
  }

  @override
  void dispose() {
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode ?? _ownedFocusNode,
      decoration: widget.decoration,
      style: widget.style,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      obscureText: widget.obscureText,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
    );
  }
}
