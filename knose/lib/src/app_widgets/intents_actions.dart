import 'package:flutter/widgets.dart';

class NewNodeBelowIntent extends Intent {
  const NewNodeBelowIntent();
}

class DeleteNodeIntent extends Intent {
  const DeleteNodeIntent();
}

typedef NewNodeBelowAction = CallbackAction<NewNodeBelowIntent>;

class ConfigureNodeViewIntent extends Intent {
  const ConfigureNodeViewIntent();
}
