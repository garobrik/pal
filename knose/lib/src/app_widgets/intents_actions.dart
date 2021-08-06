import 'package:flutter/widgets.dart';

class NewNodeBelowIntent extends Intent {
  const NewNodeBelowIntent();
}

typedef NewNodeBelowAction = CallbackAction<NewNodeBelowIntent>;

class ConfigureNodeViewIntent extends Intent {
  const ConfigureNodeViewIntent();
}
