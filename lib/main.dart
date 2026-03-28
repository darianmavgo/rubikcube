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

  AnimationController? _controller;
  Animation<double>? _animation;
  String? _animAxis;
  int? _animSlice;
  double _animTargetAngle = 0;

  Offset? _swipeStart;

  @override
  void initState() {
    super.initState();
    _initCube();
    
    // Rotation completes in 1 second
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
          if (_animAxis == 'x') {
            rot.rotateX(_animTargetAngle);
          } else if (_animAxis == 'y') {
            rot.rotateY(_animTargetAngle);
          } else if (_animAxis == 'z') {
            rot.rotateZ(_animTargetAngle);
          }
          
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
    });
    
    // Log axis and direction with timestamp
    final now = DateTime.now();
    final timestamp = "${now.hour}:${now.minute}:${now.second}.${now.millisecond}";
    String direction = angle > 0 ? "Clockwise" : "Counter-Clockwise";
    print("[$timestamp] ROTATION: Face $faceLabel | Axis $axis | Slice $sliceIndex | Direction: $direction");

    _animation = Tween<double>(begin: 0.0, end: angle).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeInOut)
    );
    _controller!.forward(from: 0.0);
  }

  void _onFaceClicked(Cubie cubie, String axis, double sign, bool isClockwise, String faceLabel) {
    if (_controller != null && _controller!.isAnimating) return;
    
    final center = cubie.transform.getTranslation();
    int sliceIndex = ( (axis == 'x' ? center.x : axis == 'y' ? center.y : center.z) / cubieSize ).round();
    
    double angle = (pi / 2) * sign * (isClockwise ? 1 : -1);
    _rotateSlice(axis: axis, sliceIndex: sliceIndex, angle: angle, faceLabel: faceLabel);
  }

  void _onFaceSwiped(Cubie cubie, String axis, double angle, String faceLabel) {
    if (_controller != null && _controller!.isAnimating) return;

    final center = cubie.transform.getTranslation();
    int sliceIndex = ( (axis == 'x' ? center.x : axis == 'y' ? center.y : center.z) / cubieSize ).round();
    
    _rotateSlice(axis: axis, sliceIndex: sliceIndex, angle: angle, faceLabel: faceLabel);
  }

  void _onPanStart(DragStartDetails details) {
    if (_controller != null && _controller!.isAnimating) return;
    _swipeStart = details.globalPosition;
  }

  void _onPanUpdate(Cubie cubie, double nx, double ny, double nz, DragUpdateDetails details, Matrix4 globalTransform) {
    if (_swipeStart == null) return;
    
    double dx = details.globalPosition.dx - _swipeStart!.dx;
    double dy = details.globalPosition.dy - _swipeStart!.dy;
    
    if ((dx * dx + dy * dy) > 144) {
      _swipeStart = null; 
      
      double gx = cubie.transform.entry(0,0)*nx + cubie.transform.entry(0,1)*ny + cubie.transform.entry(0,2)*nz;
      double gy = cubie.transform.entry(1,0)*nx + cubie.transform.entry(1,1)*ny + cubie.transform.entry(1,2)*nz;
      double gz = cubie.transform.entry(2,0)*nx + cubie.transform.entry(2,1)*ny + cubie.transform.entry(2,2)*nz;
      
      String normalAxis;
      if (gx.abs() > gy.abs() && gx.abs() > gz.abs()) normalAxis = 'x';
      else if (gy.abs() > gx.abs() && gy.abs() > gz.abs()) normalAxis = 'y';
      else normalAxis = 'z';

      List<String> candidateAxes = ['x', 'y', 'z']..remove(normalAxis);
      
      final faceCenter = cubie.transform.getTranslation(); 
      faceCenter.x += gx * (cubieSize / 2.0);
      faceCenter.y += gy * (cubieSize / 2.0);
      faceCenter.z += gz * (cubieSize / 2.0);

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

        double diffX = (pSim.x / pSim.w) - (pOrig.x / pOrig.w);
        double diffY = (pSim.y / pSim.w) - (pOrig.y / pOrig.w);

        double dot = diffX * dx + diffY * dy;

        if (dot.abs() > bestDotAbs) {
          bestDotAbs = dot.abs();
          bestAxis = axis;
          bestAngleSign = dot > 0 ? 1 : -1;
        }
      }

      final center = cubie.transform.getTranslation();
      int sliceIndex = ( (bestAxis == 'x' ? center.x : bestAxis == 'y' ? center.y : center.z) / cubieSize ).round();
      _rotateSlice(axis: bestAxis, sliceIndex: sliceIndex, angle: bestAngleSign * (pi/2));
    }
  }

  void _onPanEnd() {
    _swipeStart = null;
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
      body: Stack(
        children: [
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
                        rx: rx, 
                        ry: ry, 
                        cubies: cubies, 
                        animAxis: _animAxis,
                        animSlice: _animSlice,
                        animAngle: _animation?.value ?? 0.0,
                        onFaceClick: _onFaceClicked,
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                      );
                    }
                  )
                ),
              ),
            ),
          ),
          const Positioned(
            top: 20, left: 0, right: 0,
            child: Text(
              "Directions: Drag blocks to swipe slices. Drag background to orbit.\nAxes Reference: Red (X), Green (Y), Blue (Z)",
              style: TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          // Legend for Axes
          Positioned(
            bottom: 30, left: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _axisLegend("X Axis", Colors.redAccent),
                _axisLegend("Y Axis", Colors.greenAccent),
                _axisLegend("Z Axis", Colors.blueAccent),
              ],
            ),
          ),
          Positioned(
            bottom: 30, right: 30,
            child: FloatingActionButton(
              onPressed: () {
                if (_controller != null && _controller!.isAnimating) return;
                setState(() {
                  rx = -0.55; ry = 0.55;
                  _initCube();
                });
              },
              backgroundColor: Colors.indigoAccent,
              child: const Icon(Icons.refresh, color: Colors.white),
            )
          )
        ],
      ),
    );
  }

  Widget _axisLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
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

  final String? animAxis;
  final int? animSlice;
  final double animAngle;
  final void Function(Cubie cubie, String axis, double sign, bool isClockwise)? onFaceClick;
  final void Function(DragStartDetails details)? onPanStart;
  final void Function(Cubie cubie, double nx, double ny, double nz, DragUpdateDetails details, Matrix4 globalTransform)? onPanUpdate;
  final void Function()? onPanEnd;

  const RubiksCube3D({
    super.key, 
    required this.rx, 
    required this.ry, 
    required this.cubies, 
    this.animAxis,
    this.animSlice,
    this.animAngle = 0.0,
    this.onFaceClick,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    final globalTransform = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateX(rx)
      ..rotateY(ry);

    List<_FaceData> allFaces = [];

    for (var cubie in cubies) {
      allFaces.add(_createFace(cubie.x == 1 ? Colors.redAccent : const Color(0xFF111111), Matrix4.identity()..translate(cubie.size/2, 0.0, 0.0)..rotateY(pi / 2), cubie, globalTransform, 1.0, 0.0, 0.0, "R"));
      allFaces.add(_createFace(cubie.x == -1 ? Colors.orangeAccent : const Color(0xFF111111), Matrix4.identity()..translate(-cubie.size/2, 0.0, 0.0)..rotateY(-pi / 2), cubie, globalTransform, -1.0, 0.0, 0.0, "O"));
      allFaces.add(_createFace(cubie.y == -1 ? Colors.white : const Color(0xFF111111), Matrix4.identity()..translate(0.0, -cubie.size/2, 0.0)..rotateX(pi / 2), cubie, globalTransform, 0.0, -1.0, 0.0, "W"));
      allFaces.add(_createFace(cubie.y == 1 ? Colors.yellowAccent : const Color(0xFF111111), Matrix4.identity()..translate(0.0, cubie.size/2, 0.0)..rotateX(-pi / 2), cubie, globalTransform, 0.0, 1.0, 0.0, "Y"));
      allFaces.add(_createFace(cubie.z == 1 ? Colors.greenAccent : const Color(0xFF111111), Matrix4.identity()..translate(0.0, 0.0, cubie.size/2), cubie, globalTransform, 0.0, 0.0, 1.0, "G"));
      allFaces.add(_createFace(cubie.z == -1 ? Colors.blueAccent : const Color(0xFF111111), Matrix4.identity()..translate(0.0, 0.0, -cubie.size/2)..rotateY(pi), cubie, globalTransform, 0.0, 0.0, -1.0, "B"));
    }

    // Add Axes Label Visualizers (Dotted lines along center)
    _addAxesLines(allFaces, globalTransform);

    // Add X, Y, Z labels at the ends of the axes
    _addAxisLabel(allFaces, globalTransform, 220, 0, 0, Colors.redAccent, "X");
    _addAxisLabel(allFaces, globalTransform, 0, 220, 0, Colors.greenAccent, "Y");
    _addAxisLabel(allFaces, globalTransform, 0, 0, 220, Colors.blueAccent, "Z");

    allFaces.sort((a, b) => b.z.compareTo(a.z));

    final stackChildren = <Widget>[
      SizedBox(width: cubies.first.size * 6, height: cubies.first.size * 6),
    ];
    stackChildren.addAll(allFaces.map((f) => f.widget));

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: stackChildren,
    );
  }

  void _addAxesLines(List<_FaceData> faces, Matrix4 globalTransform) {
    for (int i = -10; i <= 10; i++) {
      if (i == 0) continue;
      double offset = i * 20.0;
      
      // X Axis (Red)
      _addPoint(faces, globalTransform, offset, 0, 0, Colors.redAccent, "X");
      // Y Axis (Green)
      _addPoint(faces, globalTransform, 0, offset, 0, Colors.greenAccent, "Y");
      // Z Axis (Blue)
      _addPoint(faces, globalTransform, 0, 0, offset, Colors.blueAccent, "Z");
    }
  }

  void _addPoint(List<_FaceData> faces, Matrix4 globalTransform, double tx, double ty, double tz, Color color, String label) {
    final trans = globalTransform.clone()..translate(tx, ty, tz);
    final z = trans.getTranslation().z;
    faces.add(_FaceData(
      Transform(
        transform: trans,
        alignment: Alignment.center,
        child: IgnorePointer(
          child: Container(
            width: 4, height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
      z
    ));
  }

  void _addAxisLabel(List<_FaceData> faces, Matrix4 globalTransform, double tx, double ty, double tz, Color color, String text) {
    final trans = globalTransform.clone()..translate(tx, ty, tz);
    final z = trans.getTranslation().z;
    faces.add(_FaceData(
      Transform(
        transform: trans,
        alignment: Alignment.center,
        child: IgnorePointer(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 24,
              shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
            ),
          ),
        ),
      ),
      z
    ));
  }

  _FaceData _createFace(Color baseColor, Matrix4 faceTransform, Cubie cubie, Matrix4 globalTransform, double nx, double ny, double nz, String label) {
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
        onTap: () => _triggerClick(cubie, nx, ny, nz, true, label),
        onSecondaryTap: () => _triggerClick(cubie, nx, ny, nz, false, label),
        onLongPress: () => _triggerClick(cubie, nx, ny, nz, false, label),
        onPanStart: onPanStart,
        onPanUpdate: (details) => onPanUpdate?.call(cubie, nx, ny, nz, details, globalTransform, label),
        onPanEnd: (details) => onPanEnd?.call(),
        onPanCancel: () => onPanEnd?.call(),
        child: Container(
          width: cubie.size,
          height: cubie.size,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              if (baseColor != const Color(0xFF111111))
                Text(label, style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ),
    );

    return _FaceData(widget, z);
  }
  
  void _triggerClick(Cubie cubie, double nx, double ny, double nz, bool isClockwise, String faceLabel) {
    if (onFaceClick == null) return;
    
    // We isolate the 3x3 orientation sub-matrix from the cubie's full 4x4 matrix.
    // This allows us to map the local face normal directly to the exact world axis 
    // it's currently pointing towards!
    final col0 = cubie.transform.getValues().sublist(0, 3);
    final col1 = cubie.transform.getValues().sublist(4, 7);
    final col2 = cubie.transform.getValues().sublist(8, 11);
    
    final worldRotation = Matrix3(
      col0[0], col0[1], col0[2],
      col1[0], col1[1], col1[2],
      col2[0], col2[1], col2[2]
    );

    final localNormal = Vector3(nx, ny, nz);
    final worldNormal = worldRotation * localNormal;

    String activeAxis;
    double worldSign;
    
    double ax = worldNormal.x.abs();
    double ay = worldNormal.y.abs();
    double az = worldNormal.z.abs();

    if (ax > ay && ax > az) {
      activeAxis = 'x'; worldSign = worldNormal.x.sign;
    } else if (ay > ax && ay > az) {
      activeAxis = 'y'; worldSign = worldNormal.y.sign;
    } else {
      activeAxis = 'z'; worldSign = worldNormal.z.sign;
    }

    final globalRotM = Matrix4.identity()..rotateX(rx)..rotateY(ry);
    final projectedNormal = globalRotM.transform3(worldNormal);

    double perspectiveFlip = projectsSign(projectedNormal.z);
    
    onFaceClick!(cubie, activeAxis, worldSign, isClockwise ? (perspectiveFlip > 0) : (perspectiveFlip < 0), faceLabel);
  }

  double projectsSign(double val) => (val.abs() < 0.000001) ? 1 : val.sign;
}

class _FaceData {
  final Widget widget;
  final double z;
  _FaceData(this.widget, this.z);
}
