%% Frequency Response Analysis - Bode Plot Style
% Analyzes magnitude attenuation and phase shift vs frequency
% at different distances from the driven boundary
%
% Outputs:
%   - Magnitude response (attenuation) vs frequency at multiple distances
%   - Phase response (lag) vs frequency at multiple distances
%   - Transfer function H(f) = response/drive as function of position

clear; close all;

%% Configuration
% Path to batch simulation folder
batch_folder = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\drivensinesims';
sim_base_path = batch_folder;

% Frequencies are auto-detected from available simulation folders below
drive_amplitude = 2.0;  % Known input amplitude in pixels

% Measurement positions (fraction of box width from left edge)
measure_positions = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8];  % 10% to 80% across

% Analysis parameters
num_cycles_skip = 5;    % Skip initial transient (cycles)
num_cycles_analyze = 10; % Analyze this many cycles for steady-state

%% Find completed simulations
sim_dirs = dir(fullfile(sim_base_path, 'sinusoidal_f*_a2.0'));
completed_freqs = [];
completed_paths = {};

for i = 1:length(sim_dirs)
    folder_name = sim_dirs(i).name;
    % Extract frequency from folder name
    tokens = regexp(folder_name, 'sinusoidal_f([\d.]+)_a', 'tokens');
    if ~isempty(tokens)
        f = str2double(tokens{1}{1});
        % Check if plist file exists
        plist_file = fullfile(sim_base_path, folder_name, 'plist.txt');
        if exist(plist_file, 'file')
            completed_freqs(end+1) = f;
            completed_paths{end+1} = fullfile(sim_base_path, folder_name);
        end
    end
end

[completed_freqs, sort_idx] = sort(completed_freqs);
completed_paths = completed_paths(sort_idx);

fprintf('Found %d completed simulations\n', length(completed_freqs));

%% Initialize storage
n_freqs = length(completed_freqs);
n_positions = length(measure_positions);

magnitude_response = nan(n_freqs, n_positions);  % |H(f)| at each position
phase_response = nan(n_freqs, n_positions);       % angle(H(f)) in degrees
coherence = nan(n_freqs, n_positions);            % How clean is the response

%% Process each simulation
for f_idx = 1:n_freqs
    freq = completed_freqs(f_idx);
    sim_path = completed_paths{f_idx};

    fprintf('Processing f = %.4f (%d/%d)...\n', freq, f_idx, n_freqs);

    % Load trajectory data
    plist_file = fullfile(sim_path, 'plist.txt');
    [positions, box_size, n_particles, n_frames] = load_plist_data(plist_file);

    if isempty(positions)
        fprintf('  Failed to load data, skipping\n');
        continue;
    end

    % Determine frames to analyze
    frames_per_cycle = round(1 / freq);
    start_frame = num_cycles_skip * frames_per_cycle + 1;
    end_frame = min(start_frame + num_cycles_analyze * frames_per_cycle, n_frames);

    if end_frame <= start_frame
        fprintf('  Not enough frames for analysis, skipping\n');
        continue;
    end

    analyze_frames = start_frame:end_frame;
    n_analyze = length(analyze_frames);

    % Get initial positions for displacement calculation
    x0 = squeeze(positions(1, :, 1));  % Initial x positions

    % Find particles at measurement positions
    for p_idx = 1:n_positions
        target_x = measure_positions(p_idx) * box_size(1);

        % Find particles near this x position (within 5% of box width)
        tolerance = 0.05 * box_size(1);
        particle_mask = abs(x0 - target_x) < tolerance;
        particle_indices = find(particle_mask);

        if isempty(particle_indices)
            continue;
        end

        % Extract x-displacement time series for these particles
        x_displacements = zeros(n_analyze, length(particle_indices));
        for t = 1:n_analyze
            frame = analyze_frames(t);
            x_displacements(t, :) = positions(frame, particle_indices, 1) - x0(particle_indices);
        end

        % Average displacement across particles at this position
        avg_displacement = mean(x_displacements, 2);

        % Generate reference drive signal
        t_vec = (0:n_analyze-1)';
        drive_signal = drive_amplitude * sin(2 * pi * freq * (analyze_frames(1) + t_vec - 1));

        % Compute transfer function using cross-correlation / FFT
        [mag, phase_deg, coh] = compute_transfer_function(drive_signal, avg_displacement, freq, 1);

        magnitude_response(f_idx, p_idx) = mag;
        phase_response(f_idx, p_idx) = phase_deg;
        coherence(f_idx, p_idx) = coh;
    end

    fprintf('  Done. Avg magnitude at 50%%: %.3f\n', magnitude_response(f_idx, 4));
