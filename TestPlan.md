# Rubik's Cube Interaction Test Plan

## Objective
Verify the mathematical accuracy of Face Selection, Axis Detection, and Rotation Direction across different viewing angles using a 10-step browser automation script.

## The 10 Test Moves

1. **Test Front Face Clockwise (Z-Axis)**
   - **Action**: Left-click Center Green Face (G14).
   - **Expected**: Entire Z-slice rotates geometrically clockwise relative to the viewer. Console logs `Axis z | Direction: Clockwise`.
2. **Test Front Face Counter-Clockwise (Z-Axis)**
   - **Action**: Right-click Center Green Face (G14).
   - **Expected**: Entire Z-slice rotates geometrically counter-clockwise.
3. **Test Top Face Clockwise (Y-Axis)**
   - **Action**: Left-click Center Yellow Face (Y16).
   - **Expected**: Entire Y-slice rotates clockwise. Console logs `Axis y | Direction: Clockwise`.
4. **Test Right Face Clockwise (X-Axis)**
   - **Action**: Left-click Center Red Face (R22).
   - **Expected**: Entire X-slice rotates clockwise. Console logs `Axis x | Direction: Clockwise`.
5. **Test Edge Cubie Interaction (Corner Focus)**
   - **Action**: Left-click Top-Right Front Corner (G26).
   - **Expected**: Detects Z-axis correctly, rotates Front Slice clockwise.
6. **Test Horizontal Swipe (Y-Axis Sweep)**
   - **Action**: Click and drag horizontally across the middle Green Faces.
   - **Expected**: The radial sweep algorithm detects horizontal motion and rotates the corresponding Y-axis slice.
7. **Test Vertical Swipe (X-Axis Sweep)**
   - **Action**: Click and drag vertically down the Red faces.
   - **Expected**: The radial sweep algorithm detects vertical motion and rotates the corresponding X-axis slice towards the viewer.
8. **Test Global Camera Orbit**
   - **Action**: Click and drag starting completely off the cube (on the dark background).
   - **Expected**: Interaction is caught by the background gesture detector; camera orbits around the cube to reveal the Blue (B) and White (W) hidden faces.
9. **Test Background Perspective Inversion Logic**
   - **Action**: Left-click Center Blue Face (B12).
   - **Expected**: The global perspective normalization mathematically recognizes the face is pointing *away* from the user and dynamically flips the perceived clockwise rotation to match the viewer's intuition.
10. **Test Scrambled Sub-Matrix Logic**
    - **Action**: Left-click a previously manipulated face (e.g., a Red face that now rests on the Top face).
    - **Expected**: The 3x3 orientation sub-matrix algorithm correctly evaluates that the face's normal is now pointing *Up* (Y-axis), and triggers a Y-axis rotation instead of its original X-axis constraint.

---
**Status**: Pending browser subagent URL.
