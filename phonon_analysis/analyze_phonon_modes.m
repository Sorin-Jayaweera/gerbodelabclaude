%% analyze_phonon_modes.m
% Comprehensive phonon mode analysis for colloidal crystal simulations
% Analyzes impulse response to extract vibrational modes, dispersion relations,
% and energy distribution
%
% Author: Gerbode Lab
% Date: 2026

%% ========== CONFIGURATION ==========
% Modify these parameters for your specific simulation

% File paths - update these to your simulation outputs
sim_name = 'onaxisphonon3impulse_.5';
plist_file = [sim_name '/plist.mat'];  % Adjust path as needed

% Physical parameters
particle_diameter = 10;  % pixels
looseness = 1.06;
lattice_constant = particle_diameter * looseness;  % approximate lattice spacing

% Time parameters
data_saving_frequency = 100;  % simulation steps between saved frames
dt_sim = 0.05;  % simulation time step (from TDsim default step_size)
dt = dt_sim * data_saving_frequency;  % time between saved frames

% Analysis parameters
use_windowing = true;  % Apply Hanning window before FFT
remove_drift = true;   % Remove any net drift from particle motion

%% ========== LOAD AND PREPARE DATA ==========
fprintf('Loading simulation data...\n');

% Load plist and convert to xyz format
load(plist_file, 'plist');
xyz = plist2xyz(plist);  % Expected shape: [N_particles, 3, N_frames]

[N_particles, N_dims, N_frames] = size(xyz);
fprintf('Loaded %d particles, %d dimensions, %d frames\n', N_particles, N_dims, N_frames);

% Extract position time series
x = squeeze(xyz(:, 1, :));  % [N_particles, N_frames]
y = squeeze(xyz(:, 2, :));  % [N_particles, N_frames]
if N_dims >= 3
    z = squeeze(xyz(:, 3, :));  % For buckled monolayers
else
    z = zeros(size(x));
end

%% ========== COMPUTE EQUILIBRIUM AND DISPLACEMENTS ==========
fprintf('Computing equilibrium positions and displacements...\n');

% Use first few frames before impulse propagates as equilibrium
% Or use time-averaged positions
n_equil_frames = min(10, N_frames);
x0 = mean(x(:, 1:n_equil_frames), 2);
y0 = mean(y(:, 1:n_equil_frames), 2);
z0 = mean(z(:, 1:n_equil_frames), 2);

% Compute displacements from equilibrium
ux = x - x0;  % [N_particles, N_frames]
uy = y - y0;
uz = z - z0;

% Remove any net drift if requested
if remove_drift
    ux = ux - mean(ux, 1);
    uy = uy - mean(uy, 1);
    uz = uz - mean(uz, 1);
end

%% ========== TEMPORAL FOURIER ANALYSIS ==========
fprintf('Performing temporal Fourier analysis...\n');

% Time and frequency arrays
t = (0:N_frames-1) * dt;
fs = 1/dt;  % Sampling frequency
f = (0:N_frames-1) * fs / N_frames;  % Frequency array
f_nyquist = fs/2;

% Apply windowing if requested
if use_windowing
    window = hann_window(N_frames)';
    ux_windowed = ux .* window;
    uy_windowed = uy .* window;
    uz_windowed = uz .* window;
else
    ux_windowed = ux;
    uy_windowed = uy;
    uz_windowed = uz;
end

% FFT of displacements for each particle
Ux = fft(ux_windowed, [], 2);  % FFT along time dimension
Uy = fft(uy_windowed, [], 2);
Uz = fft(uz_windowed, [], 2);

% Power spectral density for each particle
Px = abs(Ux).^2 / N_frames;
Py = abs(Uy).^2 / N_frames;
Pz = abs(Uz).^2 / N_frames;

% Total power spectrum (sum over all particles)
P_total_x = sum(Px, 1);
P_total_y = sum(Py, 1);
P_total_z = sum(Pz, 1);
P_total = P_total_x + P_total_y + P_total_z;