end

%% Create Bode Plots
figure('Position', [100, 100, 1400, 900], 'Name', 'Frequency Response Analysis');

% Color map for different positions
colors = parula(n_positions);
position_labels = arrayfun(@(x) sprintf('%.0f%% from edge', x*100), measure_positions, 'UniformOutput', false);

% Subplot 1: Magnitude Response (dB)
subplot(2, 2, 1);
hold on;
for p_idx = 1:n_positions
    mag_dB = 20 * log10(magnitude_response(:, p_idx) + 1e-10);
    valid = ~isnan(mag_dB);
    plot(completed_freqs(valid), mag_dB(valid), 'o-', 'Color', colors(p_idx,:), ...
         'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', position_labels{p_idx});
end
hold off;
set(gca, 'XScale', 'log');
xlabel('Frequency (cycles/frame)');
ylabel('Magnitude (dB)');
title('Magnitude Response |H(f)|');
legend('Location', 'southwest');
grid on;
xlim([min(completed_freqs)*0.8, max(completed_freqs)*1.2]);

% Subplot 2: Magnitude Response (linear)
subplot(2, 2, 2);
hold on;
for p_idx = 1:n_positions
    valid = ~isnan(magnitude_response(:, p_idx));
    plot(completed_freqs(valid), magnitude_response(valid, p_idx), 'o-', 'Color', colors(p_idx,:), ...
         'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', position_labels{p_idx});
end
hold off;
set(gca, 'XScale', 'log');
xlabel('Frequency (cycles/frame)');
ylabel('Magnitude (ratio)');
title('Magnitude Response |H(f)| - Linear Scale');
legend('Location', 'northeast');
grid on;
xlim([min(completed_freqs)*0.8, max(completed_freqs)*1.2]);

% Subplot 3: Phase Response
subplot(2, 2, 3);
hold on;
for p_idx = 1:n_positions
    valid = ~isnan(phase_response(:, p_idx));
    plot(completed_freqs(valid), phase_response(valid, p_idx), 'o-', 'Color', colors(p_idx,:), ...
         'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', position_labels{p_idx});
end
hold off;
set(gca, 'XScale', 'log');
xlabel('Frequency (cycles/frame)');
ylabel('Phase (degrees)');
title('Phase Response \angle H(f)');
legend('Location', 'southwest');
grid on;
xlim([min(completed_freqs)*0.8, max(completed_freqs)*1.2]);
% Add reference lines
yline(0, '--k', 'LineWidth', 0.5);
yline(-180, ':k', 'LineWidth', 0.5);
yline(-360, ':k', 'LineWidth', 0.5);

% Subplot 4: Coherence (signal quality)
subplot(2, 2, 4);
hold on;
for p_idx = 1:n_positions
    valid = ~isnan(coherence(:, p_idx));
    plot(completed_freqs(valid), coherence(valid, p_idx), 'o-', 'Color', colors(p_idx,:), ...
         'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', position_labels{p_idx});
end
hold off;
set(gca, 'XScale', 'log');
xlabel('Frequency (cycles/frame)');
ylabel('Coherence');
title('Coherence (Signal Quality)');
legend('Location', 'southwest');
grid on;
xlim([min(completed_freqs)*0.8, max(completed_freqs)*1.2]);
ylim([0, 1.1]);

