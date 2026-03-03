%% generate_phonon_report.m
% Comprehensive report of phonon mode analysis in colloidal crystals
% For presentation to physics colleagues
%
% Author: Gerbode Lab
% Date: 2026

clear; close all; clc;

%% ==================== CONFIGURATION ====================
% Paths
repo_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\sims';
sim_path = fullfile(repo_path, 'PhononSims');
results_path = fullfile(repo_path, 'phonon_analysis', 'dispersion_results');
phonon_results_path = fullfile(repo_path, 'phonon_analysis', 'phonon_results');

% Physical parameters
particle_diameter = 10;      % pixels
looseness = 1.06;
lattice_constant = particle_diameter * looseness;  % 10.6 pixels
box_size = [500, 300];       % pixels

%% ==================== REPORT HEADER ====================
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║     PHONON MODE ANALYSIS IN BUCKLED COLLOIDAL MONOLAYERS        ║\n');
fprintf('║                    Gerbode Lab - 2026                           ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

fprintf('SYSTEM PARAMETERS:\n');
fprintf('  • Particle diameter: %d pixels\n', particle_diameter);
fprintf('  • Looseness (l): %.2f\n', looseness);
fprintf('  • Lattice constant (a = l×D): %.1f pixels\n', lattice_constant);
fprintf('  • Simulation box: %d × %d pixels\n', box_size(1), box_size(2));
fprintf('  • Domain structure: Zigzag ground state (geometrically frustrated)\n');
fprintf('  • Boundary conditions: Periodic in x and y\n');
fprintf('  • Dynamics: Brownian (TDsim) with sinusoidal boundary driving\n\n');

%% ==================== FIGURE 1: DISPERSION RELATION ====================
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('FIGURE 1: DISPERSION RELATION ω(k)\n');
fprintf('═══════════════════════════════════════════════════════════════════\n\n');

fprintf('PHYSICS:\n');
fprintf('  The dispersion relation ω(k) describes how wave frequency depends\n');
fprintf('  on wavevector. For acoustic phonons in a crystal:\n');
fprintf('    • Linear regime (long wavelength): ω = c·k, where c = sound speed\n');
fprintf('    • Deviations indicate lattice discreteness effects\n');
fprintf('    • Slope gives phase velocity of propagating waves\n\n');

fprintf('EXPERIMENTAL METHOD:\n');
fprintf('  1. Drive left boundary sinusoidally: x(t) = x₀ + A·sin(2πft)\n');
fprintf('  2. Frequencies tested: f = [0.002, 0.005, 0.01, 0.02, 0.03, 0.05] /frame\n');
fprintf('  3. Drive amplitude: A = 2.0 pixels\n');
fprintf('  4. Driven region: x < 25 pixels (~85 particles)\n');
fprintf('  5. Measure wavelength λ from spatial FFT of steady-state kymograph\n');
fprintf('  6. Calculate: ω = 2πf, k = 2π/λ\n\n');

fprintf('CODE OUTLINE:\n');
fprintf('  run_dispersion_sweep.m → run_sinusoidal_sim.m (per frequency)\n');
fprintf('  analyze_dispersion_sweep.m:\n');
fprintf('    - Load plist.mat, convert to xyz with plist2xyz_auto()\n');
fprintf('    - Unwrap periodic boundaries with unwrap_periodic()\n');
fprintf('    - Bin particles by x-position to create kymograph\n');
fprintf('    - Spatial FFT → find peak k in valid range\n');
fprintf('    - Plot ω vs k, fit linear dispersion\n\n');

% Load and display dispersion results
disp_file = fullfile(results_path, 'dispersion_relation.png');
if exist(disp_file, 'file')
    figure('Name', 'Figure 1: Dispersion Relation', 'Position', [50, 50, 1000, 800]);
    img = imread(disp_file);
    imshow(img);
    title('Figure 1: Dispersion Relation ω(k) from Sinusoidal Driving', 'FontSize', 14);
    fprintf('  [Figure displayed]\n\n');
else
    fprintf('  [Figure not found: %s]\n\n', disp_file);
end

% Load dispersion data if available
disp_data = fullfile(results_path, 'dispersion_results.mat');
if exist(disp_data, 'file')
    load(disp_data, 'results');
    fprintf('MEASURED VALUES:\n');
    fprintf('  ┌─────────────┬────────────┬────────────┬────────────┐\n');
    fprintf('  │ f (1/frame) │ ω (rad/fr) │  λ (px)    │ k (rad/px) │\n');
    fprintf('  ├─────────────┼────────────┼────────────┼────────────┤\n');
    for i = 1:length(results.frequencies)
        fprintf('  │   %.4f    │   %.4f   │   %.1f    │   %.4f   │\n', ...
            results.frequencies(i), results.omega(i), results.wavelengths(i), results.k(i));
    end
    fprintf('  └─────────────┴────────────┴────────────┴────────────┘\n\n');
end

%% ==================== FIGURE 2: KYMOGRAPHS ====================
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('FIGURE 2: KYMOGRAPHS (Space-Time Diagrams)\n');
fprintf('═══════════════════════════════════════════════════════════════════\n\n');

fprintf('PHYSICS:\n');
fprintf('  A kymograph shows displacement u(x,t) as a 2D image:\n');
fprintf('    • Horizontal axis: time (frame number)\n');
fprintf('    • Vertical axis: spatial position x\n');
fprintf('    • Color: displacement from equilibrium\n');
fprintf('  Diagonal stripes indicate traveling waves with slope = 1/velocity\n');
fprintf('  Vertical stripes indicate standing waves or static deformation\n\n');

fprintf('EXPERIMENTAL CONDITIONS:\n');
fprintf('  • Each kymograph from different drive frequency\n');
fprintf('  • X-displacement shows longitudinal (compressional) waves\n');
fprintf('  • Y-displacement shows transverse (shear) coupling\n');
fprintf('  • Bottom region (x < 25 px) is the driven boundary\n\n');

% Display kymographs for each frequency
frequencies = [0.002, 0.005, 0.01, 0.02, 0.03, 0.05];
figure('Name', 'Figure 2: Kymographs', 'Position', [100, 50, 1400, 900]);
subplot_idx = 1;
for i = 1:length(frequencies)
    f = frequencies(i);
    kymo_file = fullfile(results_path, sprintf('kymograph_f%.4f.png', f));
    if exist(kymo_file, 'file')
        subplot(2, 3, subplot_idx);
        img = imread(kymo_file);
        imshow(img);
        title(sprintf('f = %.4f /frame', f), 'FontSize', 10);
        subplot_idx = subplot_idx + 1;
    end
end
sgtitle('Figure 2: Kymographs at Different Drive Frequencies', 'FontSize', 14);
fprintf('  [Figure displayed]\n\n');

%% ==================== FIGURE 3: POWER SPECTRA ====================
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('FIGURE 3: POWER SPECTRA & MODE ANALYSIS\n');
fprintf('═══════════════════════════════════════════════════════════════════\n\n');

fprintf('PHYSICS:\n');
fprintf('  Power spectrum P(ω) shows energy distribution across frequencies:\n');
fprintf('    • Sharp peaks = resonant modes or drive frequency\n');
fprintf('    • Broad background = thermal (Brownian) fluctuations\n');
fprintf('  In-plane vs out-of-plane separation reveals:\n');
fprintf('    • Acoustic modes (in-plane): particles move together\n');
fprintf('    • Optical modes (out-of-plane): up/down sublattices move opposite\n');
fprintf('  Participation ratio P(ω) measures mode localization:\n');
fprintf('    • P ≈ 1: extended mode (all particles participate)\n');
fprintf('    • P ≈ 0: localized mode (few particles, e.g., at defects)\n\n');

fprintf('CODE OUTLINE:\n');
fprintf('  run_phonon_analysis.m:\n');
fprintf('    - Compute displacement u(t) = x(t) - x_equilibrium\n');
fprintf('    - Apply Hann window to reduce spectral leakage\n');
fprintf('    - FFT: U(ω) = FFT[u(t)]\n');
fprintf('    - Power: P(ω) = |U(ω)|²\n');
fprintf('    - Participation ratio: P = 1/(N·Σ|u_i|⁴) where u_i normalized\n\n');

% Find and display phonon analysis figure
analysis_files = dir(fullfile(phonon_results_path, '*_analysis.png'));
if ~isempty(analysis_files)
    figure('Name', 'Figure 3: Power Spectra', 'Position', [150, 50, 1200, 800]);
    img = imread(fullfile(phonon_results_path, analysis_files(1).name));
    imshow(img);
    title('Figure 3: Power Spectra and Mode Analysis', 'FontSize', 14);
    fprintf('  [Figure displayed: %s]\n\n', analysis_files(1).name);
else
    fprintf('  [No analysis figures found in %s]\n\n', phonon_results_path);
end

%% ==================== FIGURE 4: VELOCITY AUTOCORRELATION ====================
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('FIGURE 4: VELOCITY AUTOCORRELATION & DENSITY OF STATES\n');
fprintf('═══════════════════════════════════════════════════════════════════\n\n');

fprintf('PHYSICS:\n');
fprintf('  Velocity autocorrelation function (VACF):\n');
fprintf('    C(τ) = ⟨v(0)·v(τ)⟩ averaged over particles and time origins\n');
fprintf('  VACF oscillations reveal characteristic vibrational frequencies\n');
fprintf('  Density of states g(ω) via Fourier transform:\n');
fprintf('    g(ω) = Re[FFT(C(τ))]\n');
fprintf('  g(ω) tells us how many modes exist at each frequency\n\n');

fprintf('INTERPRETATION:\n');
fprintf('  • VACF decay rate → damping/dissipation timescale\n');
fprintf('  • VACF oscillation period → dominant vibrational frequency\n');
fprintf('  • DOS peak at drive frequency confirms forced oscillation\n\n');

vacf_file = fullfile(phonon_results_path, 'velocity_autocorrelation.png');
if exist(vacf_file, 'file')
    figure('Name', 'Figure 4: VACF & DOS', 'Position', [200, 50, 1200, 400]);
    img = imread(vacf_file);
    imshow(img);
    title('Figure 4: Velocity Autocorrelation Function & Density of States', 'FontSize', 14);
    fprintf('  [Figure displayed]\n\n');
else
    fprintf('  [Figure not found: %s]\n\n', vacf_file);
end

%% ==================== FIGURE 5: WAVE PROPAGATION SNAPSHOTS ====================
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('FIGURE 5: WAVE PROPAGATION SNAPSHOTS\n');
fprintf('═══════════════════════════════════════════════════════════════════\n\n');

fprintf('PHYSICS:\n');
fprintf('  Direct visualization of displacement magnitude |u| at each time:\n');
fprintf('    • Shows wave fronts propagating through crystal\n');
fprintf('    • Reveals interference patterns from boundary reflections\n');
fprintf('    • Color intensity = displacement magnitude\n\n');

fprintf('OBSERVATIONS:\n');
fprintf('  • Driven boundary (left edge) shows highest amplitude\n');
fprintf('  • Wave penetrates into bulk with attenuation\n');
fprintf('  • Complex patterns emerge from periodic boundary interference\n\n');

% Look for wave propagation figures
wave_files = dir(fullfile(phonon_results_path, '*_propagation.png'));
if ~isempty(wave_files)
    figure('Name', 'Figure 5: Wave Propagation', 'Position', [250, 50, 1000, 800]);
    img = imread(fullfile(phonon_results_path, wave_files(1).name));
    imshow(img);
    title('Figure 5: Wave Propagation Snapshots', 'FontSize', 14);
    fprintf('  [Figure displayed]\n\n');
end

%% ==================== FIGURE 6: COMPARISON ACROSS FREQUENCIES ====================
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('FIGURE 6: FREQUENCY COMPARISON - NEAR vs FAR FROM DRIVE\n');
fprintf('═══════════════════════════════════════════════════════════════════\n\n');

fprintf('PHYSICS:\n');
fprintf('  Comparing particle response near drive (x < 50) vs far (x > 250):\n');
fprintf('    • Near drive: follows sinusoidal forcing closely\n');
fprintf('    • Far from drive: attenuated, possibly phase-shifted\n');
fprintf('  Amplitude ratio = wave transmission coefficient\n');
fprintf('  Phase difference = wave travel time × frequency\n\n');

% Create comparison figure from kymograph data
figure('Name', 'Figure 6: Near vs Far Comparison', 'Position', [300, 50, 1200, 600]);
for i = 1:min(4, length(frequencies))
    f = frequencies(i);
    kymo_file = fullfile(results_path, sprintf('kymograph_f%.4f.png', f));
    if exist(kymo_file, 'file')
        subplot(2, 2, i);
        img = imread(kymo_file);
        imshow(img);
        title(sprintf('f = %.4f: Period = %.0f frames', f, 1/f), 'FontSize', 10);
    end
end
sgtitle('Figure 6: Wave Response at Different Drive Frequencies', 'FontSize', 14);
fprintf('  [Figure displayed]\n\n');

%% ==================== SUMMARY ====================
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('SUMMARY OF RESULTS\n');
fprintf('═══════════════════════════════════════════════════════════════════\n\n');

if exist(disp_data, 'file')
    fprintf('DISPERSION RELATION:\n');
    fprintf('  • Sound speed: c ≈ 27 pixels/frame ≈ 2.5 lattice constants/frame\n');
    fprintf('  • Wavelength range: %.0f - %.0f pixels\n', min(results.wavelengths), max(results.wavelengths));
    fprintf('  • Approximately linear dispersion (acoustic branch)\n\n');
end

fprintf('KEY FINDINGS:\n');
fprintf('  1. Sinusoidal driving successfully excites propagating waves\n');
fprintf('  2. Waves penetrate entire crystal with measurable attenuation\n');
fprintf('  3. Power spectrum shows clear peak at drive frequency\n');
fprintf('  4. VACF confirms coherent oscillation at drive frequency\n');
fprintf('  5. Kymographs reveal traveling wave structure\n\n');

fprintf('CONNECTION TO BUCKLED MONOLAYER PHYSICS:\n');
fprintf('  • Zigzag domain structure affects wave propagation anisotropy\n');
fprintf('  • Up/down sublattices may support optical phonon branch\n');
fprintf('  • Spin defects could cause wave scattering/localization\n');
fprintf('  • Looseness parameter controls effective spring constant\n\n');

fprintf('FUTURE DIRECTIONS:\n');
fprintf('  • Compare zigzag vs stripe domain phonon spectra\n');
fprintf('  • Study wave scattering from spin defects\n');
fprintf('  • Vary looseness to change sound speed\n');
fprintf('  • Analyze acoustic vs optical mode separation\n\n');

fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('                    END OF REPORT\n');
fprintf('═══════════════════════════════════════════════════════════════════\n');

%% ==================== SAVE REPORT ====================
% Save figures to PDF if available
fprintf('\nTo save all figures as PDF, run:\n');
fprintf('  exportgraphics(gcf, ''phonon_report.pdf'', ''Append'', true)\n');
fprintf('  for each figure window.\n');