% Only keep positive frequencies
n_pos_freq = floor(N_frames/2) + 1;
f_pos = f(1:n_pos_freq);
P_total_pos = P_total(1:n_pos_freq);

%% ========== SPATIAL FOURIER ANALYSIS (DISPERSION RELATION) ==========
fprintf('Computing dispersion relation...\n');

% For dispersion relation, we need to compute spatial FFT
% First, we need to set up reciprocal lattice vectors for triangular lattice

% Real-space lattice vectors for triangular lattice
a1 = lattice_constant * [1, 0];
a2 = lattice_constant * [0.5, sqrt(3)/2];

% Reciprocal lattice vectors
% b1 = 2*pi * (a2_perp) / (a1 . a2_perp)
area = a1(1)*a2(2) - a1(2)*a2(1);  % Cross product in 2D
b1 = 2*pi * [a2(2), -a2(1)] / area;
b2 = 2*pi * [-a1(2), a1(1)] / area;

% Create k-space grid
n_k = 50;  % Number of k-points along each direction
k_max = norm(b1);  % Maximum k value

% For 1D impulse response, compute dispersion along impulse direction
% Assuming impulse was along x-axis
k_parallel = linspace(0, k_max, n_k);

% Compute spatial FFT at each frequency
% S(k, omega) = |sum_j u_j(omega) * exp(-i*k*r_j)|^2
dispersion = zeros(n_k, n_pos_freq);

for ik = 1:n_k
    k = k_parallel(ik);
    % Phase factor for each particle
    phase = exp(-1i * k * x0);  % k along x-direction

    for iw = 1:n_pos_freq
        % Sum over particles with phase weighting
        Sk_x = sum(Ux(:, iw) .* phase);
        Sk_y = sum(Uy(:, iw) .* phase);
        dispersion(ik, iw) = abs(Sk_x)^2 + abs(Sk_y)^2;
    end
end

%% ========== MODE IDENTIFICATION ==========
fprintf('Identifying dominant modes...\n');

% Find peaks in total power spectrum
[pks, locs] = findpeaks(P_total_pos, 'MinPeakProminence', max(P_total_pos)*0.01);

% Sort by peak height
[pks_sorted, sort_idx] = sort(pks, 'descend');
locs_sorted = locs(sort_idx);

% Report top modes
n_modes_to_report = min(10, length(pks));
fprintf('\nTop %d frequency peaks:\n', n_modes_to_report);
fprintf('Rank\tFrequency\tPower\n');
for i = 1:n_modes_to_report
    fprintf('%d\t%.4f\t\t%.2e\n', i, f_pos(locs_sorted(i)), pks_sorted(i));
end

%% ========== COMPUTE PARTICIPATION RATIO ==========
% Participation ratio tells us how localized vs delocalized each mode is
% PR = 1 means all particles participate equally, PR = 1/N means one particle

fprintf('Computing participation ratios...\n');

participation_ratio = zeros(1, n_pos_freq);
for iw = 1:n_pos_freq
    % Mode amplitude for each particle at this frequency
    amp = abs(Ux(:, iw)).^2 + abs(Uy(:, iw)).^2 + abs(Uz(:, iw)).^2;
    amp = amp / sum(amp);  % Normalize

    % Participation ratio
    if sum(amp) > 0
        participation_ratio(iw) = 1 / (N_particles * sum(amp.^2));
    end
end

%% ========== VISUALIZATION ==========
fprintf('Creating visualizations...\n');

% Figure 1: Power Spectrum
figure('Position', [100, 100, 1200, 800]);

subplot(2,2,1);
semilogy(f_pos, P_total_pos, 'b-', 'LineWidth', 1.5);
hold on;
semilogy(f_pos(locs_sorted(1:n_modes_to_report)), pks_sorted(1:n_modes_to_report), 'ro', 'MarkerSize', 8);
xlabel('Frequency (1/sim time)');
ylabel('Power Spectral Density');
title('Total Power Spectrum');
xlim([0, f_nyquist]);
grid on;