sgtitle('Bode Plot - Phonon Frequency Response', 'FontSize', 14, 'FontWeight', 'bold');

%% Figure 2: Attenuation vs Distance
figure('Position', [150, 150, 1200, 500], 'Name', 'Spatial Attenuation');

% Select subset of frequencies for clarity
freq_subset_idx = round(linspace(1, n_freqs, min(8, n_freqs)));
colors2 = jet(length(freq_subset_idx));

subplot(1, 2, 1);
hold on;
distances = measure_positions * box_size(1);  % Convert to pixels
for i = 1:length(freq_subset_idx)
    f_idx = freq_subset_idx(i);
    mag = magnitude_response(f_idx, :);
    valid = ~isnan(mag);
    plot(distances(valid), mag(valid), 'o-', 'Color', colors2(i,:), ...
         'LineWidth', 2, 'MarkerSize', 8, ...
         'DisplayName', sprintf('f = %.4f', completed_freqs(f_idx)));
end
hold off;
xlabel('Distance from drive (pixels)');
ylabel('Magnitude (ratio)');
title('Amplitude Attenuation vs Distance');
legend('Location', 'northeast');
grid on;

subplot(1, 2, 2);
hold on;
for i = 1:length(freq_subset_idx)
    f_idx = freq_subset_idx(i);
    phase = phase_response(f_idx, :);
    valid = ~isnan(phase);
    plot(distances(valid), phase(valid), 'o-', 'Color', colors2(i,:), ...
         'LineWidth', 2, 'MarkerSize', 8, ...
         'DisplayName', sprintf('f = %.4f', completed_freqs(f_idx)));
end
hold off;
xlabel('Distance from drive (pixels)');
ylabel('Phase (degrees)');
title('Phase Lag vs Distance');
legend('Location', 'southwest');
grid on;

sgtitle('Spatial Dependence of Frequency Response', 'FontSize', 14, 'FontWeight', 'bold');

%% Figure 3: Attenuation Length vs Frequency
figure('Position', [200, 200, 600, 500], 'Name', 'Attenuation Length');

% Fit exponential decay to get attenuation length at each frequency
attenuation_lengths = nan(n_freqs, 1);
for f_idx = 1:n_freqs
    mag = magnitude_response(f_idx, :);
    valid = ~isnan(mag) & mag > 0.01;  % Need positive magnitude

    if sum(valid) >= 3
        x_data = (measure_positions(valid) * box_size(1))';
        y_data = mag(valid)';

        % Fit: mag = A * exp(-x / L)
        % log(mag) = log(A) - x/L
        try
            p = polyfit(x_data, log(y_data), 1);
            if p(1) < 0  % Should be decaying
                attenuation_lengths(f_idx) = -1 / p(1);
            end
        catch
            % Fit failed, leave as NaN
        end
    end
end

valid_L = ~isnan(attenuation_lengths) & attenuation_lengths > 0 & attenuation_lengths < box_size(1)*2;
loglog(completed_freqs(valid_L), attenuation_lengths(valid_L), 'bo-', 'LineWidth', 2, 'MarkerSize', 10);
xlabel('Frequency (cycles/frame)');
ylabel('Attenuation Length (pixels)');
title('Attenuation Length vs Frequency');
grid on;

% Add power law fit if enough points
if sum(valid_L) >= 3
    p = polyfit(log(completed_freqs(valid_L)), log(attenuation_lengths(valid_L)), 1);
    hold on;
    f_fit = logspace(log10(min(completed_freqs)), log10(max(completed_freqs)), 50);
    L_fit = exp(p(2)) * f_fit.^p(1);
    plot(f_fit, L_fit, 'r--', 'LineWidth', 1.5, 'DisplayName', sprintf('L \\propto f^{%.2f}', p(1)));
    legend('Data', sprintf('Fit: L \\propto f^{%.2f}', p(1)), 'Location', 'northeast');
    hold off;
end

