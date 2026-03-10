# Gerbode Lab - Colloidal Crystal Phonon Analysis Suite

## For Claude Code Instances: Project Context & Continuation Guide

This README documents the complete development history, physics context, codebase organization, and future work for this phonon analysis project. It is written to enable another Claude Code instance to immediately understand and continue this work.

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Physics Background](#physics-background)
3. [User Prompt History](#user-prompt-history)
4. [Codebase Organization](#codebase-organization)
5. [Key File Descriptions](#key-file-descriptions)
6. [Simulation Types](#simulation-types)
7. [Analysis Pipeline](#analysis-pipeline)
8. [Tasks Completed](#tasks-completed)
9. [Tasks Remaining / Future Work](#tasks-remaining--future-work)
10. [Online Resources for Research](#online-resources-for-research)
11. [Technical Notes](#technical-notes)

---

## Project Overview

This project provides a comprehensive MATLAB-based analysis suite for studying **phonon modes in simulated colloidal crystal monolayers**. The work is conducted in the **Gerbode Lab** at Harvey Mudd College, focusing on understanding vibrational wave propagation through different domain structures in 2D colloidal crystals.

### Core Research Questions
1. How do phonons (vibrational waves) propagate through colloidal crystals?
2. How does domain structure (chevron, stripe, random, frustrated) affect wave propagation?
3. What is the frequency-dependent penetration depth of driven waves?
4. How does drive direction (X-side vs Y-top) affect the response?
5. Can we measure dispersion relations ω(k) from simulations?

### Key Outcomes
- Interactive simulation viewer for real-time data exploration
- Comprehensive analysis pipeline (Bode, Fourier, penetration depth, MSD, anisotropy)
- Comparison video generation for different lattice types
- Support for 7 simulation configurations across 20 frequencies

---

## Physics Background

### What are Phonons?
Phonons are quantized vibrational modes in a crystal lattice. In colloidal crystals (micrometer-scale particles in suspension), thermal fluctuations and external driving create collective particle motions that can be analyzed as phonon modes.

### Triangular Lattice Structure
The simulations use a 2D triangular (hexagonal) lattice with:
- **Lattice constant**: ~10.6 pixels (particle diameter × looseness factor)
- **Particle diameter**: 10 pixels (simulation units)
- **Looseness factor**: 1.06 (slight expansion from close-packed)
- **Buckling (z-displacement)**: zmax = 0.45 allows out-of-plane motion

### Domain Structures Studied

| Domain Type | Description | Key Feature |
|-------------|-------------|-------------|
| **Chevron (Zigzag)** | Alternating up/down stripes forming V-patterns | Anisotropic wave propagation |
| **Stripe** | Parallel domain stripes | Direction-dependent transmission |
| **Random** | Randomly oriented domains | Scattering, disorder effects |
| **Frustrated (Frust)** | Geometrically frustrated zigzag | Enhanced scattering at boundaries |

### Dispersion Relation Theory
For a triangular lattice with harmonic springs:
- **Acoustic modes**: ω → 0 as k → 0 (sound waves, linear dispersion at low k)
- **Optical modes** (in buckled layers): finite ω at k = 0 (up/down particle oscillations)
- **Brillouin zone**: Hexagonal, with high-symmetry points Γ, M, K

### Key Physics Concepts

**Participation Ratio (PR)**
- PR = 1: All particles participate equally (extended mode)
- PR = 1/N: Only one particle moves (localized mode)
- Defects create localized modes with low PR

**Penetration Depth**
- Amplitude decays exponentially into crystal: A(x) = A₀ exp(-x/δ)
- δ (penetration depth) is frequency-dependent
- Higher frequencies → shorter penetration depth

**Anisotropy**
- X-displacement vs Y-displacement response ratio
- Reveals coupling between longitudinal and transverse modes

---

## User Prompt History

The following prompts were given during development (reconstructed from commit history and code comments):

### Phase 1: Initial Setup
1. "Create phonon analysis tools for colloidal crystal simulations"
2. "Set up sinusoidal driving simulations instead of impulse response"
3. "Run frequency sweeps from 0.0004 to 0.1 oscillations/frame"

### Phase 2: Simulation Infrastructure
4. "Add support for different domain types: stripes, random, zigzags, frustrated"
5. "Create top-driven (Y-direction) simulations in addition to side-driven (X)"
6. "Run overnight/weekend batch simulations across all frequencies"
7. "Add parallel processing for faster simulation runs"

### Phase 3: Visualization
8. "Create interactive simulation viewer with multiple panels"
9. "Add wavefront profile, kymograph, and particle position views"
10. "Support overlaying multiple simulations for comparison"
11. "Add video export functionality"
12. "Create comparison videos showing different lattice types side-by-side"

### Phase 4: Analysis
13. "Generate Bode plots (amplitude and phase vs position)"
14. "Compute Fourier power spectra at each position"
15. "Extract penetration depth from exponential fits"
16. "Calculate MSD (mean squared displacement) over time"
17. "Analyze X vs Y response anisotropy"

### Phase 5: Fixes and Improvements
18. "Fix frust_top simulations - dimensions were wrong (400x800 not 800x400)"
19. "Handle corrupt plist.mat files gracefully"
20. "Add cross-platform path support (Windows Z: drive vs Linux paths)"
21. "Fix video export losing overlaid simulations"
22. "Add robust error handling for long overnight runs"

### Phase 6: Documentation (Current)
23. "Make a detailed summary of all work in an overarching README for another Claude instance"

---

## Codebase Organization

```
gerbodelabclaude/
├── README.md                    # THIS FILE - comprehensive project documentation
├── .gitignore                   # Excludes large data files, images, videos
│
├── phonon_analysis/             # Main MATLAB code directory
│   ├── README.md                # Original technical README
│   │
│   ├── ===== MASTER SCRIPTS =====
│   ├── run_master_analysis.m    # Complete pipeline: setup, fix data, videos, analysis
│   ├── run_all_simulations.m    # Run all 7 sim types × 20 frequencies
│   ├── run_all_simulations_parallel.m  # Parallel version using parfor
│   │
│   ├── ===== INTERACTIVE VIEWERS =====
│   ├── interactive_simulation_viewer.m  # Main GUI (2500 lines) - view/compare sims
│   ├── analysis_viewer.m        # Browse analysis results with descriptions
│   ├── interactive_kymograph_viewer.m   # Specialized kymograph viewer
│   │
│   ├── ===== SIMULATION RUNNERS =====
│   ├── run_sinusoidal_sim.m     # Single sinusoidal driving simulation
│   ├── run_all_weekend.m        # Weekend batch runner with progress tracking
│   ├── run_dispersion_sweep.m   # Frequency sweep for dispersion
│   ├── run_frust_and_analysis.m # Frustrated lattice simulations
│   ├── run_topdriven_zigzag_sweep.m  # Y-driven chevron simulations
│   ├── run_stripe_domain_sweep.m     # X-driven stripe simulations
│   ├── run_stripe_top_sweep.m        # Y-driven stripe simulations
│   ├── run_random_domain_sweep.m     # Random domain simulations
│   ├── run_frust_stripe_side_sweep.m # Frustrated stripe X-driven
│   ├── run_frust_stripe_top_sweep.m  # Frustrated stripe Y-driven
│   ├── run_stripe_top_single.m       # Single frequency stripe top
│   ├── run_stripe_nodrive.m          # Control: stripe with no drive
│   ├── run_zigzag_nodrive.m          # Control: zigzag with no drive
│   │
│   ├── ===== ANALYSIS FUNCTIONS =====
│   ├── analyze_phonon_modes.m   # Main Fourier analysis
│   ├── analyze_frequency_response.m  # Bode-style frequency response
│   ├── analyze_dispersion_sweep.m    # Dispersion from frequency sweep
│   ├── analyze_buckled_modes.m       # Acoustic/optical mode separation
│   ├── analyze_defect_modes.m        # Localized modes at defects
│   ├── analyze_noise_floor.m         # Background noise characterization
│   ├── analyze_dispersion_for_batch.m  # Batch dispersion analysis
│   ├── analyze_freq_response_for_batch.m  # Batch frequency response
│   ├── run_phonon_analysis.m         # Wrapper for full analysis
│   ├── run_all_analysis.m            # Run analysis on all simulations
│   ├── run_full_analysis.m           # Comprehensive analysis (1500 lines)
│   │
│   ├── ===== COMPUTATION FUNCTIONS =====
│   ├── compute_dispersion_2d.m       # Full 2D S(k,ω) dispersion
│   ├── compute_dynamical_matrix.m    # Harmonic approximation
│   ├── compute_velocity_autocorrelation.m  # VACF and DOS
│   ├── hann_window.m                 # Hann window for FFT
│   ├── unwrap_periodic.m             # Phase unwrapping
│   │
│   ├── ===== VISUALIZATION =====
│   ├── visualize_wave_propagation.m  # Kymographs and animations
│   ├── animated_wave_profiles.m      # Animated wavefront profiles
│   ├── animated_frequency_comparison.m  # Multi-frequency animation
│   │
│   ├── ===== VIDEO GENERATION =====
│   ├── create_interesting_comparison_videos.m  # Cross-lattice comparisons
│   ├── create_drive_comparison_videos.m        # X vs Y drive comparisons
│   ├── create_lattice_comparison_videos.m      # Lattice structure comparisons
│   ├── create_lattice_comparison_images.m      # Static comparison images
│   ├── create_zigzag_massive_video.m           # Large chevron video
│   ├── create_zigzag_sidebyside_videos.m       # Side-by-side chevron
│   ├── stitch_frequency_videos.m               # Combine frequency videos
│   │
│   ├── ===== DATA HANDLING =====
│   ├── plist2xyz_auto.m              # Convert plist to xyz format
│   ├── convert_plist_to_xyz.m        # Explicit conversion
│   ├── generate_images_from_plist.m  # Generate images from data
│   ├── verify_data.m                 # Data integrity checks
│   │
│   ├── ===== UTILITIES =====
│   ├── get_paths.m                   # Cross-platform path configuration
│   ├── regenerate_figures.m          # Regenerate analysis figures
│   ├── generate_summary_figures.m    # Summary plots
│   ├── generate_all_experiment_images.m  # Batch image generation
│   ├── generate_phonon_report.m      # Generate physics report
│   ├── reorganize_batch_folder.m     # Folder restructuring
│   ├── compare_drive_directions.m    # X vs Y drive comparison
│   ├── compare_impulse_directions.m  # Impulse direction comparison
│   ├── compare_domain_dispersions.m  # Domain type comparison
│   │
│   ├── ===== DIAGNOSTIC/DEBUG =====
│   ├── check_frust_top_data.m        # Debug frust_top issues
│   ├── diagnose_frust_top.m          # Diagnose frust_top problems
│   ├── cleanup_frust_top.m           # Clean up frust_top data
│   ├── run_all_fixes.m               # Apply all fixes
│   ├── run_chevron_regenerate.m      # Regenerate chevron data
│
├── .claude/                     # Claude Code settings
│   └── settings.local.json
│
└── sims/                        # SIMULATION DATA (gitignored, on network drive)
    ├── drivensinesims/          # Chevron X-driven
    ├── stripesinesims/          # Stripe X-driven
    ├── randomsinesims/          # Random X-driven
    ├── frustsinesims/           # Frustrated X-driven
    ├── topdrivensims/           # Chevron Y-driven
    ├── stripetopsims/           # Stripe Y-driven
    └── frusttopsims/            # Frustrated Y-driven
```

---

## Key File Descriptions

### `interactive_simulation_viewer.m` (2,482 lines)
The main GUI application. Features:
- 7 simulation type checkboxes with separate X/Y axis selection
- Frequency slider (20 frequencies from 0.0004 to 0.10)
- View modes: Particles, Wavefront, Kymograph, Delaunay triangulation
- Playback controls with variable speed
- Multi-frequency overlay mode
- Video export with frame range selection
- Collapsible sidebar
- Sync pan/zoom across panels
- Caching for fast switching between simulations

### `run_master_analysis.m` (752 lines)
Complete analysis pipeline:
1. System setup (git pull, addpath, rehash)
2. Fix/regenerate corrupt xyz_data.mat from plist.mat
3. Create comparison videos
4. Generate all analysis plots for viewer

### `get_paths.m` (31 lines)
**Critical for cross-platform support**. Detects Windows vs Linux and returns:
```matlab
paths.root           % Repository root
paths.sims           % Simulation data folder
paths.colloid_work   % Colloid Work Folder (TDsim, BDsim code)
paths.simulations    % TDsim source
paths.phonon_analysis
paths.analysis_output
paths.interesting_videos
paths.bdsims
```

### `compute_dispersion_2d.m` (208 lines)
Computes full 2D dynamical structure factor S(k,ω):
- Reciprocal lattice vectors for triangular lattice
- k-space grid covering first Brillouin zone
- High-symmetry path: Γ → M → K → Γ
- FFT-based computation

---

## Simulation Types

### Configuration Summary

| Name | Folder | Format | Drive | Size |
|------|--------|--------|-------|------|
| chevron_side | drivensinesims | sinusoidal_f%.4f_a2.0 | X | 800×400 |
| stripe_side | stripesinesims | sinusoidal_f%.4f_a2.0_stripes | X | 800×400 |
| random_side | randomsinesims | sinusoidal_f%.4f_a2.0_random | X | 800×400 |
| frust_side | frustsinesims | frust_f%.4f_a2.0 | X | 800×400 |
| chevron_top | topdrivensims | topdriven_f%.4f_a2.0 | Y | 400×800 |
| stripe_top | stripetopsims | stripetop_f%.4f_a2.0 | Y | 800×400 |
| frust_top | frusttopsims | frusttop_f%.4f_a2.0 | Y | 400×800 |

### Frequencies
20 frequencies spanning 2.5 orders of magnitude:
```matlab
[0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009,
 0.001,  0.0012, 0.0015, 0.0018,
 0.002,  0.0025, 0.003,  0.004,  0.005,
 0.007,  0.01,   0.02,   0.05,   0.10]
```

### Simulation Parameters
```matlab
drive_amplitude = 2.0;        % Pixels
drive_width = 25;             % Pixels from driven edge
fixed_width = 25;             % Pixels (fixed boundary)
num_frames = 20000;           % Total simulation frames
data_saving_frequency = 2;    % Save every 2 frames
looseness = 1.06;             % Lattice expansion factor
zmax = 0.45;                  % Max buckling amplitude
```

---

## Analysis Pipeline

### 1. Data Loading
```matlab
% Load plist.mat and convert to xyz format
load(fullfile(sim_path, 'plist.mat'));
% xyz is [N_particles, 3, N_frames]
% Dimension 1: particle index
% Dimension 2: x=1, y=2, z=3
% Dimension 3: time frame
```

### 2. Preprocessing
```matlab
% Compute equilibrium positions (first 10 frames)
x0 = mean(xyz(:, 1, 1:10), 3);
y0 = mean(xyz(:, 2, 1:10), 3);

% Compute displacements
dx = squeeze(xyz(:, 1, :)) - x0;
dy = squeeze(xyz(:, 2, :)) - y0;
```

### 3. Analysis Types

**Bode Analysis**
- Bin particles by position (X for side-driven, Y for top-driven)
- FFT each bin's mean displacement
- Extract amplitude and phase at drive frequency
- Plot amplitude vs position, phase vs position

**Fourier Analysis**
- Power spectrum of mean displacement
- Identify peak frequency
- Compare to drive frequency

**Penetration Depth**
- Compute RMS amplitude per particle
- Bin by position
- Fit exponential decay: A(x) = A₀ exp(-x/δ)
- Extract δ (penetration depth)

**MSD (Mean Squared Displacement)**
- Track particle displacement from initial position
- Compute <Δr²> vs time

**Anisotropy**
- Compare X vs Y displacement amplitudes
- Histogram of amplitude ratios

---

## Tasks Completed

### Infrastructure
- [x] Cross-platform path support (Windows/Linux)
- [x] Git integration with auto-pull in master script
- [x] Robust error handling for overnight runs
- [x] Progress tracking and logging
- [x] Memory cleanup between simulations

### Simulations
- [x] All 7 simulation types implemented
- [x] 20 frequencies per type (140 total simulations)
- [x] Parallel processing support
- [x] Adaptive image saving (more for high frequencies)
- [x] Control simulations (no drive)

### Visualization
- [x] Interactive simulation viewer with all features
- [x] Analysis viewer with descriptions
- [x] Video export functionality
- [x] Comparison video generation
- [x] Multi-frequency overlay mode

### Analysis
- [x] Bode analysis (amplitude, phase vs position)
- [x] Fourier power spectra
- [x] Penetration depth extraction
- [x] MSD calculation
- [x] Anisotropy analysis
- [x] 2D dispersion S(k,ω) computation

### Bug Fixes
- [x] Fix frust_top dimensions (400×800)
- [x] Fix Y-driven wavefront position/y-axis
- [x] Handle corrupt plist.mat files
- [x] Fix video frame size consistency
- [x] Fix view mode switching panel sizes
- [x] Fix overlay preservation during export

---

## Tasks Remaining / Future Work

### High Priority
- [ ] **Complete random_side simulations** - Some frequencies may be missing
- [ ] **Validate stripe_top data** - Verify dimensions are correct
- [ ] **Run dispersion analysis** on all completed simulations
- [ ] **Generate summary plots** comparing all lattice types

### Analysis Extensions
- [ ] **Wavelength extraction** - Fit spatial oscillation to get λ, compute k = 2π/λ
- [ ] **Dispersion curves** - Plot ω vs k for each lattice type
- [ ] **Attenuation coefficients** - More sophisticated penetration analysis
- [ ] **Mode decomposition** - Separate longitudinal/transverse modes
- [ ] **Domain boundary effects** - Analyze scattering at domain walls

### Visualization
- [ ] **3D dispersion surface** - S(kx, ky) at fixed ω
- [ ] **Animated dispersion** - Sweep through frequencies
- [ ] **Participation ratio maps** - Localization visualization
- [ ] **Domain structure overlay** - Show domains on wave profiles

### Comparisons
- [ ] **Quantitative lattice comparison** - Statistical tests
- [ ] **Theoretical predictions** - Compare to harmonic theory
- [ ] **Experimental validation** - Compare to tracked particle data

### Code Quality
- [ ] **Unit tests** for analysis functions
- [ ] **Documentation** for each function
- [ ] **Performance profiling** for large datasets

---

## Online Resources for Research

### Phonon Physics
- **Ashcroft & Mermin** - Solid State Physics textbook (Chapter on phonons)
- Search: "phonon dispersion triangular lattice"
- Search: "dynamical structure factor colloidal crystal"

### Colloidal Crystal References
- Search: "colloidal crystal phonon modes"
- Search: "2D colloidal monolayer vibrations"
- Wang thesis (referenced in original README) - Brownian dynamics

### Dispersion Relations
- Search: "dispersion relation 2D hexagonal lattice"
- Search: "acoustic optical phonon modes"
- Search: "Brillouin zone triangular lattice"

### Domain Effects
- Search: "phonon scattering domain boundaries"
- Search: "grain boundary thermal resistance"
- Search: "polycrystalline phonon transport"

### Simulation Methods
- TDsim documentation (in Colloid Work Folder)
- BDsim documentation (Brownian dynamics)
- Search: "Brownian dynamics simulation colloids"

### MATLAB References
- FFT and signal processing: `doc fft`, `doc pwelch`
- Image processing: `doc imagesc`, `doc colormap`
- GUI programming: `doc uifigure`, `doc uiaxes`

---

## Technical Notes

### Data Formats

**plist.mat** - Raw simulation output
```
plist: [N_total × 4] matrix
  Column 1: x position
  Column 2: y position
  Column 3: z position
  Column 4: frame number
```

**xyz_data.mat** - Converted format
```
xyz: [N_particles × 3 × N_frames] array
  Dimension 1: particle index
  Dimension 2: coordinate (1=x, 2=y, 3=z)
  Dimension 3: time frame
```

### Physical Units
- Distance: pixels (1 particle = 10 px diameter)
- Time: frames (dt = 0.05 per simulation step, data saved every 2-10 steps)
- Frequency: oscillations per frame

### Common Issues

**Corrupt plist.mat**
- Caused by interrupted saves or network issues
- Solution: `run_master_analysis.m` step 2 regenerates from plist.mat

**Memory errors**
- Large simulations (~3000 particles × 10000 frames)
- Solution: Load partial frame ranges (0-20% option in viewer)

**Path issues**
- Windows uses `Z:\Colloid Cru\...`
- Linux uses `/home/sorin/AllSaves/...`
- Solution: Always use `get_paths()` function

### Git Workflow
```bash
# Before starting work
git pull origin main

# After making changes
git add phonon_analysis/*.m
git commit -m "Description of changes"
git push origin main
```

### Running on Network Drive
- Simulations are stored on lab network drive (Z:)
- Use robust save with retry for network glitches
- Check connection before starting overnight runs

---

## Contact & Lab Info

**Gerbode Lab**
Harvey Mudd College
Claremont, CA

Project started: 2026

---

*This README was generated to facilitate continuation of this research project. For questions about specific implementations, refer to the inline comments in each MATLAB file or examine the git commit history for context on specific changes.*
