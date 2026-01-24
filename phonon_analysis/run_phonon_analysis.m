%% run_phonon_analysis.m
% Master script for phonon mode analysis of colloidal crystal simulations
%
% This script provides a complete workflow for analyzing phonon modes,
% including impulse response, dispersion relations, and defect effects.
%
% USAGE:
%   1. Set the configuration parameters below
%   2. Run this script
%   3. Results saved to output folder with figures and .mat files
%
% Author: Gerbode Lab
% Date: 2026

clear; close all; clc;

%% ==================== CONFIGURATION ====================
% Modify these parameters for your analysis

% --- Path Setup ---
% Base path to simulation data
sim_base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\PhononSims';

% --- Simulation Info ---
% Simulation folder names (relative to sim_base_path)
sim_names = {
    'onaxisphonon1impulse_.5',   % 0° direction
    'onaxisphonon2impulse_.5',   % 60° direction
    'onaxisphonon3impulse_.5'    % 120° direction
};

% Build full paths
sim_folders = cell(size(sim_names));
for i = 1:length(sim_names)
    sim_folders{i} = fullfile(sim_base_path, sim_names{i});
end

% Labels for crystallographic directions (triangular lattice principal axes)
direction_labels = {'0° (a_1)', '60° (a_2)', '120° (a_3)'};

% --- Physical Parameters ---
particle_diameter = 10;          % pixels (simulation)
looseness = 1.06;                % lattice looseness parameter
lattice_constant = particle_diameter * looseness;

% Simulation box size (for periodic boundary unwrapping)
% From your sim setup: width=500, height=300
box_size = [500, 300];  % [Lx, Ly] in pixels

% --- Simulation Time Parameters ---
% From TDsim: step_size = 0.05, data_saving_frequency = 100
dt_per_step = 0.05;              % simulation time per step
steps_per_saved_frame = 100;     % data_saving_frequency
dt = dt_per_step * steps_per_saved_frame;  % time between saved frames

% --- Analysis Options ---
analyze_single_sim = true;       % Run full analysis on first simulation
compare_directions = true;       % Compare all three impulse directions
analyze_wave_propagation = true; % Visualize wave propagation
analyze_defects = false;         % Analyze defect modes (set true if defects present)
compute_dos = true;              % Compute density of states
create_animations = false;       % Create video animations (slow)

% --- Output ---
output_folder = 'phonon_results';
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% ==================== LOAD DATA ====================
fprintf('==========================================================\n');
fprintf('           PHONON MODE ANALYSIS - COLLOIDAL CRYSTALS       \n');
fprintf('==========================================================\n\n');

n_sims = length(sim_folders);
all_data = cell(n_sims, 1);

for s = 1:n_sims
    fprintf('Loading simulation %d/%d: %s\n', s, n_sims, sim_folders{s});

    % Look for plist file
    plist_path = fullfile(sim_folders{s}, 'plist.mat');
    if ~exist(plist_path, 'file')
        plist_path = [sim_folders{s} '_plist.mat'];
    end

    if exist(plist_path, 'file')
        loaded = load(plist_path);
        if isfield(loaded, 'plist')
            plist = loaded.plist;
        else
            % Try first field
            fn = fieldnames(loaded);
            plist = loaded.(fn{1});
        end

        % Convert to xyz format: [N_particles, 3, N_frames]
        xyz = plist2xyz_auto(plist);

        % Unwrap periodic boundary crossings
        xyz = unwrap_periodic(xyz, box_size);

        data = struct();
        data.xyz = xyz;
        data.name = sim_folders{s};
        data.label = direction_labels{s};
        [data.N_particles, data.N_dims, data.N_frames] = size(xyz);

        fprintf('  -> %d particles, %d frames\n', data.N_particles, data.N_frames);

        all_data{s} = data;
    else
        warning('Could not find plist for %s', sim_folders{s});
    end
end

