import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A widget that uses a delegate to size and position multiple children.
///
/// This is an alternative version of the [CustomMultiChildLayout] widget that
/// allows the delegate to determine the size of the parent widget.
///
/// It also relaxes some of the requirements of the [CustomMultiChildLayout],
/// for example children can be laid out more than once in the same layout
/// pass.
class SizedCustomMultiChildLayout extends MultiChildRenderObjectWidget {
  /// Creates a custom multi-child layout.
  const SizedCustomMultiChildLayout({
    super.key,
    required this.delegate,
    super.children,
  });

  /// The delegate that controls the layout of the children.
  final SizedMultiChildLayoutDelegate delegate;

  @override
  RenderSizedCustomMultiChildLayoutBox createRenderObject(
      BuildContext context) {
    return RenderSizedCustomMultiChildLayoutBox(delegate: delegate);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSizedCustomMultiChildLayoutBox renderObject) {
    renderObject.delegate = delegate;
  }
}

/// A delegate that controls the layout of multiple children.
///
/// Conceptually similar to [MultiChildLayoutDelegate], but with the ability to
/// determine the size of the parent widget.
abstract class SizedMultiChildLayoutDelegate {
  /// Creates a layout delegate.
  ///
  /// The layout will update whenever [relayout] notifies its listeners.
  SizedMultiChildLayoutDelegate({Listenable? relayout}) : _relayout = relayout;

  final Listenable? _relayout;

  bool hasChild(Object childId) => _idToChild![childId] != null;

  Size layoutChild(Object childId, BoxConstraints constraints) {
    final RenderBox? child = _idToChild![childId];
    assert(() {
      if (child == null) {
        throw FlutterError(
          'The $this custom multichild layout delegate tried to lay out a non-existent child.\n'
          'There is no child with the id "$childId".',
        );
      }
      _debugChildrenNeedingLayout!.remove(child);
      try {
        assert(constraints.debugAssertIsValid(isAppliedConstraint: true));
        // ignore: avoid_catching_errors
      } on AssertionError catch (exception) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'The $this custom multichild layout delegate provided invalid box constraints for the child with id "$childId".'),
          DiagnosticsProperty<AssertionError>('Exception', exception,
              showName: false),
          ErrorDescription(
            'The minimum width and height must be greater than or equal to zero.\n'
            'The maximum width must be greater than or equal to the minimum width.\n'
            'The maximum height must be greater than or equal to the minimum height.',
          ),
        ]);
      }
      return true;
    }());
    if (_isDryLayout) {
      return child!.getDryLayout(constraints);
    } else {
      child!.layout(constraints, parentUsesSize: true);
      return child.size;
    }
  }

  void positionChild(Object childId, Offset offset) {
    final RenderBox? child = _idToChild![childId];
    assert(() {
      if (child == null) {
        throw FlutterError(
          'The $this custom multichild layout delegate tried to position out a non-existent child:\n'
          'There is no child with the id "$childId".',
        );
      }
      _debugChildrenNeedingPositioning!.remove(child);
      return true;
    }());
    if (!_isDryLayout) {
      final MultiChildLayoutParentData childParentData =
          child!.parentData! as MultiChildLayoutParentData;
      childParentData.offset = offset;
    }
  }

  /// Override this method to include additional information in the
  /// debugging data printed by [debugDumpRenderTree] and friends.
  ///
  /// By default, returns the [runtimeType] of the class.
  @override
  String toString() => objectRuntimeType(this, 'MultiChildLayoutDelegate');

  //
  //
  //

  Set<RenderBox>? _debugChildrenNeedingLayout;
  Set<RenderBox>? _debugChildrenNeedingPositioning;

  bool get isDryLayout => _isDryLayout;
  bool _isDryLayout = false;

  Size performLayout(BoxConstraints constraints);

  bool shouldRelayout(covariant SizedMultiChildLayoutDelegate oldDelegate);

  Map<Object, RenderBox>? _idToChild;

  T _runLayout<T>(RenderBox? firstChild, T Function() cb) {
    final previousIdToChild = _idToChild;
    Set<RenderBox>? previousChildrenNeedingLayout;
    Set<RenderBox>? previousChildrenNeedingPositioning;

    assert(() {
      previousChildrenNeedingLayout = _debugChildrenNeedingLayout;
      previousChildrenNeedingPositioning = _debugChildrenNeedingPositioning;
      _debugChildrenNeedingLayout = <RenderBox>{};
      _debugChildrenNeedingPositioning = <RenderBox>{};
      return true;
    }());
    _idToChild = <Object, RenderBox>{};

    try {
      RenderBox? child = firstChild;
      while (child != null) {
        final MultiChildLayoutParentData childParentData =
            child.parentData! as MultiChildLayoutParentData;
        assert(() {
          if (childParentData.id == null) {
            throw FlutterError.fromParts(<DiagnosticsNode>[
              ErrorSummary(
                  'Every child of a RenderSizedCustomMultiChildLayoutBox must have an ID in its parent data.'),
              child!.describeForError('The following child has no ID'),
            ]);
          }
          if (!_isDryLayout) {
            _debugChildrenNeedingLayout!.add(child!);
            _debugChildrenNeedingPositioning!.add(child);
          }
          return true;
        }());
        _idToChild![childParentData.id!] = child;
        child = childParentData.nextSibling;
      }
      final res = cb();
      assert(() {
        if (_debugChildrenNeedingLayout!.isNotEmpty) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Each child must be laid out at least once.'),
            DiagnosticsBlock(
              name: 'The $this custom multichild layout delegate forgot '
                  'to lay out the following '
                  '${_debugChildrenNeedingLayout!.length > 1 ? 'children' : 'child'}',
              properties: _debugChildrenNeedingLayout!
                  .map<DiagnosticsNode>(_debugDescribeChild)
                  .toList(),
            ),
          ]);
        }
        if (_debugChildrenNeedingPositioning!.isNotEmpty) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Each child must be positioned at least once.'),
            DiagnosticsBlock(
              name: 'The $this custom multichild layout delegate forgot '
                  'to position the following '
                  '${_debugChildrenNeedingPositioning!.length > 1 ? 'children' : 'child'}',
              properties: _debugChildrenNeedingPositioning!
                  .map<DiagnosticsNode>(_debugDescribeChild)
                  .toList(),
            ),
          ]);
        }
        return true;
      }());
      return res;
    } finally {
      _idToChild = previousIdToChild;
      assert(() {
        _debugChildrenNeedingLayout = previousChildrenNeedingLayout;
        _debugChildrenNeedingPositioning = previousChildrenNeedingPositioning;
        return true;
      }());
    }
  }

  DiagnosticsNode _debugDescribeChild(RenderBox child) {
    final MultiChildLayoutParentData childParentData =
        child.parentData! as MultiChildLayoutParentData;
    return DiagnosticsProperty<RenderBox>('${childParentData.id}', child);
  }

  Size _callPerformLayout(BoxConstraints constraints, RenderBox? firstChild) {
    return _runLayout(firstChild, () {
      return performLayout(constraints);
    });
  }

  Size _getSize(BoxConstraints constraints, RenderBox? firstChild) {
    return _runLayout(firstChild, () {
      final previousDryLayout = _isDryLayout;
      _isDryLayout = true;
      final Size result = performLayout(constraints);
      _isDryLayout = previousDryLayout;
      return result;
    });
  }
}

