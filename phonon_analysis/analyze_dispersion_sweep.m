%% analyze_dispersion_sweep.m
% Analyze multiple sinusoidal driving simulations to extract dispersion relation
%
% For each simulation at frequency f:
%   1. Generate kymograph (x-displacement vs position and time)
%   2. Measure wavelength λ from spatial pattern
%   3. Calculate k = 2π/λ and ω = 2πf
%   4. Plot dispersion relation ω(k)
%
% Author: Gerbode Lab
% Date: 2026

clear; close all; clc;

%% ==================== CONFIGURATION ====================

% Path to simulations
sim_base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\PhononSims';

% Frequencies that were run (should match run_dispersion_sweep.m)
frequencies = [0.002, 0.005, 0.01, 0.02, 0.03, 0.05];
drive_amplitude = 2.0;

% Physical parameters
particle_diameter = 10;  % pixels
looseness = 1.06;
lattice_constant = particle_diameter * looseness;

% Box size
box_size = [500, 300];

% Output
output_folder = 'dispersion_results';
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% ==================== ANALYZE EACH FREQUENCY ====================
fprintf('==============================================\n');
fprintf('   DISPERSION RELATION ANALYSIS\n');
fprintf('==============================================\n\n');

results = struct();
results.frequencies = [];
results.omega = [];
results.wavelengths = [];
results.k = [];
results.amplitudes = [];

for i = 1:length(frequencies)
    f = frequencies(i);
    sim_name = sprintf('sinusoidal_f%.4f_a%.1f', f, drive_amplitude);
    sim_path = fullfile(sim_base_path, sim_name);

    fprintf('Analyzing f = %.4f (%s)...\n', f, sim_name);

    % Check if simulation exists
    plist_file = fullfile(sim_path, 'plist.mat');
    if ~exist(plist_file, 'file')
        fprintf('  NOT FOUND - skipping\n');
        continue;
    end

    % Load data
    loaded = load(plist_file);
    plist = loaded.plist;

    % Convert to xyz
    xyz = plist2xyz_auto(plist, 1);  % Use all frames
    xyz = unwrap_periodic(xyz, box_size);

    [N_particles, ~, N_frames] = size(xyz);
    fprintf('  Loaded: %d particles, %d frames\n', N_particles, N_frames);

    % Extract x positions
    x = squeeze(xyz(:, 1, :));
    y_pos = squeeze(xyz(:, 2, 1));  % y positions (for binning)

    % Equilibrium from first few frames
    x0 = mean(x(:, 1:min(10, N_frames)), 2);

    % Displacement
    ux = x - x0;
    ux = ux - mean(ux, 1);  % Remove COM drift

    %% Create kymograph
    % Bin particles by x-position
    n_bins = 50;
    x_edges = linspace(0, box_size(1), n_bins+1);
    x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;

    kymograph = zeros(n_bins, N_frames);
    for t = 1:N_frames
        for b = 1:n_bins
            in_bin = x0 >= x_edges(b) & x0 < x_edges(b+1);
            if sum(in_bin) > 0
                kymograph(b, t) = mean(ux(in_bin, t));
            end
        end
    end

    %% Extract wavelength using spatial FFT
    % Use later frames when wave is established (skip transient)
    start_frame = min(200, floor(N_frames/4));
    kymograph_steady = kymograph(:, start_frame:end);

    % Spatial FFT at each time, then average
    n_fft = 2^nextpow2(n_bins);
    spatial_spectrum = zeros(n_fft, 1);
    for t = 1:size(kymograph_steady, 2)
        col = kymograph_steady(:, t);
        col = col - mean(col);
        spec = abs(fft(col, n_fft)).^2;
        spatial_spectrum = spatial_spectrum + spec;
    end
    spatial_spectrum = spatial_spectrum / size(kymograph_steady, 2);

    % Frequency axis (spatial frequency)
    dx = box_size(1) / n_bins;
    k_spatial = (0:n_fft-1) / (n_fft * dx) * 2 * pi;  % Convert to k = 2π/λ

    % Find dominant spatial frequency (excluding DC)
    half = floor(n_fft/2);
    [~, peak_idx] = max(spatial_spectrum(2:half));
    peak_idx = peak_idx + 1;  % Adjust for skipping DC

    k_measured = k_spatial(peak_idx);
    wavelength = 2*pi / k_measured;

    %% Measure amplitude decay
    % Compare amplitude near drive vs far from drive
    near_drive = x0 < 50;
    far_from_drive = x0 > 250 & x0 < 350;

    amp_near = std(ux(near_drive, start_frame:end), [], 'all');
    amp_far = std(ux(far_from_drive, start_frame:end), [], 'all');

    fprintf('  Wavelength: %.1f pixels (%.1f lattice constants)\n', wavelength, wavelength/lattice_constant);
    fprintf('  Amplitude near drive: %.2f px, far: %.2f px\n', amp_near, amp_far);

    %% Store results
    results.frequencies(end+1) = f;
    results.omega(end+1) = 2 * pi * f;  % Angular frequency
    results.wavelengths(end+1) = wavelength;
    results.k(end+1) = k_measured;
    results.amplitudes(end+1) = amp_far;

    %% Save individual kymograph
    figure('Position', [100, 100, 1200, 400]);

    subplot(1, 3, 1);
    imagesc(1:N_frames, x_centers, kymograph);
    colorbar;
    xlabel('Frame');
    ylabel('X position (pixels)');
    title(sprintf('Kymograph: f = %.4f', f));
    set(gca, 'YDir', 'normal');

    subplot(1, 3, 2);
    plot(k_spatial(1:half), spatial_spectrum(1:half), 'b-', 'LineWidth', 1.5);
    hold on;
    xline(k_measured, 'r--', 'LineWidth', 2);
    xlabel('k (rad/pixel)');
    ylabel('Power');
    title(sprintf('Spatial spectrum (λ = %.1f px)', wavelength));
    xlim([0, 0.5]);
    grid on;

    subplot(1, 3, 3);
    t_plot = 1:min(500, N_frames);
    plot(t_plot, mean(ux(near_drive, t_plot), 1), 'b-', 'LineWidth', 1, 'DisplayName', 'Near drive');
    hold on;
    plot(t_plot, mean(ux(far_from_drive, t_plot), 1), 'r-', 'LineWidth', 1, 'DisplayName', 'Far from drive');
    xlabel('Frame');
    ylabel('Mean X displacement');
    title('Wave propagation');
    legend('Location', 'best');
    grid on;

    saveas(gcf, fullfile(output_folder, sprintf('kymograph_f%.4f.png', f)));
    close(gcf);
