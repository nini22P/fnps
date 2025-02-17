import 'package:flutter/material.dart';

Future<void> showPopup({
  required BuildContext context,
  required Widget child,
}) async =>
    await Navigator.of(context).push(Popup(child: child));

Future<void> replacePopup({
  required BuildContext context,
  required Widget child,
}) async =>
    await Navigator.of(context).pushReplacement(Popup(child: child));

class Popup<T> extends PopupRoute<T> {
  Popup({required this.child});

  final Widget child;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    int size = screenWidth > 1200
        ? 3
        : screenWidth > 720
            ? 2
            : 1;

    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(onTap: () => Navigator.of(context).pop()),
          ),
          Align(
            alignment: size == 1 ? Alignment.topCenter : Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, -1.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubicEmphasized,
                    )),
                    child: child,
                  );
                },
                child: Card(
                  elevation: 5,
                  clipBehavior: Clip.hardEdge,
                  child: UnconstrainedBox(
                    child: LimitedBox(
                      maxWidth: screenWidth / size - (size == 1 ? 16 : 0),
                      maxHeight: screenHeight / 3 * 2,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: SingleChildScrollView(
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
