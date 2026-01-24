%% compare_impulse_directions.m
% Compare phonon responses from impulses along different crystallographic axes
%
% For a triangular lattice, the three principal directions are:
%   - 0° (along a1 lattice vector)
%   - 60° (along a2 lattice vector)
%   - 30° (perpendicular to dense rows - "zigzag" direction)
%
% Author: Gerbode Lab

%% ========== CONFIGURATION ==========

% List of simulation folders/names
sim_names = {
    'onaxisphonon1impulse_.5',   % Direction 1
    'onaxisphonon2impulse_.5',   % Direction 2
    'onaxisphonon3impulse_.5'    % Direction 3
};

% Labels for each direction (update based on your actual setup)
direction_labels = {
    'Axis 1 (0°)',
    'Axis 2 (60°)',
    'Axis 3 (120°)'
};

colors = {'r', 'b', 'g'};

% Physical parameters (should match your simulations)
particle_diameter = 10;
looseness = 1.06;
lattice_constant = particle_diameter * looseness;
data_saving_frequency = 100;
dt_sim = 0.05;
dt = dt_sim * data_saving_frequency;

%% ========== LOAD AND PROCESS ALL SIMULATIONS ==========

n_sims = length(sim_names);
all_results = cell(n_sims, 1);

for s = 1:n_sims
    fprintf('\n========== Processing %s ==========\n', sim_names{s});

    % Load data
    plist_file = [sim_names{s} '/plist.mat'];
    if ~exist(plist_file, 'file')
        % Try alternative path
        plist_file = [sim_names{s} '.mat'];
    end

    load(plist_file, 'plist');
    xyz = plist2xyz(plist);

    [N_particles, N_dims, N_frames] = size(xyz);
    fprintf('Loaded %d particles, %d frames\n', N_particles, N_frames);

    % Extract positions
    x = squeeze(xyz(:, 1, :));
    y = squeeze(xyz(:, 2, :));

    % Compute equilibrium and displacements
    n_equil = min(10, N_frames);
    x0 = mean(x(:, 1:n_equil), 2);
    y0 = mean(y(:, 1:n_equil), 2);

    ux = x - x0;
    uy = y - y0;

    % Remove drift
    ux = ux - mean(ux, 1);
    uy = uy - mean(uy, 1);

    % Temporal FFT
    window = hanning(N_frames)';
    Ux = fft(ux .* window, [], 2);
    Uy = fft(uy .* window, [], 2);

    % Power spectra
    Px = abs(Ux).^2 / N_frames;
    Py = abs(Uy).^2 / N_frames;

    % Total power
    P_total = sum(Px + Py, 1);

    % Frequency array
    fs = 1/dt;
    f = (0:N_frames-1) * fs / N_frames;
    n_pos = floor(N_frames/2) + 1;
    f_pos = f(1:n_pos);
    P_pos = P_total(1:n_pos);

    % Store results
    results = struct();
    results.f = f_pos;
    results.P_total = P_pos;
    results.P_x = sum(Px(:, 1:n_pos), 1);
    results.P_y = sum(Py(:, 1:n_pos), 1);
    results.x0 = x0;
    results.y0 = y0;
    results.Ux = Ux;
    results.Uy = Uy;
    results.N_particles = N_particles;
    results.N_frames = N_frames;

    all_results{s} = results;
end

%% ========== COMPARATIVE VISUALIZATION ==========

fprintf('\nCreating comparative plots...\n');

% Figure 1: Power spectra comparison
figure('Position', [100, 100, 1400, 800]);

subplot(2, 2, 1);
for s = 1:n_sims
    semilogy(all_results{s}.f, all_results{s}.P_total, colors{s}, ...
        'LineWidth', 1.5, 'DisplayName', direction_labels{s});
    hold on;
end
xlabel('Frequency (1/sim time)');
ylabel('Power Spectral Density');
title('Total Power Spectrum - All Directions');
legend('Location', 'northeast');
grid on;
xlim([0, max(all_results{1}.f)/2]);

subplot(2, 2, 2);
for s = 1:n_sims
    semilogy(all_results{s}.f, all_results{s}.P_x, colors{s}, ...
        'LineWidth', 1.5, 'DisplayName', direction_labels{s});
    hold on;
end
xlabel('Frequency (1/sim time)');
ylabel('Power Spectral Density');
title('X-Component Power Spectrum (Longitudinal)');
legend('Location', 'northeast');
grid on;
xlim([0, max(all_results{1}.f)/2]);

subplot(2, 2, 3);
for s = 1:n_sims
    semilogy(all_results{s}.f, all_results{s}.P_y, colors{s}, ...
        'LineWidth', 1.5, 'DisplayName', direction_labels{s});
    hold on;
end
xlabel('Frequency (1/sim time)');
ylabel('Power Spectral Density');
title('Y-Component Power Spectrum (Transverse)');
legend('Location', 'northeast');
grid on;
xlim([0, max(all_results{1}.f)/2]);

