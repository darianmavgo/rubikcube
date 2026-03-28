import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'dart:math';

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
        title: const Text("Strict Hover-Sweep Interaction Engine", style: TextStyle(fontSize: 16)),
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
          
          // Technical Telemetry Overlay Mode
          Positioned(
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
                  Text("Axis Select : ${_animAxis?.toUpperCase() ?? 'IDLE'}", style: TextStyle(color: _animAxis == null ? Colors.white54 : Colors.yellowAccent, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold)),
                  Text("Slice Index : ${_animSlice ?? '-'}", style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14)),
                  Text("Target Rot. : ${(_animTargetAngle * 180 / pi).toStringAsFixed(1)}°", style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14)),
                  Text("Face ID     : ${_animFaceLabel ?? '-'}", style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14)),
                ],
              ),
            ),
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

class Cubie {
  final int id, x, y, z;
  final double size;
  Matrix4 transform;
  Cubie({required this.id, required this.x, required this.y, required this.z, required this.transform, required this.size});
}

class RubiksCube3D extends StatelessWidget {
  final double rx, ry;
  final List<Cubie> cubies;
  final String? animAxis;
  final int? animSlice;
  final double animAngle;
  final void Function(DragStartDetails details)? onPanStart;
  final void Function(Cubie cubie, double nx, double ny, double nz, DragUpdateDetails details, Matrix4 globalTransform, String label)? onPanUpdate;
  final void Function()? onPanEnd;

  const RubiksCube3D({super.key, required this.rx, required this.ry, required this.cubies, this.animAxis, this.animSlice, this.animAngle = 0.0, this.onPanStart, this.onPanUpdate, this.onPanEnd});