end

%% ==================== PLOT DISPERSION RELATION ====================
fprintf('\n==============================================\n');
fprintf('   DISPERSION RELATION RESULTS\n');
fprintf('==============================================\n');

if length(results.k) >= 2
    figure('Position', [100, 100, 800, 600]);

    % Plot measured points
    subplot(2, 2, 1);
    plot(results.k, results.omega, 'ro', 'MarkerSize', 10, 'LineWidth', 2, 'MarkerFaceColor', 'r');
    xlabel('k (rad/pixel)');
    ylabel('ω (rad/frame)');
    title('Dispersion Relation ω(k)');
    grid on;

    % Fit linear dispersion (acoustic branch): ω = c*k
    % where c is the wave speed
    if length(results.k) >= 2
        p = polyfit(results.k, results.omega, 1);
        c_sound = p(1);  % Wave speed in pixels/frame
        k_fit = linspace(0, max(results.k)*1.2, 100);
        hold on;
        plot(k_fit, p(1)*k_fit + p(2), 'b--', 'LineWidth', 1.5);
        legend('Measured', sprintf('Linear fit (c = %.2f px/frame)', c_sound), 'Location', 'best');
    end

    % Plot wavelength vs frequency
    subplot(2, 2, 2);
    plot(results.frequencies, results.wavelengths, 'bs', 'MarkerSize', 10, 'LineWidth', 2, 'MarkerFaceColor', 'b');
    xlabel('Drive frequency (1/frame)');
    ylabel('Wavelength (pixels)');
    title('Wavelength vs Frequency');
    grid on;

    % Plot amplitude vs frequency (attenuation)
    subplot(2, 2, 3);
    plot(results.frequencies, results.amplitudes, 'g^', 'MarkerSize', 10, 'LineWidth', 2, 'MarkerFaceColor', 'g');
    xlabel('Drive frequency (1/frame)');
    ylabel('Amplitude far from drive (pixels)');
    title('Wave Penetration vs Frequency');
    grid on;

    % Summary table
    subplot(2, 2, 4);
    axis off;
    text(0.1, 0.9, 'DISPERSION RESULTS', 'FontSize', 14, 'FontWeight', 'bold');
    text(0.1, 0.75, sprintf('Number of frequencies: %d', length(results.k)), 'FontSize', 11);
    if exist('c_sound', 'var')
        text(0.1, 0.6, sprintf('Sound speed: %.3f pixels/frame', c_sound), 'FontSize', 11);
        text(0.1, 0.45, sprintf('           = %.2f lattice constants/frame', c_sound/lattice_constant), 'FontSize', 11);
    end
    text(0.1, 0.3, sprintf('Wavelength range: %.1f - %.1f pixels', min(results.wavelengths), max(results.wavelengths)), 'FontSize', 11);

    saveas(gcf, fullfile(output_folder, 'dispersion_relation.png'));
    saveas(gcf, fullfile(output_folder, 'dispersion_relation.fig'));

    fprintf('\nSound speed: %.4f pixels/frame\n', c_sound);
    fprintf('           = %.2f lattice constants/frame\n', c_sound/lattice_constant);
else
    fprintf('\nNeed at least 2 frequencies to plot dispersion relation.\n');
    fprintf('Run more simulations with run_dispersion_sweep.m\n');
end

% Save results
save(fullfile(output_folder, 'dispersion_results.mat'), 'results');
fprintf('\nResults saved to: %s\n', output_folder);

%% Print table
fprintf('\n--- Data Table ---\n');
fprintf('f (1/frame)\tω (rad/frame)\tλ (pixels)\tk (rad/px)\tAmplitude\n');
for i = 1:length(results.frequencies)
    fprintf('%.4f\t\t%.4f\t\t%.1f\t\t%.4f\t\t%.3f\n', ...
        results.frequencies(i), results.omega(i), results.wavelengths(i), ...
        results.k(i), results.amplitudes(i));
end
