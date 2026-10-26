import 'package:flutter/widgets.dart';

/// Closes the keyboard when the user touches anywhere outside the focused
/// text field.
///
/// Flutter's default only does this for a mouse or stylus: on a phone a
/// touch outside leaves the field focused. Android users can still close the
/// keyboard with Back, but iOS has no Back, so the keyboard stayed up for
/// good. Overriding [EditableTextTapOutsideIntent] here (in
/// `MaterialApp.builder`) covers every text field in the app. The field's
/// own selection toolbar sits in its tap region, so using it does not count
/// as outside.
class DismissKeyboardOnTapOutside extends StatelessWidget {
  const DismissKeyboardOnTapOutside({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
              onInvoke: (intent) {
                intent.focusNode.unfocus();
                return null;
              },
            ),
      },
      child: child,
    );
  }
}
