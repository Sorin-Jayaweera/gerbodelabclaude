function results = analyze_freq_response_for_batch(batch_folder, domain_type)
%% ANALYZE_FREQ_RESPONSE_FOR_BATCH Analyze frequency response (Bode plot) for any batch
%
% INPUTS:
%   batch_folder - Path to the batch simulation folder
%   domain_type  - String identifier ('zigzag', 'stripe', 'random', 'topdriven')
%
% OUTPUTS:
%   results      - Structure with frequency response analysis
%
% Author: Gerbode Lab
% Date: 2026

fprintf('============================================\n');
fprintf('  FREQUENCY RESPONSE ANALYSIS: %s\n', upper(domain_type));
fprintf('============================================\n');

%% Setup paths
simulations_folder = fullfile(batch_folder, 'simulations');
if ~exist(simulations_folder, 'dir')
    simulations_folder = batch_folder;
end

output_folder = fullfile(batch_folder, 'analysis');
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% Find completed simulations - pattern depends on domain type
switch domain_type
    case 'topdriven'
        sim_pattern = 'topdriven_f*_a*';
        freq_regex = 'topdriven_f([\d.]+)_a';
    case 'frust_side'
        sim_pattern = 'frust_f*_a*';
        freq_regex = 'frust_f([\d.]+)_a';
    case 'frust_top'
        sim_pattern = 'frusttop_f*_a*';
        freq_regex = 'frusttop_f([\d.]+)_a';
    otherwise  % chevron, stripe, random
        sim_pattern = 'sinusoidal_f*_a*';
        freq_regex = 'sinusoidal_f([\d.]+)_a';
end

sim_dirs = dir(fullfile(simulations_folder, sim_pattern));
frequencies = [];
sim_paths = {};

for i = 1:length(sim_dirs)
    folder_name = sim_dirs(i).name;
    tokens = regexp(folder_name, freq_regex, 'tokens');

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

%% Measurement positions (fraction of box width)
measure_fractions = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8];

%% Initialize results
n_freqs = length(frequencies);
n_positions = length(measure_fractions);

results = struct();
results.domain_type = domain_type;
results.frequencies = frequencies(:)';
results.measure_fractions = measure_fractions;
results.magnitude = nan(n_freqs, n_positions);  % |H(f)|
results.phase_deg = nan(n_freqs, n_positions);  % Phase in degrees
results.coherence = nan(n_freqs, n_positions);  % Signal quality

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

        % Analyze frequency response at each position
        for p = 1:n_positions
            frac = measure_fractions(p);
            [mag, phase, coh] = measure_response_at_position(xyz, f, sim_params, frac, domain_type);
            results.magnitude(i, p) = mag;
            results.phase_deg(i, p) = phase;
            results.coherence(i, p) = coh;
        end

    catch ME
        fprintf('    ERROR: %s\n', ME.message);
    end
end

%% Save results
results_file = fullfile(output_folder, sprintf('freq_response_%s.mat', domain_type));
save(results_file, 'results');
fprintf('Results saved to: %s\n', results_file);

%% Generate Bode plots
fig = figure('Position', [100 100 1400 600], 'Visible', 'off');

% Plot 1: Magnitude response
subplot(1, 2, 1);
hold on;
colors = lines(n_positions);
for p = 1:n_positions
    valid = ~isnan(results.magnitude(:, p));
    semilogx(results.frequencies(valid), 20*log10(results.magnitude(valid, p)), ...
        'o-', 'Color', colors(p,:), 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'DisplayName', sprintf('x = %.0f%%', measure_fractions(p)*100));
end
hold off;
xlabel('Frequency f');
ylabel('Magnitude (dB)');
title('Magnitude Response');
legend('Location', 'best');
grid on;

% Plot 2: Phase response
subplot(1, 2, 2);
hold on;
for p = 1:n_positions
    valid = ~isnan(results.phase_deg(:, p));
    semilogx(results.frequencies(valid), results.phase_deg(valid, p), ...
        's-', 'Color', colors(p,:), 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'DisplayName', sprintf('x = %.0f%%', measure_fractions(p)*100));
end
hold off;
xlabel('Frequency f');
ylabel('Phase (degrees)');
title('Phase Response');
legend('Location', 'best');
grid on;

sgtitle(sprintf('Bode Plot: %s Domain', upper(domain_type)), 'FontSize', 14);

% Save figure
saveas(fig, fullfile(output_folder, sprintf('bode_%s.png', domain_type)));
saveas(fig, fullfile(output_folder, sprintf('bode_%s.fig', domain_type)));
close(fig);

fprintf('Plots saved to: %s\n', output_folder);
fprintf('============================================\n\n');

end


function [magnitude, phase_deg, coherence] = measure_response_at_position(xyz, frequency, sim_params, x_fraction, domain_type)
%% Measure frequency response at a specific x position

[n_particles, ~, n_frames] = size(xyz);

% Get box dimensions
width = sim_params.width;
height = sim_params.height;
drive_amp = sim_params.drive_amplitude;
data_freq = sim_params.data_saving_frequency;

% Determine measurement direction based on drive direction
if strcmp(domain_type, 'topdriven')
    % Y-driven: measure Y displacement, select by Y position
    pos = squeeze(xyz(:, 2, :));
    pos_select = squeeze(xyz(:, 2, 1));
    target_pos = height * (1 - x_fraction);  % Measure from top
    box_dim = height;
else
    % X-driven: measure X displacement, select by X position
    pos = squeeze(xyz(:, 1, :));
    pos_select = squeeze(xyz(:, 1, 1));
    target_pos = width * x_fraction;
    box_dim = width;
end

% Find equilibrium
n_equil = min(10, n_frames);
pos0 = mean(pos(:, 1:n_equil), 2);

% Compute displacements
dpos = pos - pos0;

% Select particles near target position
bin_width = box_dim * 0.05;  % 5% of box
in_region = abs(pos_select - target_pos) < bin_width;

if sum(in_region) < 5
    magnitude = NaN;
    phase_deg = NaN;
    coherence = NaN;
    return;
end

% Average displacement in region
avg_displacement = mean(dpos(in_region, :), 1);

% Skip transient
skip_frames = round(0.3 * n_frames);
signal = avg_displacement(skip_frames:end);
n_signal = length(signal);

% Generate reference drive signal
t = (skip_frames:n_frames-1) * data_freq;
drive_signal = drive_amp * sin(2 * pi * frequency * t);

% Cross-correlation to find phase lag
[xcorr_vals, lags] = xcorr(signal, drive_signal, 'coeff');
[~, max_idx] = max(abs(xcorr_vals));
lag_frames = lags(max_idx);
phase_lag = 2 * pi * frequency * lag_frames * data_freq;
phase_deg = rad2deg(phase_lag);

% Wrap phase to [-180, 180]
phase_deg = mod(phase_deg + 180, 360) - 180;

% Magnitude: RMS of response / drive amplitude
response_rms = rms(signal);
magnitude = response_rms / drive_amp;

% Coherence: max cross-correlation value
coherence = max(abs(xcorr_vals));

end