subplot(2, 2, 4);
% Ratio of longitudinal to transverse
for s = 1:n_sims
    ratio = all_results{s}.P_x ./ (all_results{s}.P_y + 1e-10);
    semilogy(all_results{s}.f, ratio, colors{s}, ...
        'LineWidth', 1.5, 'DisplayName', direction_labels{s});
    hold on;
end
xlabel('Frequency (1/sim time)');
ylabel('P_x / P_y');
title('Longitudinal / Transverse Ratio');
legend('Location', 'northeast');
grid on;
xlim([0, max(all_results{1}.f)/2]);

saveas(gcf, 'impulse_comparison_spectra.png');
saveas(gcf, 'impulse_comparison_spectra.fig');

%% ========== PEAK COMPARISON ==========

figure('Position', [100, 100, 1000, 400]);

% Find peaks for each simulation
all_peaks = cell(n_sims, 1);

for s = 1:n_sims
    [pks, locs] = findpeaks(all_results{s}.P_total, ...
        'MinPeakProminence', max(all_results{s}.P_total) * 0.02);
    [pks_sorted, idx] = sort(pks, 'descend');
    locs_sorted = locs(idx);

    peak_freqs = all_results{s}.f(locs_sorted);
    all_peaks{s} = peak_freqs(1:min(10, length(peak_freqs)));
end

% Bar plot of peak frequencies
subplot(1, 2, 1);
hold on;
for s = 1:n_sims
    n_peaks = length(all_peaks{s});
    bar((1:n_peaks) + (s-2)*0.25, all_peaks{s}(1:n_peaks), 0.2, colors{s});
end
xlabel('Peak Rank');
ylabel('Frequency');
title('Top Peak Frequencies by Direction');
legend(direction_labels, 'Location', 'northeast');

% Scatter plot of peaks
subplot(1, 2, 2);
for s = 1:n_sims
    peaks = all_peaks{s};
    scatter(ones(size(peaks))*s, peaks, 50, colors{s}, 'filled');
    hold on;
end
xlim([0.5, n_sims + 0.5]);
xticks(1:n_sims);
xticklabels(direction_labels);
ylabel('Frequency');
title('Peak Frequency Distribution');

saveas(gcf, 'impulse_comparison_peaks.png');
saveas(gcf, 'impulse_comparison_peaks.fig');

%% ========== ANISOTROPY ANALYSIS ==========

fprintf('\n========== Anisotropy Analysis ==========\n');

% Compare the spectra at each frequency to quantify anisotropy
% Anisotropy = std(P) / mean(P) at each frequency

n_freq = length(all_results{1}.f);
P_matrix = zeros(n_sims, n_freq);

for s = 1:n_sims
    P_matrix(s, :) = all_results{s}.P_total;
end

anisotropy = std(P_matrix, 0, 1) ./ (mean(P_matrix, 1) + 1e-10);

figure('Position', [100, 100, 800, 400]);

subplot(1, 2, 1);
plot(all_results{1}.f, anisotropy, 'k-', 'LineWidth', 1.5);
xlabel('Frequency');
ylabel('Anisotropy (std/mean)');
title('Directional Anisotropy vs Frequency');
xlim([0, max(all_results{1}.f)/2]);
grid on;

subplot(1, 2, 2);
% Find frequencies with highest anisotropy
[~, high_aniso_idx] = sort(anisotropy, 'descend');
high_aniso_idx = high_aniso_idx(1:min(20, length(high_aniso_idx)));
high_aniso_freqs = all_results{1}.f(high_aniso_idx);

histogram(high_aniso_freqs, 20);
xlabel('Frequency');
ylabel('Count');
title('Frequencies with High Anisotropy');

saveas(gcf, 'impulse_anisotropy.png');

%% ========== SAVE COMPARATIVE RESULTS ==========

comparison_results = struct();
comparison_results.sim_names = sim_names;
comparison_results.direction_labels = direction_labels;
comparison_results.all_results = all_results;
comparison_results.all_peaks = all_peaks;
comparison_results.anisotropy = anisotropy;
comparison_results.frequencies = all_results{1}.f;

save('impulse_comparison_results.mat', 'comparison_results');

fprintf('\nComparison complete! Results saved to impulse_comparison_results.mat\n');

%% ========== REPORT ==========

fprintf('\n========== SUMMARY REPORT ==========\n');
fprintf('Number of particles: %d\n', all_results{1}.N_particles);
fprintf('Number of frames: %d\n', all_results{1}.N_frames);
fprintf('Frequency resolution: %.6f\n', all_results{1}.f(2) - all_results{1}.f(1));
fprintf('Nyquist frequency: %.4f\n', max(all_results{1}.f));

fprintf('\nTop 5 peaks for each direction:\n');
for s = 1:n_sims
    fprintf('%s: ', direction_labels{s});
    fprintf('%.4f  ', all_peaks{s}(1:min(5, length(all_peaks{s}))));
    fprintf('\n');
end
