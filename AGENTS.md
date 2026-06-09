# Agent Onboarding Guide: Point Cloud & Grid Surface Helpers

Welcome, Agent. This repository is a workspace for modeling contact dynamics using **Point Clouds (PC)** and **Grid Surfaces (GS)** in **Simscape Multibody (SSMB)**. This guide provides the structure, workflows, and command cheat sheets needed to parse, maintain, and expand this project.

---

## 🗺️ Codebase Map

### Directory Reference
- **[`Libraries/`](file:///y:/AntiGravity/point-cloud-and-grid-surface-helpers/Libraries/)**: Core library containing `PC_GS_SSMB.slx`.
- **[`Models/`](file:///y:/AntiGravity/point-cloud-and-grid-surface-helpers/Models/)**: Verification and demonstration Simulink models (e.g., stairs, bearings, terrains).
- **[`CAD/`](file:///y:/AntiGravity/point-cloud-and-grid-surface-helpers/CAD/)**: 3D STL geometries representing road surfaces (Kyalami, Silverstone, Hockenheim, Nordschleife).
- **[`Scripts/`](file:///y:/AntiGravity/point-cloud-and-grid-surface-helpers/Scripts/)**: High-level scripts (data extraction, performance benchmarking, lookup tables).
- **[`Scripts/Functions/`](file:///y:/AntiGravity/point-cloud-and-grid-surface-helpers/Scripts/Functions/)**: Core algorithmic back-end for spline extrusion, point cloud generation, and TIFF/STL terrain processing.
- **[`PointCloudScans/`](file:///y:/AntiGravity/point-cloud-and-grid-surface-helpers/PointCloudScans/)**: Raw `.pcd` point scans and rasterization tools.

---

## ⚙️ Key Mechanisms & Workflows

### 1. Smart Mask Caching (`cacheMaskHeavyComputation.m`)
Simulink frequently re-runs mask initialization code. To avoid rendering delays and UI stutter, the library uses [cacheMaskHeavyComputation.m](file:///y:/AntiGravity/point-cloud-and-grid-surface-helpers/Scripts/Functions/cacheMaskHeavyComputation.m):
- It hashes input parameters (e.g., `inputPoints`, `R`, `resolution`).
- It uses a persistent map keyed on the block path (`gcb`) to store/retrieve results.
- **Rule**: When adding or updating a masked block, verify that heavy math (like STL parsing, triangulation, or plotting) is wrapped in the `shouldCompute` condition.

### 2. Block Mask Metadata Databases
We maintain JSON files documenting every block mask and its scripts:
- **[`PC_GS_SSMB_mask_extraction.json`](file:///y:/AntiGravity/point-cloud-and-grid-surface-helpers/PC_GS_SSMB_mask_extraction.json)**: Full database of all 471 masked blocks.
- **[`PC_GS_SSMB_mask_code_only.json`](file:///y:/AntiGravity/point-cloud-and-grid-surface-helpers/PC_GS_SSMB_mask_code_only.json)**: Filters and lists only blocks containing custom mask initialization code, variables, or callbacks.
- **How to Refresh**: Run the utility function `extractMasksToJson()` in MATLAB to reload the library, query masks, and write fresh JSON outputs.

---

## 🛠️ Common MATLAB & Simulink Commands

### Project & Paths
```matlab
% Open the MATLAB Project (automatically sets up all paths and startup shortcuts)
openProject('PointCloudAndGridSurfaceHelper.prj');

% Query the active project
proj = currentProject;
```

### Library Operations
```matlab
% Load the library without opening the GUI window
load_system('Libraries/PC_GS_SSMB.slx');

% Unlock the library for editing
set_param('PC_GS_SSMB', 'Lock', 'off');

% Lock and save the library
set_param('PC_GS_SSMB', 'Lock', 'on');
save_system('PC_GS_SSMB');
```

### Block & Mask Querying
```matlab
% Find all masked blocks recursively
blocks = find_system('PC_GS_SSMB', 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Mask', 'on');

% Query mask initialization code
init_code = get_param(block_path, 'MaskInitialization');

% Query mask parameter names
param_names = get_param(block_path, 'MaskNames');

% Force evaluation of a block's mask initialization
% (Change a parameter value to trigger validation/execution)
set_param(block_path, 'R', '16');
```

### Simulation & Timing
```matlab
% Run a simulation programmatically
sim('Terrain');

% Run a simulation and capture timings
tic;
sim('Rotor_Delevitation');
execution_time = toc;
```

---

## 🧭 Guidelines for AI Agents

1. **Keep Comments in English**: All MATLAB code, helper scripts, and class files must contain explicit, clear comments in English.
2. **Simscape Block Manipulation**: When adding and connecting Simscape blocks programmatically, **do not** use `add_line` from the MATLAB scripting language. Simscape blocks require connection via physical nodes.
3. **Keep Capture Code Off-screen**: When generating mask images using `getframe`, keep the figure hidden (`'Visible', 'off'`). Modern MATLAB supports off-screen capture, avoiding disruptive window pop-ups during parameter updates.
