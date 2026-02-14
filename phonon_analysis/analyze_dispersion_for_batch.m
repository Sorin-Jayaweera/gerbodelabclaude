function results = analyze_dispersion_for_batch(batch_folder, domain_type)
%% ANALYZE_DISPERSION_FOR_BATCH Analyze dispersion relation for any batch folder
%
% INPUTS:
%   batch_folder - Path to the batch simulation folder
%   domain_type  - String identifier ('zigzag', 'stripe', 'random', 'topdriven')
%
% OUTPUTS:
%   results      - Structure with dispersion analysis results
%
% Author: Gerbode Lab
% Date: 2026

fprintf('============================================\n');
fprintf('  DISPERSION ANALYSIS: %s\n', upper(domain_type));
fprintf('============================================\n');

%% Setup paths
simulations_folder = fullfile(batch_folder, 'simulations');
if ~exist(simulations_folder, 'dir')
    simulations_folder = batch_folder;  % Flat structure
end

output_folder = fullfile(batch_folder, 'analysis');
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% Find completed simulations
% Handle different naming conventions
if strcmp(domain_type, 'topdriven')
    sim_pattern = 'topdriven_f*_a*.0';
else
    sim_pattern = 'sinusoidal_f*_a*';
end

sim_dirs = dir(fullfile(simulations_folder, sim_pattern));
frequencies = [];
sim_paths = {};

for i = 1:length(sim_dirs)
    folder_name = sim_dirs(i).name;
    % Extract frequency
    if strcmp(domain_type, 'topdriven')
        tokens = regexp(folder_name, 'topdriven_f([\d.]+)_a', 'tokens');
    else
        tokens = regexp(folder_name, 'sinusoidal_f([\d.]+)_a', 'tokens');
    end

    if ~isempty(tokens)
        f = str2double(tokens{1}{1});
        plist_file = fullfile(simulations_folder, folder_name, 'plist.mat');
        if exist(plist_file, 'file')
            frequencies(end+1) = f;
            sim_paths{end+1} = fullfile(simulations_folder, folder_name);
        end
    end
end

[frequencies, sort_idx] = sort(frequencies);
sim_paths = sim_paths(sort_idx);

fprintf('Found %d completed simulations\n', length(frequencies));

if isempty(frequencies)
    warning('No simulations found for %s', domain_type);
    results = struct();
    return;
end

%% Initialize results
results = struct();
results.domain_type = domain_type;
results.frequencies = frequencies(:)';
results.omega = 2 * pi * frequencies(:)';
results.wavelengths = nan(size(frequencies));
results.k = nan(size(frequencies));
results.amplitudes = nan(size(frequencies));
results.phase_velocity = nan(size(frequencies));
results.decay_length = nan(size(frequencies));

%% Process each simulation
for i = 1:length(frequencies)
    f = frequencies(i);
    sim_path = sim_paths{i};

    fprintf('  Processing f=%.4f (%d/%d)...\n', f, i, length(frequencies));

    try
        % Load data
        loaded = load(fullfile(sim_path, 'plist.mat'));
        plist = loaded.plist;

        % Load parameters
        params_file = fullfile(sim_path, 'sim_params.mat');
        if exist(params_file, 'file')
            params = load(params_file);
            sim_params = params.sim_params;
        else
            sim_params = struct('width', 800, 'height', 400, ...
                'drive_amplitude', 2.0, 'data_saving_frequency', 10);
        end

        % Convert to xyz
        frames = unique(plist(:, 4));
        n_frames = length(frames);
        n_particles = sum(plist(:, 4) == frames(1));

        xyz = zeros(n_particles, 3, n_frames);
        for ff = 1:n_frames
            frame_mask = plist(:, 4) == frames(ff);
            xyz(:, :, ff) = plist(frame_mask, 1:3);
        end

        % Analyze this simulation
        sim_result = analyze_single_dispersion(xyz, f, sim_params, domain_type);

        % Store results
        results.wavelengths(i) = sim_result.wavelength;
        results.k(i) = sim_result.k;
        results.amplitudes(i) = sim_result.amplitude;
        results.phase_velocity(i) = sim_result.phase_velocity;
        results.decay_length(i) = sim_result.decay_length;

    catch ME
        fprintf('    ERROR: %s\n', ME.message);
    end
end

%% Save results
results_file = fullfile(output_folder, sprintf('dispersion_results_%s.mat', domain_type));
save(results_file, 'results');
fprintf('Results saved to: %s\n', results_file);

%% Generate plots
fig = figure('Position', [100 100 1200 800], 'Visible', 'off');

