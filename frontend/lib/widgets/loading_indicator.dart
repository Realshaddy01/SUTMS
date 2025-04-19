import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// A loading indicator widget that shows a spinning animation
class LoadingIndicator extends StatelessWidget {
  final Color? color;
  final double size;
  final String? message;

  const LoadingIndicator({
    Key? key,
    this.color,
    this.size = 50.0,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitDoubleBounce(
            color: color ?? Theme.of(context).primaryColor,
            size: size,
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                message!,
                style: TextStyle(
                  color: color ?? Theme.of(context).primaryColor,
                  fontSize: 16.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
} 