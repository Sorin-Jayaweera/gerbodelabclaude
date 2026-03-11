# Phonon Mode Analysis for Colloidal Crystals

Analysis tools for studying vibrational modes in simulated colloidal crystal monolayers.

> **Note**: For comprehensive project documentation, physics background, and Claude Code continuation guide, see the main [README.md](../README.md) in the repository root.

## Overview

This package provides comprehensive tools to analyze phonon modes from **sinusoidally-driven simulations** of colloidal crystals. The project supports multiple domain types (chevron, stripe, random, frustrated) and drive directions (X-side, Y-top). Key capabilities:

- **Interactive Viewer**: Real-time simulation exploration with `interactive_simulation_viewer.m`
- **Bode Analysis**: Amplitude and phase vs position at drive frequency
- **Fourier Analysis**: Power spectral analysis of particle displacements
- **Penetration Depth**: Exponential decay fits for wave attenuation
- **Dispersion Relations**: Compute ω(k) relationships via 2D structure factor
- **Mode Visualization**: See how particles move at each frequency
- **Defect Mode Analysis**: Study how defects localize vibrational energy
- **Comparison Videos**: Side-by-side lattice type and drive direction comparisons

## Quick Start

```matlab
% Add path and get configuration
addpath(pwd);
paths = get_paths();

% Launch interactive viewer (main tool)
interactive_simulation_viewer

% Or run complete analysis pipeline
run_master_analysis

% Load simulation data manually:
load(fullfile(sim_path, 'plist.mat'));
xyz = plist2xyz_auto(plist, 1);  % [N_particles, 3, N_frames], skip=1

% Wave visualization
x0 = mean(squeeze(xyz(:,1,1:10)), 2);
y0 = mean(squeeze(xyz(:,2,1:10)), 2);
visualize_wave_propagation(xyz, x0, y0, 1:10:100, 'myoutput');

% Buckled layer analysis
results = analyze_buckled_modes(xyz, dt, lattice_constant);
```

## Key Functions

### Interactive Tools

| File | Description |
|------|-------------|
| `interactive_simulation_viewer.m` | Main GUI - view/compare all simulations |
| `analysis_viewer.m` | Browse analysis results with descriptions |
| `interactive_kymograph_viewer.m` | Specialized kymograph viewer |

### Master Scripts

| File | Description |
|------|-------------|
| `run_master_analysis.m` | Complete pipeline: setup, fix data, videos, analysis |
| `run_all_simulations.m` | Run all 7 sim types × 20 frequencies |
| `run_all_simulations_parallel.m` | Parallel version using parfor |

### Analysis Functions

| File | Description |
|------|-------------|
| `analyze_frequency_response.m` | Bode-style amplitude/phase analysis |
| `analyze_phonon_modes.m` | Fourier power spectrum analysis |
| `compute_dispersion_2d.m` | Full 2D S(k,ω) structure factor |
| `compute_dynamical_matrix.m` | Harmonic approximation dynamical matrix |
| `compute_velocity_autocorrelation.m` | VACF and density of states |
| `analyze_defect_modes.m` | Localized modes at coordination defects |
| `analyze_buckled_modes.m` | Acoustic/optical modes in buckled layers |

### Visualization & Video

| File | Description |
|------|-------------|
| `visualize_wave_propagation.m` | Kymographs, animations, wave speed |
| `create_lattice_comparison_videos.m` | Side-by-side lattice comparisons |
| `create_drive_comparison_videos.m` | X vs Y drive direction comparisons |

### Utilities

| File | Description |
|------|-------------|
| `get_paths.m` | Cross-platform path configuration (Windows/Linux) |
| `plist2xyz_auto.m` | Convert plist to xyz format |
| `verify_data.m` | Data integrity checks |

## Data Format

### Input: plist
The simulation outputs `plist`, an Nx4 array:
- Column 1-3: x, y, z coordinates
- Column 4: frame number

### Converted: xyz
Use `plist2xyz_auto(plist, frame_skip)` to get a 3D array:
- Dimension 1: particle index (1 to N_particles)
- Dimension 2: coordinate (1=x, 2=y, 3=z)
- Dimension 3: frame number (1 to N_frames)

Note: z is scaled by particle diameter (10 pixels in simulation).

## Physical Parameters

| Parameter | Simulation | Notes |
|-----------|------------|-------|
| Particle diameter | 10 pixels | Simulation units |
| Looseness | 1.06 | Lattice expansion factor |
| Lattice constant | ~10.6 px | diameter × looseness |
| zmax | 0.45 | Max buckling amplitude |
| dt per step | 0.05 | - |
| Data save frequency | 2 | Save every 2 frames |
| Drive amplitude | 2.0 pixels | Sinusoidal drive |
| Drive/fixed width | 25 pixels | Edge boundary region |
| Total frames | 20,000 | Per simulation |

## Triangular Lattice Directions

For a 2D triangular lattice, the three principal crystallographic directions are:
- **0°**: Along the a₁ lattice vector (dense row)
- **60°**: Along the a₂ lattice vector
- **120°**: Third equivalent direction (= -60°)

Impulses along different directions probe different mode polarizations due to lattice anisotropy.

## Key Physics

### Dispersion Relation
For a triangular lattice with harmonic springs:
- **Acoustic modes**: ω → 0 as k → 0 (sound waves)
- **Optical modes** (buckled): finite ω at k = 0 (up/down oscillations)

### Participation Ratio
Measures mode localization:
- PR = 1: All particles participate equally (extended mode)
- PR = 1/N: Only one particle moves (localized mode)

### Defect Modes
Coordination defects (5-7 pairs) create localized vibrational modes that can:
- Scatter propagating phonons
- Store energy locally
- Affect thermal transport

## Simulation Types

Seven simulation configurations across 20 frequencies (0.0004 to 0.10 oscillations/frame):

| Name | Folder | Drive Direction | Domain Type |
|------|--------|-----------------|-------------|
| chevron_side | drivensinesims | X (left edge) | Zigzag/Chevron |
| stripe_side | stripesinesims | X | Parallel stripes |
| random_side | randomsinesims | X | Random domains |
| frust_side | frustsinesims | X | Frustrated zigzag |
| chevron_top | topdrivensims | Y (top edge) | Zigzag/Chevron |
| stripe_top | stripetopsims | Y | Parallel stripes |
| frust_top | frusttopsims | Y | Frustrated zigzag |

## Example: Running Simulations

```matlab
% Run all simulations (sequential)
run_all_simulations

% Run with parallel processing
run_all_simulations_parallel

% Run a single simulation type
run_sinusoidal_sim('stripe_side', 0.005)  % stripe X-driven at f=0.005
```

## Future Work

See the main [README.md](../README.md) for the complete task list. Key priorities:

- Complete random_side simulations (some frequencies may be missing)
- Run dispersion analysis on all completed simulations
- Generate summary plots comparing all lattice types
- Extract wavelengths and build dispersion curves ω(k)

## References

- Wang thesis: Brownian dynamics fundamentals
- Ashcroft & Mermin: Solid state physics, phonon theory
- See main README for additional online resources

## Author

Gerbode Lab, Harvey Mudd College, 2026
