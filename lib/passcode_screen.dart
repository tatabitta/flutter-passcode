library passcode_screen;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:passcode_screen/circle.dart';
import 'package:passcode_screen/keyboard.dart';
import 'package:passcode_screen/shake_curve.dart';
import 'package:flutter/foundation.dart';

typedef PasswordEnteredCallback = void Function(String text);
typedef IsValidCallback = void Function();
typedef CancelCallback = void Function();

class PasscodeScreen extends StatefulWidget {
  final Widget title;
  final int passwordDigits;
  final PasswordEnteredCallback passwordEnteredCallback;
  // Cancel button and delete button will be switched based on the screen state
  final Widget cancelButton;
  final Widget deleteButton;
  final Widget? bioButton;
  final Stream<bool> shouldTriggerVerification;
  final CircleUIConfig circleUIConfig;
  final KeyboardUIConfig keyboardUIConfig;

  //isValidCallback will be invoked after passcode screen will pop.
  final IsValidCallback? isValidCallback;
  final CancelCallback? cancelCallback;

  final Color? backgroundColor;
  final Widget? bottomWidget;
  final List<String>? digits;

  PasscodeScreen({
    Key? key,
    required this.title,
    this.passwordDigits = 6,
    required this.passwordEnteredCallback,
    required this.cancelButton,
    required this.deleteButton,
    required this.shouldTriggerVerification,
    this.isValidCallback,
    CircleUIConfig? circleUIConfig,
    KeyboardUIConfig? keyboardUIConfig,
    this.bottomWidget,
    this.backgroundColor,
    this.cancelCallback,
    this.bioButton,
    this.digits,
  })  : circleUIConfig = circleUIConfig ?? const CircleUIConfig(),
        keyboardUIConfig = keyboardUIConfig ?? const KeyboardUIConfig(),
        super(key: key);

  @override
  State<StatefulWidget> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<bool> streamSubscription;
  String enteredPasscode = '';
  late AnimationController controller;
  late Animation<double> animation;

  @override
  initState() {
    super.initState();
    streamSubscription = widget.shouldTriggerVerification
        .listen((isValid) => _showValidation(isValid));
    controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    final Animation curve =
    CurvedAnimation(parent: controller, curve: ShakeCurve());
    animation = Tween(begin: 0.0, end: 10.0).animate(curve as Animation<double>)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            enteredPasscode = '';
            controller.value = 0;
          });
        }
      })
      ..addListener(() {
        setState(() {
          // the animation object’s value is the changed state
        });
      });
  }

  @override
  Widget build(BuildContext context) {
    if ( kIsWeb ) {
      return _buildPortraitPasscodeScreen();
    }

    return Scaffold(
      backgroundColor: widget.backgroundColor ?? Colors.black.withOpacity(0.8),
      body: SafeArea(
        child: _buildPortraitPasscodeScreen()
      ),
    );
  }

  _buildPortraitPasscodeScreen() => Stack(
    children: [
      Positioned(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.title,
              Container(
                margin: const EdgeInsets.only(top: 20),
                height: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _buildCircles(),
                ),
              ),
              _buildKeyboard(),
              widget.bottomWidget ?? Container(),
            ],
          ),
        ),
      ),
    ],
  );

  _buildKeyboard() {
    final runSpacing = 4;
    final columns = 3;
    final primarySize = (MediaQuery.of(context).size.height / 2) * .75;
    final itemSize = (primarySize - runSpacing * (columns - 1)) / columns;
    return Container(
      child: Keyboard(
          onKeyboardTap: _onKeyboardButtonPressed,
          keyboardUIConfig: widget.keyboardUIConfig,
          digits: widget.digits,
          actionButtons: Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                        height: itemSize,
                        width: itemSize,
                        child: Center(
                          child: widget.bioButton != null ? widget.bioButton! : Container(),
                        )
                    ),
                    Container(
                        width: itemSize,
                        height: itemSize,
                        child: Center(
                            child: _buildDeleteButton()
                        )
                    )
                  ],
                ),
              ),
            ),
          )
      ),
    );
  }

  List<Widget> _buildCircles() {
    var list = <Widget>[];
    var config = widget.circleUIConfig;
    var extraSize = animation.value;
    for (int i = 0; i < widget.passwordDigits; i++) {
      list.add(
        Container(
          margin: EdgeInsets.all(8),
          child: Circle(
            filled: i < enteredPasscode.length,
            circleUIConfig: config,
            extraSize: extraSize,
          ),
        ),
      );
    }
    return list;
  }

  _onDeleteCancelButtonPressed() {
    if (enteredPasscode.length > 0) {
      setState(() {
        enteredPasscode =
            enteredPasscode.substring(0, enteredPasscode.length - 1);
      });
    } else {
      if (widget.cancelCallback != null) {
        widget.cancelCallback!();
      }
    }
  }

  _onKeyboardButtonPressed(String text) {
    if (text == Keyboard.deleteButton) {
      _onDeleteCancelButtonPressed();
      return;
    }
    setState(() {
      if (enteredPasscode.length < widget.passwordDigits) {
        enteredPasscode += text;
        if (enteredPasscode.length == widget.passwordDigits) {
          widget.passwordEnteredCallback(enteredPasscode);
        }
      }
    });
  }

  @override
  didUpdateWidget(PasscodeScreen old) {
    super.didUpdateWidget(old);
    // in case the stream instance changed, subscribe to the new one
    if (widget.shouldTriggerVerification != old.shouldTriggerVerification) {
      streamSubscription.cancel();
      streamSubscription = widget.shouldTriggerVerification
          .listen((isValid) => _showValidation(isValid));
    }
  }

  @override
  dispose() {
    controller.dispose();
    streamSubscription.cancel();
    super.dispose();
  }

  _showValidation(bool isValid) {
    if (isValid) {
      _validationCallback();
    } else {
      controller.forward();
    }
  }

  _validationCallback() {
    if (widget.isValidCallback != null) {
      widget.isValidCallback!();
    } else {
      print(
          "You didn't implement validation callback. Please handle a state by yourself then.");
    }
  }

  Widget _buildDeleteButton() {
    return Container(
      child: CupertinoButton(
        onPressed: _onDeleteCancelButtonPressed,
        child: Container(
          child: enteredPasscode.length == 0
              ? widget.cancelButton
              : widget.deleteButton,
        ),
      ),
    );
  }
}
