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
  double rx = -0.5;
  double ry = 0.5;

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
                  child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective
                      ..rotateX(rx)
                      ..rotateY(ry),
                    alignment: Alignment.center,
                    child: const RubiksCube3D(size: 240),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 40.0),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  rx = -0.5; 
                  ry = 0.5;
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
  const RubiksCube3D({super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    // Standard Rubik's Colors: U=White, D=Yellow, F=Green, B=Blue, L=Orange, R=Red
    // Note: Due to Flutter's 2D canvas origin, without z-sorting some back faces 
    // might overlap the front at extreme angles, but for typical front-facing
    // views this provides a fantastic native-rendered 3D illusion!
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back Face (Blue)
          _buildFace(Colors.blueAccent, size, Matrix4.identity()..translate(0.0, 0.0, -size/2)..rotateY(pi)),
          // Left Face (Orange)
          _buildFace(Colors.orange, size, Matrix4.identity()..translate(-size/2, 0.0, 0.0)..rotateY(-pi / 2)),
          // Bottom Face (Yellow)
          _buildFace(Colors.yellowAccent, size, Matrix4.identity()..translate(0.0, size/2, 0.0)..rotateX(-pi / 2)),
          // Top Face (White)
          _buildFace(Colors.white, size, Matrix4.identity()..translate(0.0, -size/2, 0.0)..rotateX(pi / 2)),
          // Right Face (Red)
          _buildFace(Colors.redAccent, size, Matrix4.identity()..translate(size/2, 0.0, 0.0)..rotateY(pi / 2)),
          // Front Face (Green)
          _buildFace(Colors.greenAccent, size, Matrix4.identity()..translate(0.0, 0.0, size/2)),
        ],
      ),
    );
  }

  Widget _buildFace(Color color, double size, Matrix4 transform) {
    return Transform(
      transform: transform,
      alignment: Alignment.center,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 2,
                  )
                ]
              ),
            );
          },
        ),
      ),
    );
  }
}