%% Save results
results.frequencies = completed_freqs;
results.measure_positions = measure_positions;
results.magnitude_response = magnitude_response;
results.phase_response = phase_response;
results.coherence = coherence;
results.attenuation_lengths = attenuation_lengths;
results.box_size = box_size;

% Save to analysis subfolder
analysis_folder = fullfile(batch_folder, 'analysis');
if ~exist(analysis_folder, 'dir')
    mkdir(analysis_folder);
end
save(fullfile(analysis_folder, 'frequency_response_results.mat'), 'results');
fprintf('\nResults saved to %s\n', fullfile(analysis_folder, 'frequency_response_results.mat'));

%% Print summary table
fprintf('\n=== Frequency Response Summary ===\n');
fprintf('%-10s | %-12s | %-12s | %-12s\n', 'Freq', 'Mag@50%', 'Phase@50%', 'Atten.Length');
fprintf('%s\n', repmat('-', 1, 55));
for f_idx = 1:n_freqs
    fprintf('%-10.4f | %-12.4f | %-12.1f | %-12.1f\n', ...
        completed_freqs(f_idx), ...
        magnitude_response(f_idx, 4), ...
        phase_response(f_idx, 4), ...
        attenuation_lengths(f_idx));
end

%% Helper Functions

function [positions, box_size, n_particles, n_frames] = load_plist_data(plist_file)
    % Load particle trajectory data from plist file
    positions = [];
    box_size = [640, 480];  % Default
    n_particles = 0;
    n_frames = 0;

    try
        data = dlmread(plist_file);
        n_frames = size(data, 1);
        n_cols = size(data, 2);

        % Determine format (with or without box size columns)
        % Try to auto-detect number of particles
        % Format: [x1, y1, x2, y2, ...] or [x1, y1, x2, y2, ..., box_w, box_h]

        % Check if last two columns are constant (box size)
        if n_cols > 4
            last_col = data(:, end);
            second_last = data(:, end-1);
            if std(last_col) < 1 && std(second_last) < 1
                % Last two columns are box size
                box_size = [data(1, end-1), data(1, end)];
                data = data(:, 1:end-2);
                n_cols = size(data, 2);
            end
        end

        n_particles = n_cols / 2;
        if mod(n_cols, 2) ~= 0
            warning('Odd number of columns in plist');
            return;
        end

        % Reshape to [frames, particles, 2]
        positions = zeros(n_frames, n_particles, 2);
        for p = 1:n_particles
            positions(:, p, 1) = data(:, 2*p - 1);  % x
            positions(:, p, 2) = data(:, 2*p);      % y
        end

    catch ME
        warning('Failed to load %s: %s', plist_file, ME.message);
    end
end

function [magnitude, phase_deg, coh] = compute_transfer_function(input_signal, output_signal, freq, fs)
    % Compute transfer function magnitude and phase at the drive frequency
    % Uses FFT-based approach

    n = length(input_signal);

    % Apply Hann window to reduce spectral leakage
    window = 0.5 * (1 - cos(2*pi*(0:n-1)'/(n-1)));
    input_windowed = input_signal .* window;
    output_windowed = output_signal .* window;

    % FFT
    nfft = 2^nextpow2(n);
    fft_input = fft(input_windowed, nfft);
    fft_output = fft(output_windowed, nfft);

    % Find frequency bin closest to drive frequency
    freq_axis = (0:nfft-1) * fs / nfft;
    [~, freq_bin] = min(abs(freq_axis - freq));

    % Transfer function at drive frequency
    H = fft_output(freq_bin) / fft_input(freq_bin);

    magnitude = abs(H);
    phase_deg = angle(H) * 180 / pi;

    % Compute coherence (how much of output is at drive frequency)
    output_power = sum(abs(fft_output).^2);
    drive_power = abs(fft_output(freq_bin))^2;
    coh = drive_power / output_power;

    % Unwrap phase to be negative (lag)
    if phase_deg > 0
        phase_deg = phase_deg - 360;
    end
end
