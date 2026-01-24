# Phonon Mode Analysis for Colloidal Crystals

Analysis tools for studying vibrational modes in simulated colloidal crystal monolayers.

## Overview

This package provides comprehensive tools to analyze phonon modes from impulse response simulations of colloidal crystals. Key capabilities:

- **Power Spectral Analysis**: Extract frequency content from particle displacements
- **Dispersion Relations**: Compute ω(k) relationships
- **Mode Visualization**: See how particles move at each frequency
- **Defect Mode Analysis**: Study how defects localize vibrational energy
- **Buckled Monolayer Modes**: Special analysis for acoustic/optical modes in buckled layers
- **Wave Propagation**: Visualize and measure impulse wave propagation

## Quick Start

```matlab
% Run full analysis
run run_phonon_analysis

% Or analyze a single simulation manually:
load('mysim/plist.mat');
xyz = plist2xyz(plist);  % [N_particles, 3, N_frames]

% Basic analysis
analyze_phonon_modes  % Edit config section first

% Wave visualization
x0 = mean(squeeze(xyz(:,1,1:10)), 2);
y0 = mean(squeeze(xyz(:,2,1:10)), 2);
visualize_wave_propagation(xyz, x0, y0, 1:10:100, 'myoutput');

% Buckled layer analysis
results = analyze_buckled_modes(xyz, dt, lattice_constant);
```

## Functions

### Main Scripts

| File | Description |
|------|-------------|
| `run_phonon_analysis.m` | Master script - run this for complete analysis |
| `analyze_phonon_modes.m` | Single simulation Fourier analysis |
| `compare_impulse_directions.m` | Compare 0°, 60°, 120° impulse directions |

### Analysis Functions

| File | Description |
|------|-------------|
| `compute_dynamical_matrix.m` | Harmonic approximation dynamical matrix |
| `compute_velocity_autocorrelation.m` | VACF and density of states |
| `analyze_defect_modes.m` | Localized modes at coordination defects |
| `analyze_buckled_modes.m` | Acoustic/optical modes in buckled layers |

### Visualization

| File | Description |
|------|-------------|
| `visualize_wave_propagation.m` | Kymographs, animations, wave speed |

## Data Format

### Input: plist
The simulation outputs `plist`, an Nx4 array:
- Column 1-3: x, y, z coordinates
- Column 4: frame number

### Converted: xyz
Use `plist2xyz(plist)` to get a 3D array:
- Dimension 1: particle index (1 to N_particles)
- Dimension 2: coordinate (1=x, 2=y, 3=z)
- Dimension 3: frame number (1 to N_frames)

Note: z is scaled by particle diameter (10 pixels in simulation).

## Physical Parameters

| Parameter | Simulation | Experiment |
|-----------|------------|------------|
| Particle diameter | 10 pixels | 13 pixels |
| Looseness | 1.06 | varies |
| Lattice constant | ~10.6 px | ~13.8 px |
| dt per step | 0.05 | - |
| Data save frequency | 100 | - |

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

## Example Simulation Setup

```matlab
% TDsim impulse simulation
sim = TDsim();
sim.width = 500;
sim.height = 300;
sim.looseness = 1.06;
sim.zmax = 0.45;
sim.data_saving_frequency = 100;
sim.image_saving_frequency = 1000;
sim.num_frames = 60000;

sim.initialize_grains_unfrust('zigzags');

% Apply impulse to left edge
indices = sim.initial_particles(:,1) < 25;
particles = sim.initial_particles;
particles(indices, 1) = particles(indices, 1) + 0.5;  % 0.5 pixel impulse
sim.initial_particles = particles;
sim.current_particles = particles;

sim.run_sim('phonon_sim/', 1, true, true);
```

## Future Work

1. **Multiple layers**: Extend to 3D stacked crystals
2. **Defect engineering**: Systematic study of defect effects
3. **Nonlinear modes**: Anharmonic effects at large amplitudes
4. **Experimental validation**: Compare with tracked particle data

## References

- Wang thesis: Brownian dynamics fundamentals
- Standard solid-state physics: Ashcroft & Mermin for phonon theory

## Author

Gerbode Lab, 2026
