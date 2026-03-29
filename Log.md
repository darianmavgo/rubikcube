# Rubik's Cube Development Log

## Key Accomplishments (Last 3 Hours)

1. **Hit-Testing Bounds Fix**
   - Discovered and fixed the issue where border cubies were ignoring clicks. Flutter's 2D `Stack` engine was evaluating hit zones *before* the 3D properties pushed the blocks outward. Solved by expanding the invisible structural layout of the `Stack` by 600%.

2. **1-Second Fluid Rotations**
   - Decoupled state updates from instantaneous matrix multiplication.
   - Initialized a `SingleTickerProviderStateMixin` with a 1-second `CurvedAnimation`. Slices now animate smoothly across the screen and only permanently "bake" their matrices upon completion.

3. **Unique Cubie & Face Tracking**
   - Evolved from generic "Red Face" tracking to assigning every one of the 27 physical blocks a persistent Unique ID (0 to 26).
   - Upgraded console logging to track precise interactions with millisecond timestamps (e.g., `Face G14 | Axis y | Slice -1`).

4. **"Sticker" Label Rendering**
   - Transformed the face identifiers into realistic "stickers".
   - Engineered mathematical orientation checks to inject local scale corrections `(-1, 1)` into the rendering tree. This guarantee that face text remains upright and legible regardless of how the block translates behind the scene.

5. **Strict "Press and Drag" Physics**
   - Deprecated ambiguous single left/right-click rotations.
   - Refactored user interaction into a rigorous vector-sweep algorithm. Swiping across the cube directly computes the `dx/dy` vector against the face's 3D normal to logically determine the intended axis and slice of rotation.

6. **Automated Subagent Browser Testing**
   - Authored the `TestPlan.md` and successfully deployed a headless local subagent to record a 10-second proof video of complex block interactions, swipes, and structural orbits verifying the UI held up in a simulated browser.

7. **Telemetry Heads-Up Display**
   - Injected a persistent, real-time "Debug Telemetry" panel showing Live Camera Pitch (`rx`), Orbit (`ry`), active interaction axes, and target angle targets.

8. **2D Overlay Projection for Axis Vectors**
   - Remapped the global system to establish XY as the tabletop plane and Z as vertical height.
   - Built an algorithm to render 3D vector arrows pointing to the X, Y, and Z limits.
   - Completely defeated 3D matrix distortion by projecting the 3D axis tips into flat 2D screen coordinates, rendering crisp UI labels and dynamically angled arrowheads that float perfectly above the geometry.

---

## What Made the Rotations and Axes So Difficult?

The core challenge of this project lies in the complex overlap between **Local Object Space**, **Global World Space**, and **2D Screen Projection**:

1. **Relative "Clockwise" Perspectives**
   - Rotating a slice clockwise on the front face feels intuitive. However, rotating the identical slice from the *back* of the cube requires the exact opposite mathematical spin. To fix this, we had to extract the global camera angle (`rx/ry`), project the clicked face's world normal onto the viewport, and dynamically invert the rotation polarity if the cube face's depth proved it was pointing away from the user.

2. **Scrambled Axis Misidentification**
   - Once a cubie spins away from its starting position, it carries its own local XYZ coordinate system with it. Early logic was confused because a face pointing UP might still think its local normal was `(1,0,0)` (the X-axis).
   - We resolved this by isolating the pure **3x3 orientation sub-matrix** from the block's `Matrix4`. By transforming the local normal through this explicit sub-matrix, the engine could definitively calculate its true world-axis alignment at any moment.

3. **Flat UI Components Crushed by 3D Perspective**
   - The ultimate breakthrough was abandoning 3D widgets entirely for UI overlays. Instead of putting the text *in* the 3D world, we asked the 3D world, *"What is the exact 2D pixel coordinate of this 3D point?"* By extracting the `(p.x / p.w)` translation mapping and projecting a 2D vector for the arrow trajectory, we decoupled the UI from the 3D renderer, resulting in beautifully aligned, distortion-free vector annotations.

---

## What Else Failed (Retrospective)

1. **Compilation Crashes Due to Disconnected Architectures**
   - We experienced syntax crashes (e.g., *Too many positional arguments*) because the `GestureDetector` logic within the 3D cube widget was attempting to pass data (like `faceLabel`) back to the parent `_onFaceClicked` and `_onPanUpdate` callbacks, but we forgot to synchronize the rigorous `typedef` signatures between the two separate class definitions.
   - We also mistakenly attempted to call `.getValues()` on a `Matrix4` object, assuming the API behaved like generic arrays. The framework threw `Method not found`, forcing us to switch to the mathematically correct native `.transform3()` method instead.

2. **HitTest Bounds Limitation (Initial Failure)**
   - The initial attempt to fix "false off cube click detection" failed because we didn't realize Flutter's hit testing fundamentally respects the *untransformed* bounding box of the base `Stack`. Even when we correctly zoomed the camera out, clicks on the outer edges of the 3D-transformed corner cubies were silently swallowed by the background layer. Simply adding an explicit, massively padded `SizedBox` with `Clip.none` underneath the blocks resolved this geometry clipping.

3. **Axes Annotations Rendering Failure**
   - We originally tried to inject `Icon(Icons.arrow_upward)` and flat `Text` directly into the `Matrix4.identity()` 3D projection rendering tree. This failed spectacularly: the font was completely unreadable, heavily skewed by the perspective matrix, and mapped the Z-axis (which was intended to be vertical) to point downwards on the screen due to Flutter's native inverted Y-axis. We had to completely scrap the 3D string geometry rendering model and build the pure flat 2D viewport projection overlay instead to achieve "sticker" quality clarity.

4. **Browser Subagent Testing Limitations**
   - While the headless browser subagent successfully executed the complex click and drag sweeps, its contextual logic failed twice when attempting to run generic `replace_file_content` system commands mid-test, throwing `CORTEX_STEP_STATUS_ERROR` internal faults. While the visual tests were executed flawlessly, it highlighted that the testing bot is fragile when trying to execute abstract system interactions mid-navigation.
