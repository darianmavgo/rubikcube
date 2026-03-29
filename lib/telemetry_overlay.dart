import 'package:flutter/material.dart';
import 'dart:math';

class TelemetryOverlay extends StatelessWidget {
  final double rx;
  final double ry;
  final String? animAxis;
  final int? animSlice;
  final double animTargetAngle;
  final String? animFaceLabel;

  const TelemetryOverlay({
    super.key,
    required this.rx,
    required this.ry,
    this.animAxis,
    this.animSlice,
    required this.animTargetAngle,
    this.animFaceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20, left: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.7)),
          boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 10)]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("DEBUG TELEMETRY", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            const Text("--- CAMERA ORBIT ---", style: TextStyle(color: Colors.grey, fontSize: 10)),
            Text("Pitch (rx)  : ${rx.toStringAsFixed(3)}", style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14)),
            Text("Yaw   (ry)  : ${ry.toStringAsFixed(3)}", style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14)),
            const Text("Base  (T)   : Z-Up Correction active", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
            const SizedBox(height: 12),
            const Text("--- ACTIVE SLICE ENGINE ---", style: TextStyle(color: Colors.grey, fontSize: 10)),
            Text("Axis Select : ${animAxis?.toUpperCase() ?? 'IDLE'}", style: TextStyle(color: animAxis == null ? Colors.white54 : Colors.yellowAccent, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold)),
            Text("Slice Index : ${animSlice ?? '-'}", style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14)),
            Text("Target Rot. : ${(animTargetAngle * 180 / pi).toStringAsFixed(1)}°", style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14)),
            Text("Face ID     : ${animFaceLabel ?? '-'}", style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
