import 'package:flutter/material.dart';
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
      title: 'Rubik\'s Cube (Florite View)',
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

class _RubiksCubeScreenState extends State<RubiksCubeScreen> {
  // Initial isometric perspective
  double rx = -0.6;
  double ry = 0.6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Florite Simulator: Rubik\'s Cube',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.1),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "Drag to rotate the cube in 3D space",
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          Expanded(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  // Sensitivity multipliers for rotation
                  ry -= details.delta.dx * 0.01;
                  rx += details.delta.dy * 0.01;
                });
              },
              child: Container(
                color: Colors.transparent, // Captures drag events across whole screen
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  // We pass rx and ry directly to the cube so it can sort the faces dynamically
                  child: RubiksCube3D(size: 240, rx: rx, ry: ry),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 40.0),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  rx = -0.6; 
                  ry = 0.6;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A4E69),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text("Reset Camera"),
            ),
          )
        ],
      ),
    );
  }
}

class RubiksCube3D extends StatelessWidget {
  final double size;
  final double rx;
  final double ry;

  const RubiksCube3D({
    super.key, 
    this.size = 200,
    required this.rx,
    required this.ry,
  });

  @override
  Widget build(BuildContext context) {
    // Generate the global 3D transformation matrix from current drag state
    final globalTransform = Matrix4.identity()
      ..setEntry(3, 2, 0.001) // perspective
      ..rotateX(rx)
      ..rotateY(ry);

    // Standard Rubik's Colors: U=White, D=Yellow, F=Green, B=Blue, L=Orange, R=Red
    List<_FaceData> faces = [
      _createFace(Colors.blueAccent,   Matrix4.identity()..translate(0.0, 0.0, -size/2)..rotateY(pi), globalTransform),
      _createFace(Colors.orangeAccent, Matrix4.identity()..translate(-size/2, 0.0, 0.0)..rotateY(-pi / 2), globalTransform),
      _createFace(Colors.yellowAccent, Matrix4.identity()..translate(0.0, size/2, 0.0)..rotateX(-pi / 2), globalTransform),
      _createFace(Colors.white,        Matrix4.identity()..translate(0.0, -size/2, 0.0)..rotateX(pi / 2), globalTransform),
      _createFace(Colors.redAccent,    Matrix4.identity()..translate(size/2, 0.0, 0.0)..rotateY(pi / 2), globalTransform),
      _createFace(Colors.greenAccent,  Matrix4.identity()..translate(0.0, 0.0, size/2), globalTransform),
    ];

    // SORTING EXPLANATION:
    // Without Z-sorting, Flutter's Stack will draw faces arbitrarily causing visual overlapping bugs 
    // at certain rotation angles. We dynamically calculate each face's true Z depth via the 
    // combined local/global transform matrix and sort them before rendering.
    faces.sort((a, b) => b.z.compareTo(a.z));

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: faces.map((f) => f.widget).toList(),
      ),
    );
  }

  _FaceData _createFace(Color color, Matrix4 localTransform, Matrix4 globalTransform) {
    // Combine the single face's local orientation with the entire cube's global rotation
    final totalTransform = globalTransform.clone()..multiply(localTransform);
    
    // Extract the final Z translation depth. The Z value maps the origin of the face in 3D space.
    final z = totalTransform.getTranslation().z;

    final widget = Transform(
      transform: totalTransform,
      alignment: Alignment.center,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          border: Border.all(color: Colors.black87, width: 3), // Thicker border between faces
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, spreadRadius: 1, blurRadius: 2, offset: Offset(0, 1))
                ]
              ),
            );
          },
        ),
      ),
    );

    return _FaceData(widget, z);
  }
}

class _FaceData {
  final Widget widget;
  final double z;
  _FaceData(this.widget, this.z);
}