%% ==================== SINGLE SIMULATION ANALYSIS ====================
if analyze_single_sim && ~isempty(all_data{1})
    fprintf('\n========== Single Simulation Analysis ==========\n');

    data = all_data{1};
    xyz = data.xyz;
    [N_particles, N_dims, N_frames] = size(xyz);

    % Extract positions
    x = squeeze(xyz(:, 1, :));  % [N_particles, N_frames]
    y = squeeze(xyz(:, 2, :));
    z = squeeze(xyz(:, 3, :));

    % Compute equilibrium (average of first few frames before wave arrives)
    n_equil = min(10, N_frames);
    x0 = mean(x(:, 1:n_equil), 2);
    y0 = mean(y(:, 1:n_equil), 2);
    z0 = mean(z(:, 1:n_equil), 2);

    % Displacements
    ux = x - x0;
    uy = y - y0;
    uz = z - z0;

    % Remove center-of-mass drift
    ux = ux - mean(ux, 1);
    uy = uy - mean(uy, 1);
    uz = uz - mean(uz, 1);

    % --- Temporal Fourier Analysis ---
    fprintf('Computing Fourier analysis...\n');

    window = hanning(N_frames)';
    Ux = fft(ux .* window, [], 2);
    Uy = fft(uy .* window, [], 2);
    Uz = fft(uz .* window, [], 2);

    % Power spectra
    Px = abs(Ux).^2 / N_frames;
    Py = abs(Uy).^2 / N_frames;
    Pz = abs(Uz).^2 / N_frames;

    P_total = sum(Px + Py + Pz, 1);
    P_inplane = sum(Px + Py, 1);
    P_outofplane = sum(Pz, 1);

    % Frequency array
    fs = 1/dt;
    f = (0:N_frames-1) * fs / N_frames;
    n_pos = floor(N_frames/2) + 1;
    f_pos = f(1:n_pos);

    % --- Find Peaks ---
    [peaks, locs] = findpeaks(P_total(1:n_pos), 'MinPeakProminence', max(P_total)*0.01);
    [peaks_sorted, sort_idx] = sort(peaks, 'descend');
    locs_sorted = locs(sort_idx);

    fprintf('\nTop 10 frequency peaks:\n');
    fprintf('Rank\tFrequency\t\tPower\n');
    for i = 1:min(10, length(peaks))
        fprintf('%d\t%.6f\t\t%.2e\n', i, f_pos(locs_sorted(i)), peaks_sorted(i));
    end

    % --- Participation Ratio ---
    participation = zeros(1, n_pos);
    for iw = 1:n_pos
        amp = abs(Ux(:,iw)).^2 + abs(Uy(:,iw)).^2 + abs(Uz(:,iw)).^2;
        amp_norm = amp / sum(amp);
        if sum(amp) > 0
            participation(iw) = 1 / (N_particles * sum(amp_norm.^2));
        end
    end

    % --- Create Figures ---
    figure('Position', [50, 50, 1400, 900], 'Name', 'Phonon Analysis');

    % Power spectrum
    subplot(2, 3, 1);
    semilogy(f_pos, P_total(1:n_pos), 'b-', 'LineWidth', 1.5);
    hold on;
    semilogy(f_pos(locs_sorted(1:min(5,length(locs_sorted)))), ...
        peaks_sorted(1:min(5,length(peaks_sorted))), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    xlabel('Frequency (1/sim time)');
    ylabel('Power Spectral Density');
    title('Total Power Spectrum');
    grid on;
    xlim([0, f_pos(end)/2]);

    % In-plane vs out-of-plane
    subplot(2, 3, 2);
    semilogy(f_pos, P_inplane(1:n_pos), 'b-', 'LineWidth', 1.5, 'DisplayName', 'In-plane (x+y)');
    hold on;
    semilogy(f_pos, P_outofplane(1:n_pos), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Out-of-plane (z)');
    xlabel('Frequency');
    ylabel('Power');
    title('In-plane vs Out-of-plane Modes');
    legend('Location', 'northeast');
    grid on;
    xlim([0, f_pos(end)/2]);

    % Participation ratio
    subplot(2, 3, 3);
    plot(f_pos, participation, 'g-', 'LineWidth', 1.5);
    xlabel('Frequency');
    ylabel('Participation Ratio');
    title('Mode Localization (1=extended, 0=localized)');
    ylim([0, 1]);
    grid on;
    xlim([0, f_pos(end)/2]);

    % X, Y, Z component spectra
    subplot(2, 3, 4);
    semilogy(f_pos, sum(Px(:,1:n_pos),1), 'r-', 'LineWidth', 1.5, 'DisplayName', 'X (longitudinal)');
    hold on;
    semilogy(f_pos, sum(Py(:,1:n_pos),1), 'b-', 'LineWidth', 1.5, 'DisplayName', 'Y (transverse)');
    semilogy(f_pos, sum(Pz(:,1:n_pos),1), 'g-', 'LineWidth', 1.5, 'DisplayName', 'Z (buckle)');
    xlabel('Frequency');
    ylabel('Power');
    title('Component-Resolved Spectra');
    legend('Location', 'northeast');
    grid on;
    xlim([0, f_pos(end)/2]);

    % Mode shape for dominant mode
    subplot(2, 3, 5);
    if ~isempty(locs_sorted)
        mode_idx = locs_sorted(1);
        mode_amp = abs(Ux(:,mode_idx)) + abs(Uy(:,mode_idx));
        scatter(x0, y0, 20, mode_amp, 'filled');
        colormap(hot);
        colorbar;
        axis equal;
        title(sprintf('Mode Shape at f = %.4f', f_pos(mode_idx)));
        xlabel('x'); ylabel('y');
    end

    % Mode shape vectors for dominant mode
    subplot(2, 3, 6);
    if ~isempty(locs_sorted)
        scale = 30;
        scatter(x0, y0, 10, [0.7 0.7 0.7], 'filled');
        hold on;
        quiver(x0, y0, scale*real(Ux(:,mode_idx)), scale*real(Uy(:,mode_idx)), 0, 'r', 'LineWidth', 0.8);
        axis equal;
        title(sprintf('Mode Displacement Pattern'));
        xlabel('x'); ylabel('y');
    end

    saveas(gcf, fullfile(output_folder, [data.name '_analysis.png']));
    saveas(gcf, fullfile(output_folder, [data.name '_analysis.fig']));

    % Save results
    single_results = struct();
    single_results.f = f_pos;
    single_results.P_total = P_total(1:n_pos);
    single_results.P_inplane = P_inplane(1:n_pos);
    single_results.P_outofplane = P_outofplane(1:n_pos);
    single_results.participation = participation;
    single_results.peak_frequencies = f_pos(locs_sorted);
    single_results.peak_powers = peaks_sorted;
    single_results.x0 = x0;
    single_results.y0 = y0;
    single_results.z0 = z0;
    single_results.N_particles = N_particles;
    single_results.N_frames = N_frames;
    single_results.dt = dt;

    save(fullfile(output_folder, [data.name '_results.mat']), 'single_results');
end

%% ==================== WAVE PROPAGATION VISUALIZATION ====================
if analyze_wave_propagation && ~isempty(all_data{1})
    fprintf('\n========== Wave Propagation Analysis ==========\n');

    data = all_data{1};
    xyz = data.xyz;

    x = squeeze(xyz(:, 1, :));
    y = squeeze(xyz(:, 2, :));
    x0 = mean(x(:, 1:min(10, size(x,2))), 2);
    y0 = mean(y(:, 1:min(10, size(y,2))), 2);

    if create_animations
        visualize_wave_propagation(xyz, x0, y0, 'all', fullfile(output_folder, data.name));
    else
        frames_to_show = round(linspace(1, data.N_frames, 12));
        visualize_wave_propagation(xyz, x0, y0, frames_to_show, fullfile(output_folder, data.name));
    end
end

%% ==================== DIRECTION COMPARISON ====================
if compare_directions && n_sims >= 3
    fprintf('\n========== Comparing Impulse Directions ==========\n');

    % Process all simulations
    figure('Position', [50, 50, 1400, 500]);
    colors = {'r', 'b', 'g'};

    all_spectra = cell(n_sims, 1);

    for s = 1:n_sims
        if isempty(all_data{s})
            continue;
        end

        data = all_data{s};
        xyz = data.xyz;
        N_frames = data.N_frames;

        x = squeeze(xyz(:, 1, :));
        y = squeeze(xyz(:, 2, :));

        x0 = mean(x(:, 1:min(10, N_frames)), 2);
        y0 = mean(y(:, 1:min(10, N_frames)), 2);

        ux = x - x0; ux = ux - mean(ux, 1);
        uy = y - y0; uy = uy - mean(uy, 1);

        window = hanning(N_frames)';
        Ux = fft(ux .* window, [], 2);
        Uy = fft(uy .* window, [], 2);

        P = sum(abs(Ux).^2 + abs(Uy).^2, 1) / N_frames;
        f = (0:N_frames-1) / (N_frames * dt);
        n_pos = floor(N_frames/2) + 1;

        all_spectra{s}.f = f(1:n_pos);
        all_spectra{s}.P = P(1:n_pos);
        all_spectra{s}.label = data.label;
    end

    % Plot comparison
    subplot(1, 3, 1);
    for s = 1:n_sims
        if ~isempty(all_spectra{s})
            semilogy(all_spectra{s}.f, all_spectra{s}.P, colors{s}, ...
                'LineWidth', 1.5, 'DisplayName', all_spectra{s}.label);
            hold on;
        end
    end
    xlabel('Frequency');
    ylabel('Power');
    title('Power Spectra - All Directions');
    legend('Location', 'northeast');
    grid on;

    % Anisotropy analysis
    subplot(1, 3, 2);
    if n_sims >= 2 && ~isempty(all_spectra{1}) && ~isempty(all_spectra{2})
        n_f = min(cellfun(@(x) length(x.f), all_spectra(~cellfun(@isempty, all_spectra))));
        P_matrix = zeros(sum(~cellfun(@isempty, all_spectra)), n_f);
        idx = 1;
        for s = 1:n_sims
            if ~isempty(all_spectra{s})
                P_matrix(idx, :) = all_spectra{s}.P(1:n_f);
                idx = idx + 1;
            end
        end

        anisotropy = std(P_matrix, 0, 1) ./ (mean(P_matrix, 1) + 1e-10);
        plot(all_spectra{1}.f(1:n_f), anisotropy, 'k-', 'LineWidth', 1.5);
        xlabel('Frequency');
        ylabel('Anisotropy (std/mean)');
        title('Directional Anisotropy');
        grid on;
    end

    % Peak frequency comparison
    subplot(1, 3, 3);
    hold on;
    for s = 1:n_sims
        if ~isempty(all_spectra{s})
            [pks, locs] = findpeaks(all_spectra{s}.P, 'NPeaks', 5, 'SortStr', 'descend');
            peak_freqs = all_spectra{s}.f(locs);
            scatter(ones(size(peak_freqs))*s, peak_freqs, 60, colors{s}, 'filled');
        end
    end
    xticks(1:n_sims);
    xticklabels(direction_labels);
    ylabel('Peak Frequency');
    title('Peak Frequencies by Direction');
    grid on;

    saveas(gcf, fullfile(output_folder, 'direction_comparison.png'));
    saveas(gcf, fullfile(output_folder, 'direction_comparison.fig'));

    save(fullfile(output_folder, 'direction_comparison.mat'), 'all_spectra');
end

%% ==================== DENSITY OF STATES ====================
if compute_dos && ~isempty(all_data{1})
    fprintf('\n========== Computing Density of States ==========\n');

    data = all_data{1};
    [vacf, t_lag, dos] = compute_velocity_autocorrelation(data.xyz, dt, 0.5);

    dos_results = struct();
    dos_results.vacf = vacf;
    dos_results.t_lag = t_lag;
    dos_results.f = dos.f;
    dos_results.dos = dos.g;

    save(fullfile(output_folder, 'density_of_states.mat'), 'dos_results');
    saveas(gcf, fullfile(output_folder, 'velocity_autocorrelation.png'));
end

%% ==================== SUMMARY ====================
fprintf('\n==========================================================\n');
fprintf('                    ANALYSIS COMPLETE                       \n');
fprintf('==========================================================\n');
fprintf('Results saved to: %s\n', output_folder);
fprintf('\nFiles generated:\n');
files = dir(fullfile(output_folder, '*'));
for i = 1:length(files)
    if ~files(i).isdir
        fprintf('  - %s\n', files(i).name);
    end
end
fprintf('\n');