  @override
  Widget build(BuildContext context) {
    // We append rotateX(-pi/2) to the global transform:
    // This maps Flutter's default (Y-down, Z-in) coords to mathematically intuitive (Y-in tabletop, Z-up vertical)
    final globalTransform = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateX(rx)
      ..rotateY(ry)
      ..rotateX(-pi/2); // Z-Vertical & XY-Tabletop base tilt

    List<_FaceData> allFaces = [];

    for (var cubie in cubies) {
      allFaces.add(_createFace(cubie.x == 1 ? Colors.redAccent : const Color(0xFF111111), Matrix4.identity()..translate(cubie.size/2, 0.0, 0.0)..rotateY(pi / 2), cubie, globalTransform, 1.0, 0.0, 0.0, "R${cubie.id}"));
      allFaces.add(_createFace(cubie.x == -1 ? Colors.orangeAccent : const Color(0xFF111111), Matrix4.identity()..translate(-cubie.size/2, 0.0, 0.0)..rotateY(-pi / 2), cubie, globalTransform, -1.0, 0.0, 0.0, "O${cubie.id}"));
      allFaces.add(_createFace(cubie.y == -1 ? Colors.white : const Color(0xFF111111), Matrix4.identity()..translate(0.0, -cubie.size/2, 0.0)..rotateX(pi / 2), cubie, globalTransform, 0.0, -1.0, 0.0, "W${cubie.id}"));
      allFaces.add(_createFace(cubie.y == 1 ? Colors.yellowAccent : const Color(0xFF111111), Matrix4.identity()..translate(0.0, cubie.size/2, 0.0)..rotateX(-pi / 2), cubie, globalTransform, 0.0, 1.0, 0.0, "Y${cubie.id}"));
      allFaces.add(_createFace(cubie.z == 1 ? Colors.greenAccent : const Color(0xFF111111), Matrix4.identity()..translate(0.0, 0.0, cubie.size/2), cubie, globalTransform, 0.0, 0.0, 1.0, "G${cubie.id}"));
      allFaces.add(_createFace(cubie.z == -1 ? Colors.blueAccent : const Color(0xFF111111), Matrix4.identity()..translate(0.0, 0.0, -cubie.size/2)..rotateY(pi), cubie, globalTransform, 0.0, 0.0, -1.0, "B${cubie.id}"));
    }

    _addAxesLines(allFaces, globalTransform);
    allFaces.sort((a, b) => b.z.compareTo(a.z));

    final stackChildren = <Widget>[SizedBox(width: cubies.first.size * 6, height: cubies.first.size * 6)];
    stackChildren.addAll(allFaces.map((f) => f.widget));
    return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: stackChildren);
  }

  void _addAxesLines(List<_FaceData> faces, Matrix4 globalTransform) {
    for (int i = -14; i <= 14; i++) {
        if (i == 0) continue;
        double offset = i * 20.0;
        
        // Render tail and positive vectors
        _addPoint(faces, globalTransform, offset, 0, 0, i > 0 ? Colors.redAccent : Colors.red[900]!);
        _addPoint(faces, globalTransform, 0, offset, 0, i > 0 ? Colors.greenAccent : Colors.green[900]!);
        _addPoint(faces, globalTransform, 0, 0, offset, i > 0 ? Colors.blueAccent : Colors.blue[900]!);
    }
    
    // Add explicitly pointing vector arrowheads and text markers to the positive ends
    _addAxisLabel(faces, globalTransform, 320, 0, 0, Colors.redAccent, "X Axis\n(Tabletop Breadth)", Matrix4.identity()..rotateZ(-pi/2));
    _addAxisLabel(faces, globalTransform, 0, 320, 0, Colors.greenAccent, "Y Axis\n(Tabletop Depth)", Matrix4.identity()..rotateX(pi/2));
    _addAxisLabel(faces, globalTransform, 0, 0, 320, Colors.blueAccent, "Z Axis\n(Vertical)", Matrix4.identity());
  }

  void _addPoint(List<_FaceData> faces, Matrix4 globalTransform, double tx, double ty, double tz, Color color) {
    final trans = globalTransform.clone()..translate(tx, ty, tz);
    faces.add(_FaceData(Transform(
      transform: trans, alignment: Alignment.center,
      child: IgnorePointer(child: Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)))),
    ), trans.getTranslation().z);
  }

  void _addAxisLabel(List<_FaceData> faces, Matrix4 globalTransform, double tx, double ty, double tz, Color color, String text, Matrix4 arrowRot) {
      final trans = globalTransform.clone()..translate(tx, ty, tz);
      faces.add(_FaceData(Transform(
        transform: trans, alignment: Alignment.center,
        child: IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform(
                transform: arrowRot, alignment: Alignment.center, 
                child: Icon(Icons.arrow_upward, color: color, size: 50, shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))])
              ),
              Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18, shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))])),
            ],
          ),
        ),
      ), trans.getTranslation().z));
  }

  _FaceData _createFace(Color baseColor, Matrix4 faceTransform, Cubie cubie, Matrix4 globalTransform, double nx, double ny, double nz, String label) {
    Matrix4 tempRot = Matrix4.identity();
    if (animAxis != null) {
        final center = cubie.transform.getTranslation();
        int cx = (center.x / cubie.size).round(), cy = (center.y / cubie.size).round(), cz = (center.z / cubie.size).round();
        if ((animAxis == 'x' && cx == animSlice) || (animAxis == 'y' && cy == animSlice) || (animAxis == 'z' && cz == animSlice)) {
            if (animAxis == 'x') tempRot.rotateX(animAngle); else if (animAxis == 'y') tempRot.rotateY(animAngle); else tempRot.rotateZ(animAngle);
        }
    }
    final totalTransform = globalTransform.clone()..multiply(tempRot)..multiply(cubie.transform)..multiply(faceTransform);
    
    // We completely removed onTap mechanics. You MUST press and drag to select/rotate slices now.
    return _FaceData(Transform(
      transform: totalTransform, alignment: Alignment.center,
      child: GestureDetector(
        onPanStart: onPanStart, 
        onPanUpdate: (details) => onPanUpdate?.call(cubie, nx, ny, nz, details, globalTransform, label), 
        onPanEnd: (details) => onPanEnd?.call(), 
        onPanCancel: () => onPanEnd?.call(),
        child: Container(width: cubie.size, height: cubie.size, decoration: BoxDecoration(color: const Color(0xFF0A0A0A), border: Border.all(color: Colors.white24, width: 1)),
          child: Stack(alignment: Alignment.center, children: [
            Container(margin: const EdgeInsets.all(3), decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(6))),
            if (baseColor != const Color(0xFF111111))
              Transform(
                alignment: Alignment.center,
                // Orient standard UI text so it maps intelligently to the blocks 
                transform: Matrix4.identity()..scale(nx < 0 ? -1.0 : 1.0, (nz < 0 || ny < 0) ? -1.0 : 1.0, 1.0),
                child: Text(label, style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
          ]),
        ),
      ),
    ), totalTransform.getTranslation().z);
  }
}

class _FaceData { final Widget widget; final double z; _FaceData(this.widget, this.z); }
