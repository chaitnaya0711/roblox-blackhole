# Roblox Black Hole Simulation

A real-time gravitational lensing and black hole visualization in Roblox using `EditableMesh` and numerical geodesic integration.

## Features
- **Accretion Disk Rendering**: Dynamic multi-order disk imaging with Doppler beaming, gravitational redshift, and blackbody color lookup.
- **Gravitational Lensing**: Real-time relativistic bending of background starfields and secondary images via precomputed geodesic tables (Runge-Kutta 4 integration).
- **Photon Sphere & Event Horizon**: Lensed photon ring with relativistic brightness asymmetry and central shadow masking.
- **Low-Graphics Compatibility**: Configured with `RenderFidelity.Precise` and anchored camera focus to prevent low-graphics LOD decimation or distance culling in Roblox Studio and live clients.
- **Interactive Camera**: Smooth orbit, pitch, and zoom controls.

## Project Structure
- `src/client/BlackHole/init.client.luau` - Main client lifecycle, camera tracking, and render loop
- `src/client/BlackHole/Modules/`
  - `CameraRig.luau` - Orbit and input handling
  - `Color.luau` - Blackbody radiation color curves and tone mapping LUT
  - `Config.luau` - Physical and visual constants
  - `DiskImage.luau` - Disk mesh generation, vertex redistribution, and projection
  - `DiskTexture.luau` - Procedural noise lattice for disk turbulence
  - `Geodesics.luau` - Geodesic ray integration (RK4) and impact parameter lookup tables
  - `Loading.luau` - Initial precomputation progress screen
  - `MeshUtil.luau` - EditableMesh helpers and geometric projections
  - `PhotonRing.luau` - Photon sphere mesh and relativistic intensity modulation
  - `Scene.luau` - Environment lighting, skybox, and camera setup
  - `Shadow.luau` - Horizon shadow mask disc
  - `Stars.luau` - Background starfield deflection and Einstein ring secondary imaging

## Getting Started

### Using Rojo
1. Install [Rojo](https://rojo.space/).
2. Serve the project:
   ```bash
   rojo serve
   ```
3. Connect via the Rojo plugin in Roblox Studio.

### Building Place File
To compile directly into a `.rbxl` place file:
```bash
rojo build default.project.json -o "BlackHole.rbxl"
```
