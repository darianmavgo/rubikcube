import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'dart:math';

import 'rubiks_cube_3d.dart';
import 'telemetry_overlay.dart';

void main() {
  runApp(const RubiksCubeApp());
}

class RubiksCubeApp extends StatelessWidget {
  const RubiksCubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rubik\'s Cube Interactive',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
      ),
      home: const RubiksCubeScreen(),
    );
  }
}

class RubiksCubeScreen extends StatefulWidget {
  const RubiksCubeScreen({super.key});

  @override
  State<RubiksCubeScreen> createState() => _RubiksCubeScreenState();
}

class _RubiksCubeScreenState extends State<RubiksCubeScreen> with SingleTickerProviderStateMixin {
  // Base viewing angle adjusted so TableTop XY and Vertical Z are clearly visible
  double rx = 0.55; 
  double ry = -0.75;
  
  late List<Cubie> cubies;
  final double cubieSize = 70.0;

  AnimationController? _controller;
  Animation<double>? _animation;
  String? _animAxis;
  int? _animSlice;
  double _animTargetAngle = 0;
  String? _animFaceLabel;

  Offset? _swipeStart;

  @override
  void initState() {
    super.initState();
    _initCube();
    
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
         _bakeRotation();
         _controller!.reset();
         setState(() {
            _animAxis = null;
            _animFaceLabel = null;
         });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initCube() {
    cubies = [];
    int count = 0;
    for (int x = -1; x <= 1; x++) {
      for (int y = -1; y <= 1; y++) {
        for (int z = -1; z <= 1; z++) {
          final transform = Matrix4.identity()..translate(x * cubieSize, y * cubieSize, z * cubieSize);
          cubies.add(Cubie(
            id: count++,
            x: x, y: y, z: z, 
            transform: transform,
            size: cubieSize,
          ));
        }
      }
    }
  }

  void _bakeRotation() {
     for (var cubie in cubies) {
        final center = cubie.transform.getTranslation();
        int cx = (center.x / cubieSize).round();
        int cy = (center.y / cubieSize).round();
        int cz = (center.z / cubieSize).round();

        bool inSlice = false;
        if (_animAxis == 'x' && cx == _animSlice) inSlice = true;
        if (_animAxis == 'y' && cy == _animSlice) inSlice = true;
        if (_animAxis == 'z' && cz == _animSlice) inSlice = true;

        if (inSlice) {
          final rot = Matrix4.identity();
          if (_animAxis == 'x') rot.rotateX(_animTargetAngle);
          else if (_animAxis == 'y') rot.rotateY(_animTargetAngle);
          else if (_animAxis == 'z') rot.rotateZ(_animTargetAngle);
          cubie.transform = rot * cubie.transform;
        }
     }
  }

  void _rotateSlice({required String axis, required int sliceIndex, required double angle, String? faceLabel}) {
    if (_controller != null && _controller!.isAnimating) return; 
    
    setState(() {
       _animAxis = axis;
       _animSlice = sliceIndex;
       _animTargetAngle = angle;
       _animFaceLabel = faceLabel;
    });
    
    final now = DateTime.now();
    final timestamp = "${now.hour}:${now.minute}:${now.second}.${now.millisecond}";
    String direction = angle > 0 ? "Clockwise" : "Counter-Clockwise";
    print("[$timestamp] SWIPE ROTATION: Face $faceLabel | Axis $axis | Slice $sliceIndex | Direction: $direction");

    _animation = Tween<double>(begin: 0.0, end: angle).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeInOut)
    );
    _controller!.forward(from: 0.0);
  }

  void _onPanStart(DragStartDetails details) {
    if (_controller != null && _controller!.isAnimating) return;
    _swipeStart = details.globalPosition;
  }

  void _onPanUpdate(Cubie cubie, double nx, double ny, double nz, DragUpdateDetails details, Matrix4 globalTransform, String label) {
    if (_swipeStart == null) return;
    
    double dx = details.globalPosition.dx - _swipeStart!.dx;
    double dy = details.globalPosition.dy - _swipeStart!.dy;
    
    if ((dx * dx + dy * dy) > 144) {
      _swipeStart = null; 
      final localNormal = Vector3(nx, ny, nz);
      final worldNormal = cubie.transform.transform3(localNormal);

      String normalAxis;
      if (worldNormal.x.abs() > worldNormal.y.abs() && worldNormal.x.abs() > worldNormal.z.abs()) normalAxis = 'x';
      else if (worldNormal.y.abs() > worldNormal.x.abs() && worldNormal.y.abs() > worldNormal.z.abs()) normalAxis = 'y';
      else normalAxis = 'z';

      List<String> candidateAxes = ['x', 'y', 'z']..remove(normalAxis);
      
      final faceCenter = cubie.transform.getTranslation(); 
      faceCenter.x += worldNormal.x * (cubieSize / 2.0);
      faceCenter.y += worldNormal.y * (cubieSize / 2.0);
      faceCenter.z += worldNormal.z * (cubieSize / 2.0);

      String bestAxis = candidateAxes[0];
      double bestDotAbs = -1.0;
      double bestAngleSign = 1;

      for (String axis in candidateAxes) {
        Matrix4 rot = Matrix4.identity();
        if (axis == 'x') rot.rotateX(0.1);
        if (axis == 'y') rot.rotateY(0.1);
        if (axis == 'z') rot.rotateZ(0.1);

        final simulatedCenter = rot.transform3(faceCenter.clone());
        Vector4 pOrig = Vector4(faceCenter.x, faceCenter.y, faceCenter.z, 1.0);
        Vector4 pSim = Vector4(simulatedCenter.x, simulatedCenter.y, simulatedCenter.z, 1.0);
        globalTransform.transform(pOrig); 
        globalTransform.transform(pSim);

        double dot = ((pSim.x / pSim.w) - (pOrig.x / pOrig.w)) * dx + ((pSim.y / pSim.w) - (pOrig.y / pOrig.w)) * dy;
        if (dot.abs() > bestDotAbs) {
          bestDotAbs = dot.abs();
          bestAxis = axis;
          bestAngleSign = dot > 0 ? 1 : -1;
        }
      }

      final center = cubie.transform.getTranslation();
      int sliceIndex = ( (bestAxis == 'x' ? center.x : bestAxis == 'y' ? center.y : center.z) / cubieSize ).round();
      _rotateSlice(axis: bestAxis, sliceIndex: sliceIndex, angle: bestAngleSign * (pi/2), faceLabel: label);
    }
  }

  void _onPanEnd() {
    _swipeStart = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("", style: TextStyle(fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Camera Drag
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                setState(() {
                  ry -= details.delta.dx * 0.01;
                  rx += details.delta.dy * 0.01;
                });
              },
              child: Container(
                color: Colors.transparent,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller!,
                    builder: (context, child) {
                      return RubiksCube3D(
                        rx: rx, ry: ry, cubies: cubies, 
                        animAxis: _animAxis, animSlice: _animSlice, animAngle: _animation?.value ?? 0.0,
                        onPanStart: _onPanStart, onPanUpdate: _onPanUpdate, onPanEnd: _onPanEnd,
                      );
                    }
                  )
                ),
              ),
            ),
          ),
          
          TelemetryOverlay(
            rx: rx,
            ry: ry,
            animAxis: _animAxis,
            animSlice: _animSlice,
            animTargetAngle: _animTargetAngle,
            animFaceLabel: _animFaceLabel,
          ),

          Positioned(bottom: 30, right: 30, child: FloatingActionButton(
            onPressed: () {
              if (_controller != null && _controller!.isAnimating) return;
              setState(() {
                rx = 0.55; ry = -0.75;
                _initCube();
              });
            },
            backgroundColor: Colors.cyanAccent[700],
            child: const Icon(Icons.refresh, color: Colors.white),
          ))
        ],
      ),
    );
  }
}