/// Defers the layout of multiple children to a delegate.
///
/// The delegate can determine the layout constraints for each child and can
/// decide where to position each child.
class RenderSizedCustomMultiChildLayoutBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  /// Creates a render object that customizes the layout of multiple children.
  RenderSizedCustomMultiChildLayoutBox({
    List<RenderBox>? children,
    required SizedMultiChildLayoutDelegate delegate,
  }) : _delegate = delegate {
    addAll(children);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = MultiChildLayoutParentData();
    }
  }

  /// The delegate that controls the layout of the children.
  SizedMultiChildLayoutDelegate get delegate => _delegate;
  SizedMultiChildLayoutDelegate _delegate;
  set delegate(SizedMultiChildLayoutDelegate newDelegate) {
    if (_delegate == newDelegate) {
      return;
    }
    final SizedMultiChildLayoutDelegate oldDelegate = _delegate;
    if (newDelegate.runtimeType != oldDelegate.runtimeType ||
        newDelegate.shouldRelayout(oldDelegate)) {
      markNeedsLayout();
    }
    _delegate = newDelegate;
    if (attached) {
      oldDelegate._relayout?.removeListener(markNeedsLayout);
      newDelegate._relayout?.addListener(markNeedsLayout);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _delegate._relayout?.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _delegate._relayout?.removeListener(markNeedsLayout);
    super.detach();
  }

  Size _getSize(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    return constraints.constrain(_delegate._getSize(
      constraints,
      firstChild,
    ));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final double width =
        _getSize(BoxConstraints.tightForFinite(height: height)).width;
    if (width.isFinite) {
      return width;
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final double width =
        _getSize(BoxConstraints.tightForFinite(height: height)).width;
    if (width.isFinite) {
      return width;
    }
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final double height =
        _getSize(BoxConstraints.tightForFinite(width: width)).height;
    if (height.isFinite) {
      return height;
    }
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final double height =
        _getSize(BoxConstraints.tightForFinite(width: width)).height;
    if (height.isFinite) {
      return height;
    }
    return 0.0;
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return _getSize(constraints);
  }

  @override
  void performLayout() {
    size = delegate._callPerformLayout(constraints, firstChild);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