subplot(2,2,2);
plot(f_pos, participation_ratio, 'g-', 'LineWidth', 1.5);
xlabel('Frequency (1/sim time)');
ylabel('Participation Ratio');
title('Mode Localization (1 = delocalized, 0 = localized)');
xlim([0, f_nyquist]);
ylim([0, 1]);
grid on;

subplot(2,2,3);
imagesc(f_pos, k_parallel, log10(dispersion + 1));
xlabel('Frequency (1/sim time)');
ylabel('Wavevector k (1/pixels)');
title('Dispersion Relation S(k, \omega)');
colorbar;
axis xy;

subplot(2,2,4);
% Plot component-resolved power spectra
semilogy(f_pos, P_total_x(1:n_pos_freq), 'r-', 'LineWidth', 1.5);
hold on;
semilogy(f_pos, P_total_y(1:n_pos_freq), 'b-', 'LineWidth', 1.5);
if any(uz(:) ~= 0)
    semilogy(f_pos, P_total_z(1:n_pos_freq), 'g-', 'LineWidth', 1.5);
    legend('x (longitudinal)', 'y (transverse)', 'z (out-of-plane)');
else
    legend('x (longitudinal)', 'y (transverse)');
end
xlabel('Frequency (1/sim time)');
ylabel('Power Spectral Density');
title('Component-Resolved Power Spectra');
xlim([0, f_nyquist]);
grid on;

saveas(gcf, [sim_name '_phonon_analysis.png']);
saveas(gcf, [sim_name '_phonon_analysis.fig']);

% Figure 2: Mode visualization for top modes
figure('Position', [100, 100, 1400, 400]);
n_modes_to_plot = min(4, n_modes_to_report);

for i = 1:n_modes_to_plot
    subplot(1, n_modes_to_plot, i);

    freq_idx = locs_sorted(i);
    mode_freq = f_pos(freq_idx);

    % Get mode shape (complex amplitude at this frequency)
    mode_x = Ux(:, freq_idx);
    mode_y = Uy(:, freq_idx);

    % Plot equilibrium positions
    scatter(x0, y0, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;

    % Plot mode displacement (real part, scaled for visibility)
    scale = 20;  % Adjust for visibility
    quiver(x0, y0, scale*real(mode_x), scale*real(mode_y), 0, 'r', 'LineWidth', 1);

    axis equal;
    title(sprintf('Mode %d: f = %.4f', i, mode_freq));
    xlabel('x (pixels)');
    ylabel('y (pixels)');
end

saveas(gcf, [sim_name '_mode_shapes.png']);
saveas(gcf, [sim_name '_mode_shapes.fig']);

%% ========== SAVE RESULTS ==========
fprintf('Saving results...\n');

results = struct();
results.f = f_pos;
results.P_total = P_total_pos;
results.P_x = P_total_x(1:n_pos_freq);
results.P_y = P_total_y(1:n_pos_freq);
results.P_z = P_total_z(1:n_pos_freq);
results.participation_ratio = participation_ratio;
results.dispersion = dispersion;
results.k_parallel = k_parallel;
results.peak_frequencies = f_pos(locs_sorted);
results.peak_powers = pks_sorted;
results.x0 = x0;
results.y0 = y0;
results.Ux = Ux(:, 1:n_pos_freq);
results.Uy = Uy(:, 1:n_pos_freq);
results.lattice_constant = lattice_constant;
results.dt = dt;
results.N_particles = N_particles;
results.N_frames = N_frames;

save([sim_name '_phonon_results.mat'], 'results');

fprintf('Analysis complete!\n');
fprintf('Results saved to %s_phonon_results.mat\n', sim_name);