% Plot 1: Dispersion relation ω(k)
subplot(2, 2, 1);
valid = ~isnan(results.k);
plot(results.k(valid), results.omega(valid), 'o-', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Wavevector k (1/px)');
ylabel('Angular frequency ω (rad/frame)');
title(sprintf('Dispersion Relation - %s', upper(domain_type)));
grid on;

% Plot 2: Wavelength vs frequency
subplot(2, 2, 2);
plot(results.frequencies(valid), results.wavelengths(valid), 's-', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Drive frequency f');
ylabel('Wavelength λ (px)');
title('Wavelength vs Frequency');
grid on;

% Plot 3: Phase velocity vs frequency
subplot(2, 2, 3);
plot(results.frequencies(valid), results.phase_velocity(valid), 'd-', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Drive frequency f');
ylabel('Phase velocity v_p (px/frame)');
title('Phase Velocity');
grid on;

% Plot 4: Amplitude decay
subplot(2, 2, 4);
plot(results.frequencies(valid), results.amplitudes(valid), '^-', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Drive frequency f');
ylabel('Response amplitude (px)');
title('Amplitude at Measurement Point');
grid on;

sgtitle(sprintf('Dispersion Analysis: %s Domain', upper(domain_type)), 'FontSize', 14);

% Save figure
saveas(fig, fullfile(output_folder, sprintf('dispersion_%s.png', domain_type)));
saveas(fig, fullfile(output_folder, sprintf('dispersion_%s.fig', domain_type)));
close(fig);

fprintf('Plots saved to: %s\n', output_folder);
fprintf('============================================\n\n');

end


function result = analyze_single_dispersion(xyz, frequency, sim_params, domain_type)
%% Analyze a single simulation for dispersion properties

[n_particles, ~, n_frames] = size(xyz);

% Get parameters
width = sim_params.width;
drive_amp = sim_params.drive_amplitude;

% Extract x positions
x = squeeze(xyz(:, 1, :));
y = squeeze(xyz(:, 2, :));

% Find equilibrium positions (first few frames)
n_equil = min(10, n_frames);
x0 = mean(x(:, 1:n_equil), 2);
y0 = mean(y(:, 1:n_equil), 2);

% Compute displacements
dx = x - x0;

% Skip transient (first 20% of simulation)
skip_frames = round(0.2 * n_frames);
dx = dx(:, skip_frames:end);

% Bin particles by x position
n_bins = 50;
bin_edges = linspace(0, width, n_bins + 1);
bin_centers = (bin_edges(1:end-1) + bin_edges(2:end)) / 2;

% Average displacement in each bin
binned_dx = zeros(n_bins, size(dx, 2));
for b = 1:n_bins
    in_bin = x0 >= bin_edges(b) & x0 < bin_edges(b+1);
    if sum(in_bin) > 0
        binned_dx(b, :) = mean(dx(in_bin, :), 1);
    end
end

% Measure amplitude at each position (RMS)
amplitudes_vs_x = rms(binned_dx, 2);

% Find wavelength using spatial FFT at steady state
% Average over time to get spatial pattern
mean_profile = mean(abs(binned_dx), 2);

% Spatial FFT
n_spatial = n_bins;
k_spatial = (0:n_spatial-1) / width * 2 * pi;
spatial_fft = fft(mean_profile);
power_spatial = abs(spatial_fft(1:floor(n_spatial/2))).^2;
k_positive = k_spatial(1:floor(n_spatial/2));

% Find dominant k (excluding DC)
[~, peak_idx] = max(power_spatial(2:end));
peak_idx = peak_idx + 1;
k_dominant = k_positive(peak_idx);

% Wavelength
if k_dominant > 0
    wavelength = 2 * pi / k_dominant;
else
    wavelength = NaN;
end

% Phase velocity
omega = 2 * pi * frequency;
if k_dominant > 0
    phase_velocity = omega / k_dominant;
else
    phase_velocity = NaN;
end

% Decay length (fit exponential to amplitude vs x)
try
    % Fit: A(x) = A0 * exp(-x/decay_length)
    valid_bins = amplitudes_vs_x > 0.01 * max(amplitudes_vs_x);
    if sum(valid_bins) > 5
        log_amp = log(amplitudes_vs_x(valid_bins));
        x_valid = bin_centers(valid_bins)';
        p = polyfit(x_valid, log_amp, 1);
        decay_length = -1 / p(1);
    else
        decay_length = NaN;
    end
catch
    decay_length = NaN;
end

% Store results
result = struct();
result.wavelength = wavelength;
result.k = k_dominant;
result.amplitude = mean(amplitudes_vs_x(amplitudes_vs_x > 0));
result.phase_velocity = phase_velocity;
result.decay_length = decay_length;
result.omega = omega;

end
