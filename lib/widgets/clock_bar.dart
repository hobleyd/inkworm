import 'dart:async';

import 'package:flutter/material.dart';

class ClockBar extends StatefulWidget {
  const ClockBar({super.key});

  @override
  State<ClockBar> createState() => _ClockBarState();
}

class _ClockBarState extends State<ClockBar> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNextMinute();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNextMinute() {
    final now = DateTime.now();
    final secondsUntilNextMinute = 60 - now.second;
    _timer = Timer(Duration(seconds: secondsUntilNextMinute), () {
      if (mounted) setState(() => _now = DateTime.now());
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  String get _timeString =>
      '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: Align(
        alignment: Alignment.center,
        child: Text(_timeString, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}