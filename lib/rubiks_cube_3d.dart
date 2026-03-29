import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'dart:math';

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
    
    // Add explicitly pointing flat text markers to the positive ends
    _addAxisLabel(faces, globalTransform, 320, 0, 0, Colors.redAccent, "X Axis\n(Breadth)");
    _addAxisLabel(faces, globalTransform, 0, 320, 0, Colors.greenAccent, "Y Axis\n(Depth)");
    _addAxisLabel(faces, globalTransform, 0, 0, 320, Colors.blueAccent, "Z Axis\n(Vertical)");
  }

  void _addPoint(List<_FaceData> faces, Matrix4 globalTransform, double tx, double ty, double tz, Color color) {
    final trans = globalTransform.clone()..translate(tx, ty, tz);
    faces.add(_FaceData(
      Transform(
        transform: trans, 
        alignment: Alignment.center,
        child: IgnorePointer(child: Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)))
      ), 
      trans.getTranslation().z
    ));
  }

  void _addAxisLabel(List<_FaceData> faces, Matrix4 globalTransform, double tx, double ty, double tz, Color color, String text) {
      // 1. Calculate the final end point of the axis in screen space
      Vector4 p1 = Vector4(tx, ty, tz, 1.0);
      globalTransform.transform(p1);
      
      // 2. Calculate a second point slightly behind the tip to build a 2D line vector
      double mag = sqrt(tx*tx + ty*ty + tz*tz);
      double cx = tx == 0 ? 0 : tx - (tx/mag * 20);
      double cy = ty == 0 ? 0 : ty - (ty/mag * 20);
      double cz = tz == 0 ? 0 : tz - (tz/mag * 20);
      
      Vector4 p0 = Vector4(cx, cy, cz, 1.0);
      globalTransform.transform(p0);

      // Extract raw 2D screen coordinates
      double x1 = p1.x / p1.w; double y1 = p1.y / p1.w;
      double x0 = p0.x / p0.w; double y0 = p0.y / p0.w;

      // 3. Compute absolute screen angle of the drawn line
      double dx = x1 - x0;
      double dy = y1 - y0;
      double screenAngle = atan2(dy, dx); 
      
      faces.add(_FaceData(Transform(
        transform: Matrix4.identity()..translate(x1, y1, 0.0), 
        alignment: Alignment.center,
        child: IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Draw the Arrow Head, perfectly flat against the screen, pointing along the line's visual trajectory
              Transform.rotate(
                angle: screenAngle + (pi / 2), // Maps default Icons.arrow_upward (-Y) to the computed line angle
                child: Icon(Icons.arrow_upward, color: color, size: 40, shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xDD111111), borderRadius: BorderRadius.circular(6), border: Border.all(color: color, width: 1.5)),
                child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
      ), p1.z / p1.w));
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
