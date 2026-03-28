# Rubik's Cube Game Implementation Plan

This plan details the process of building a Rubik's Cube game using Flutter alongside Toyota's **Fluorite** 3D game engine, validating it locally, and ultimately deploying the experience to `cube.mavgo.com`.

## Phase 1: Local Setup & Development

### 1. Project Initialization
- Create a new, clean Flutter project specifically tailored for this game:
  ```bash
  flutter create --platforms=web,macos rubikcube
  cd rubikcube
  ```

### 2. Integrate the Fluorite Engine
Toyota Connected North America designed Fluorite as a high-performance, open-source 3D engine using Google's Filament renderer, seamlessly integrating with Flutter.
- Add the engine dependency in your `pubspec.yaml` (using the official repository or package).
- Import the core libraries required for the 3D canvas and Entity-Component-System (ECS) that Fluorite utilizes.
*(Note: As of early 2026, Fluorite is announced but not yet publicly released on pub.dev or GitHub. This step requires access to the Fluorite source code, or we can use a temporary 3D Flutter renderer until release).*

### 3. Core Game Logic (Dart)
- **State Representation:** Create a Dart data structure representing the 3x3x3 grid (27 "cubies"). Each cubie tracks its current colors on each face and its spatial coordinates.
- **Move Sequences:** Implement algorithms for standard Rubik's Cube notation (U, D, L, R, F, B and their primes).
- **Scrambling & Solving:** Implement a random scrambler generator and basic victory condition logic.

### 4. 3D Rendering (Fluorite)
- **Asset Loading vs. Procedural Mesh:** Decide whether to load a `glb`/`gltf` 3D model of a Rubik's cube or programmatically generate 27 individual rounded cubes with specific materials using Fluorite's mesh builders.
- **Camera Configuration:** Position a perspective camera to keep the cube centered with an isometric or customizable viewing angle.
- **Lighting:** Set up physically based rendering (PBR) lighting using Fluorite's Filament-backed lighting nodes to give the cube a realistic, tactile look.

### 5. Interaction & Drag Controls
- Map Flutter `GestureDetector` logic (pan, drag, swipe) to the 3D space via raycasting through Fluorite.
- Implement two interaction states:
  - **Camera Rotation:** Dragging the background orbits the camera around the cube.
  - **Layer Slicing:** Dragging specific rows/columns on the cube faces triggers a smooth animated rotation of that "slice".

### 6. Local Testing
- Serve the application locally for instant feedback:
  ```bash
  flutter run -d macos   # For native profiling
  flutter run -d chrome  # To verify web constraints
  ```

---

## Phase 2: Publishing to `cube.mavgo.com`

Since you run a robust automated setup via Cloudflare for the Mavgo platform, we will use Cloudflare Pages to host the compiled Flutter Web application.

### 1. Compile Flutter for the Web
Once the game is perfectly playable locally, generate the highly-optimized WASM/WebGL static bundle:
```bash
flutter build web --release --web-renderer canvaskit
```

### 2. Configure Cloudflare Deployment
- We will leverage `wrangler` (your established toolset) to securely deploy the web build.
- **Create the Project:** Initialize a Cloudflare pages project for the cube payload.
  ```bash
  npx wrangler pages project create cube-mavgo
  ```
- **Deploy:**
  ```bash
  npx wrangler pages deploy build/web --project-name cube-mavgo
  ```

### 3. Setup Custom Domain Routing
- In your Cloudflare Dashboard (or via wrangler domain configurations), map the newly deployed `cube-mavgo.pages.dev` destination to your desired custom domain: **`cube.mavgo.com`**.
- Ensure DNS records propagate and TLS certificates execute automatically.
