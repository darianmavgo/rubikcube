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
  double rx = -0.55;
  double ry = 0.55;
  
  late List<Cubie> cubies;
  final double cubieSize = 70.0;

  bool _devMode = true;
  bool _reverseRotation = false;

  AnimationController? _controller;
  Animation<double>? _animation;
  String? _animAxis;
  int? _animSlice;
  double _animTargetAngle = 0;

  @override
  void initState() {
    super.initState();
    _initCube();
    
    // We bind the animation duration directly to 1 second as requested in UpdatePlan.md
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
         _bakeRotation();
         _controller!.reset();
         setState(() {
            _animAxis = null;
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
    for (int x = -1; x <= 1; x++) {
      for (int y = -1; y <= 1; y++) {
        for (int z = -1; z <= 1; z++) {
          final transform = Matrix4.identity()..translate(x * cubieSize, y * cubieSize, z * cubieSize);
          cubies.add(Cubie(
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
          if (_animAxis == 'y') rot.rotateY(_animTargetAngle);
          if (_animAxis == 'z') rot.rotateZ(_animTargetAngle);
          
          cubie.transform = rot * cubie.transform;
        }
     }
  }

  void _rotateSlice({required String axis, required int sliceIndex, required double angle}) {
    if (_controller != null && _controller!.isAnimating) return; 
    
    setState(() {
       _animAxis = axis;
       _animSlice = sliceIndex;
       _animTargetAngle = angle;
    });
    
    _animation = Tween<double>(begin: 0.0, end: angle).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeInOut)
    );
    _controller!.forward(from: 0.0);
  }

  void _onFaceClicked(Cubie cubie, String axis, double sign, bool isClockwise) {
    if (_controller != null && _controller!.isAnimating) return;
    
    final center = cubie.transform.getTranslation();
    int sliceIndex = ( (axis == 'x' ? center.x : axis == 'y' ? center.y : center.z) / cubieSize ).round();
    
    double angle = (pi / 2) * sign * (isClockwise ? 1 : -1);
    _rotateSlice(axis: axis, sliceIndex: sliceIndex, angle: angle);
  }

  // Receiver for the newly implemented intelligent projection Swiping calculation
  void _onFaceSwiped(Cubie cubie, String axis, double angle) {
    if (_controller != null && _controller!.isAnimating) return;

    final center = cubie.transform.getTranslation();
    int sliceIndex = ( (axis == 'x' ? center.x : axis == 'y' ? center.y : center.z) / cubieSize ).round();
    
    _rotateSlice(axis: axis, sliceIndex: sliceIndex, angle: angle);
  }

  Widget _btn(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF333344),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          minimumSize: const Size(60, 48),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _axisRow(String axisLabel, String axisId, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            child: Text("$axisLabel Axis:", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _btn("-1", () => _rotateSlice(axis: axisId, sliceIndex: -1, angle: _reverseRotation ? -pi/2 : pi/2)),
          _btn(" 0", () => _rotateSlice(axis: axisId, sliceIndex: 0, angle: _reverseRotation ? -pi/2 : pi/2)),
          _btn("+1", () => _rotateSlice(axis: axisId, sliceIndex: 1, angle: _reverseRotation ? -pi/2 : pi/2)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Florite Simulator: Rubik\'s Component System',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Dev Mode (Show Axes)", style: TextStyle(color: Colors.white70)),
              Switch(
                value: _devMode, 
                onChanged: (v) => setState(() => _devMode = v),
                activeColor: Colors.indigoAccent,
              ),
              const SizedBox(width: 20),
              const Text("Reverse Control Panel", style: TextStyle(color: Colors.white70)),
              Switch(
                value: _reverseRotation, 
                onChanged: (v) => setState(() => _reverseRotation = v),
                activeColor: Colors.pinkAccent,
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
            child: const Text(
              "NEW: Click or right-click any face to rotate its sector. Or, Drag any block to intuitively swipe the slice! Swipe horizontally or vertically.",
              style: TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                // If the user drags outside of a face, it orbits the camera
                setState(() {
                  ry -= details.delta.dx * 0.01;
                  rx += details.delta.dy * 0.01;
                });
              },
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _controller!,
                    builder: (context, child) {
                      return RubiksCube3D(
                        rx: rx, 
                        ry: ry, 
                        cubies: cubies, 
                        devMode: _devMode,
                        animAxis: _animAxis,
                        animSlice: _animSlice,
                        animAngle: _animation?.value ?? 0.0,
                        onFaceClick: _onFaceClicked,
                        onFaceSwipe: _onFaceSwiped,
                      );
                    }
                  )
                ),
              ),
            ),
          ),
          // Control Panel
          Container(
            padding: const EdgeInsets.only(top: 10, bottom: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF151520),
              border: Border(top: BorderSide(color: Colors.black45, width: 2)),
            ),
            child: Column(
              children: [
                _axisRow("X (L/R)", "x", Colors.redAccent),
                _axisRow("Y (Top/Bot)", "y", Colors.greenAccent),
                _axisRow("Z (Frt/Back)", "z", Colors.lightBlueAccent),
                const SizedBox(height: 15),
                TextButton.icon(
                  onPressed: () {
                    if (_controller != null && _controller!.isAnimating) return;
                    setState(() {
                      rx = -0.55; ry = 0.55;
                      _initCube();
                    });
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white54),
                  label: const Text("Reset Cube Form", style: TextStyle(color: Colors.white54)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class Cubie {
  final int x, y, z;
  final double size;
  Matrix4 transform;

  Cubie({required this.x, required this.y, required this.z, required this.transform, required this.size});
}

class RubiksCube3D extends StatelessWidget {
  final double rx;
  final double ry;
  final List<Cubie> cubies;
  final bool devMode;

  final String? animAxis;
  final int? animSlice;
  final double animAngle;
  final void Function(Cubie cubie, String axis, double sign, bool isClockwise)? onFaceClick;
  final void Function(Cubie cubie, String axis, double angle)? onFaceSwipe;

  const RubiksCube3D({
    super.key, 
    required this.rx, 
    required this.ry, 
    required this.cubies, 
    required this.devMode,
    this.animAxis,
    this.animSlice,
    this.animAngle = 0.0,
    this.onFaceClick,
    this.onFaceSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final globalTransform = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateX(rx)
      ..rotateY(ry);

    List<_FaceData> allFaces = [];

    if (devMode) {
      _addDottedAxis(allFaces, 'x', Colors.redAccent, globalTransform);
      _addDottedAxis(allFaces, 'y', Colors.greenAccent, globalTransform);
      _addDottedAxis(allFaces, 'z', Colors.lightBlueAccent, globalTransform);
    }

    for (var cubie in cubies) {
      allFaces.add(_createFace(
        cubie.x == 1 ? Colors.redAccent : const Color(0xFF111111), 
        Matrix4.identity()..translate(cubie.size/2, 0.0, 0.0)..rotateY(pi / 2),
        cubie, globalTransform, 1.0, 0.0, 0.0
      ));
      
      allFaces.add(_createFace(
        cubie.x == -1 ? Colors.orangeAccent : const Color(0xFF111111), 
        Matrix4.identity()..translate(-cubie.size/2, 0.0, 0.0)..rotateY(-pi / 2),
        cubie, globalTransform, -1.0, 0.0, 0.0
      ));
      
      allFaces.add(_createFace(
        cubie.y == -1 ? Colors.white : const Color(0xFF111111), 
        Matrix4.identity()..translate(0.0, -cubie.size/2, 0.0)..rotateX(pi / 2),
        cubie, globalTransform, 0.0, -1.0, 0.0
      ));
      
      allFaces.add(_createFace(
        cubie.y == 1 ? Colors.yellowAccent : const Color(0xFF111111), 
        Matrix4.identity()..translate(0.0, cubie.size/2, 0.0)..rotateX(-pi / 2),
        cubie, globalTransform, 0.0, 1.0, 0.0
      ));
      
      allFaces.add(_createFace(
        cubie.z == 1 ? Colors.greenAccent : const Color(0xFF111111), 
        Matrix4.identity()..translate(0.0, 0.0, cubie.size/2),
        cubie, globalTransform, 0.0, 0.0, 1.0
      ));
      
      allFaces.add(_createFace(
        cubie.z == -1 ? Colors.blueAccent : const Color(0xFF111111), 
        Matrix4.identity()..translate(0.0, 0.0, -cubie.size/2)..rotateY(pi),
        cubie, globalTransform, 0.0, 0.0, -1.0
      ));
    }

    allFaces.sort((a, b) => b.z.compareTo(a.z));

    return Stack(
      alignment: Alignment.center,
      children: allFaces.map((f) => f.widget).toList(),
    );
  }

  void _addDottedAxis(List<_FaceData> faces, String axis, Color color, Matrix4 globalTransform) {
    for (int i = -6; i <= 6; i++) {
       if (i == 0) continue; 
       double offset = i * 35.0; 
       
       Matrix4 loc = Matrix4.identity();
       if (axis == 'x') loc.translate(offset, 0.0, 0.0);
       if (axis == 'y') loc.translate(0.0, offset, 0.0);
       if (axis == 'z') loc.translate(0.0, 0.0, offset);

       final totalTransform = globalTransform.clone()..multiply(loc);
       final z = totalTransform.getTranslation().z;

       faces.add(_FaceData(
          Transform(
             transform: totalTransform,
             alignment: Alignment.center,
             child: IgnorePointer(
               child: Container(
                 width: 12, height: 12, 
                 decoration: BoxDecoration(
                   color: color, 
                   shape: BoxShape.circle,
                   boxShadow: [BoxShadow(color: color.withOpacity(0.8), blurRadius: 10, spreadRadius: 2)]
                 )
               ),
             ),
          ),
          z
       ));
    }
  }

  _FaceData _createFace(Color baseColor, Matrix4 faceTransform, Cubie cubie, Matrix4 globalTransform, double nx, double ny, double nz) {
    
    // Inject animation transform dynamically if the block is within the active rotating slice
    Matrix4 tempRot = Matrix4.identity();
    if (animAxis != null) {
        final center = cubie.transform.getTranslation();
        int cx = (center.x / cubie.size).round();
        int cy = (center.y / cubie.size).round();
        int cz = (center.z / cubie.size).round();
        
        bool inSlice = false;
        if (animAxis == 'x' && cx == animSlice) inSlice = true;
        if (animAxis == 'y' && cy == animSlice) inSlice = true;
        if (animAxis == 'z' && cz == animSlice) inSlice = true;
        
        if (inSlice) {
            if (animAxis == 'x') tempRot.rotateX(animAngle);
            if (animAxis == 'y') tempRot.rotateY(animAngle);
            if (animAxis == 'z') tempRot.rotateZ(animAngle);
        }
    }

    final totalTransform = globalTransform.clone()
      ..multiply(tempRot)
      ..multiply(cubie.transform)
      ..multiply(faceTransform);
      
    final z = totalTransform.getTranslation().z;
    
    final widget = Transform(
      transform: totalTransform,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _triggerClick(cubie, nx, ny, nz, true),
        onSecondaryTap: () => _triggerClick(cubie, nx, ny, nz, false),
        onLongPress: () => _triggerClick(cubie, nx, ny, nz, false),
        onPanUpdate: (details) {
          final dx = details.delta.dx;
          final dy = details.delta.dy;
          if (dx.abs() > 3 || dy.abs() > 3) {
             _triggerSwipe(cubie, nx, ny, nz, dx, dy, globalTransform);
          }
        },
        child: Container(
          width: cubie.size,
          height: cubie.size,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );

    return _FaceData(widget, z);
  }
  
  void _triggerClick(Cubie cubie, double nx, double ny, double nz, bool isClockwise) {
    if (onFaceClick == null) return;
    
    double gx = cubie.transform.entry(0,0)*nx + cubie.transform.entry(0,1)*ny + cubie.transform.entry(0,2)*nz;
    double gy = cubie.transform.entry(1,0)*nx + cubie.transform.entry(1,1)*ny + cubie.transform.entry(1,2)*nz;
    double gz = cubie.transform.entry(2,0)*nx + cubie.transform.entry(2,1)*ny + cubie.transform.entry(2,2)*nz;
    
    String activeAxis;
    double sign;
    if (gx.abs() > gy.abs() && gx.abs() > gz.abs()) {
      activeAxis = 'x'; sign = gx.sign;
    } else if (gy.abs() > gx.abs() && gy.abs() > gz.abs()) {
      activeAxis = 'y'; sign = gy.sign;
    } else {
      activeAxis = 'z'; sign = gz.sign;
    }
    
    onFaceClick!(cubie, activeAxis, sign, isClockwise);
  }

  void _triggerSwipe(Cubie cubie, double nx, double ny, double nz, double dx, double dy, Matrix4 globalTransform) {
    if (onFaceSwipe == null) return;
    
    double gx = cubie.transform.entry(0,0)*nx + cubie.transform.entry(0,1)*ny + cubie.transform.entry(0,2)*nz;
    double gy = cubie.transform.entry(1,0)*nx + cubie.transform.entry(1,1)*ny + cubie.transform.entry(1,2)*nz;
    double gz = cubie.transform.entry(2,0)*nx + cubie.transform.entry(2,1)*ny + cubie.transform.entry(2,2)*nz;
    
    String normalAxis;
    if (gx.abs() > gy.abs() && gx.abs() > gz.abs()) normalAxis = 'x';
    else if (gy.abs() > gx.abs() && gy.abs() > gz.abs()) normalAxis = 'y';
    else normalAxis = 'z';

    List<String> candidateAxes = ['x', 'y', 'z']..remove(normalAxis);
    
    final faceCenter = cubie.transform.getTranslation(); 
    faceCenter.x += gx * (cubie.size / 2.0);
    faceCenter.y += gy * (cubie.size / 2.0);
    faceCenter.z += gz * (cubie.size / 2.0);

    String bestAxis = candidateAxes[0];
    double bestDotAbs = -1.0;
    double bestAngleSign = 1;

    for (String axis in candidateAxes) {
      // Simulate minor mechanical trajectory movement in geometric space
      Matrix4 rot = Matrix4.identity();
      if (axis == 'x') rot.rotateX(0.1);
      if (axis == 'y') rot.rotateY(0.1);
      if (axis == 'z') rot.rotateZ(0.1);

      final simulatedCenter = rot.transform3(faceCenter.clone());
      
      Vector4 pOrig = Vector4(faceCenter.x, faceCenter.y, faceCenter.z, 1.0);
      Vector4 pSim = Vector4(simulatedCenter.x, simulatedCenter.y, simulatedCenter.z, 1.0);
      
      globalTransform.transform(pOrig); 
      globalTransform.transform(pSim);

      double diffX = (pSim.x / pSim.w) - (pOrig.x / pOrig.w);
      double diffY = (pSim.y / pSim.w) - (pOrig.y / pOrig.w);

      // Math dot product against the physical screen Drag Delta
      double dot = diffX * dx + diffY * dy;

      if (dot.abs() > bestDotAbs) {
        bestDotAbs = dot.abs();
        bestAxis = axis;
        bestAngleSign = dot > 0 ? 1 : -1;
      }
    }

    onFaceSwipe!(cubie, bestAxis, bestAngleSign * (pi/2));
  }
}

class _FaceData {
  final Widget widget;
  final double z;
  _FaceData(this.widget, this.z);
}
