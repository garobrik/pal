import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

TickerProvider useTickerProvider() => use(const _TickerProviderHook());

class _TickerProviderHook extends Hook<TickerProvider> {
  const _TickerProviderHook();

  @override
  HookState<TickerProvider, Hook<TickerProvider>> createState() => _TickerProviderHookState();
}

class _TickerProviderHookState extends HookState<TickerProvider, _TickerProviderHook>
    implements TickerProvider {
  Set<Ticker>? _tickers;

  @override
  TickerProvider build(BuildContext context) {
    final muted = !TickerMode.of(context);
    _tickers?.forEach((ticker) => ticker.muted = muted);
    return this;
  }

  @override
  Ticker createTicker(TickerCallback onTick) {
    _tickers ??= <_HookTicker>{};
    final _HookTicker result = _HookTicker(onTick, this, debugLabel: 'created by $this');
    _tickers!.add(result);
    return result;
  }

  void _removeTicker(_HookTicker ticker) {
    assert(_tickers != null);
    assert(_tickers!.contains(ticker));
    _tickers!.remove(ticker);
  }

  @override
  void dispose() {
    assert(() {
      if (_tickers != null) {
        for (final Ticker ticker in _tickers!) {
          if (ticker.isActive) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary('$this was disposed with an active Ticker.'),
              ErrorDescription(
                '${context.widget.runtimeType} created a Ticker via a TickerProviderHook, but at the time '
                'dispose() was called on the mixin, that Ticker was still active. All Tickers must '
                'be disposed before calling super.dispose().',
              ),
              ErrorHint(
                'Tickers used by AnimationControllers '
                'should be disposed by calling dispose() on the AnimationController itself. '
                'Otherwise, the ticker will leak.',
              ),
              ticker.describeForError('The offending ticker was'),
            ]);
          }
        }
      }
      return true;
    }());
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Set<Ticker>>(
      'tickers',
      _tickers,
      description: _tickers != null
          ? 'tracking ${_tickers!.length} ticker${_tickers!.length == 1 ? "" : "s"}'
          : null,
      defaultValue: null,
    ));
  }
}

class _HookTicker extends Ticker {
  _HookTicker(TickerCallback onTick, this._creator, {String? debugLabel})
      : super(onTick, debugLabel: debugLabel);

  final _TickerProviderHookState _creator;

  @override
  void dispose() {
    _creator._removeTicker(this);
    super.dispose();
  }
}
