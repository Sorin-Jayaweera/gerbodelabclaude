%% run_master_analysis.m
% MASTER ANALYSIS SCRIPT
%
% This script performs the complete pipeline:
% 1. System setup (git pull, addpath, rehash)
% 2. Fix/regenerate corrupt xyz_data.mat files from plist.mat
% 3. Create interesting comparison videos (with random sims)
% 4. Generate all analysis plots for the analysis viewer
%    (including random and stripe_top which were previously missing)
%
% Author: Gerbode Lab
% Date: 2026

clear; close all; clc;

%% ==================== 1. SYSTEM SETUP ====================
fprintf('============================================\n');
fprintf('   STEP 1: SYSTEM SETUP\n');
fprintf('============================================\n');

% Get paths (auto-detects Windows vs Linux)
paths = get_paths();

% Git pull to get latest code
fprintf('Pulling latest code from git...\n');
old_dir = pwd;
cd(paths.root);
try
    [status, result] = system('git pull');
    if status == 0
        fprintf('Git pull successful:\n%s\n', result);
    else
        fprintf('Git pull warning (may be OK if no changes):\n%s\n', result);
    end
catch ME
    fprintf('Git pull skipped: %s\n', ME.message);
end
cd(old_dir);

% Add paths
fprintf('\nAdding paths...\n');
addpath(genpath(paths.colloid_work));
addpath(genpath(paths.simulations));
addpath(genpath(paths.phonon_analysis));
fprintf('Paths added.\n');

% Rehash toolbox cache
fprintf('Rehashing toolbox cache...\n');
rehash toolboxcache;
rehash path;
fprintf('Rehash complete.\n\n');

%% ==================== 2. FIX/REGENERATE XYZ_DATA ====================
fprintf('============================================\n');
fprintf('   STEP 2: FIX/REGENERATE XYZ_DATA FILES\n');
fprintf('============================================\n');

base_path = paths.sims;

% All simulation types including random and stripe_top
sim_configs = {
    struct('name', 'chevron_side', 'folder', 'drivensinesims', ...
           'fmt', 'sinusoidal_f%.4f_a2.0');
    struct('name', 'stripe_side', 'folder', 'stripesinesims', ...
           'fmt', 'sinusoidal_f%.4f_a2.0_stripes');
    struct('name', 'random_side', 'folder', 'randomsinesims', ...
           'fmt', 'sinusoidal_f%.4f_a2.0_random');
    struct('name', 'frust_side', 'folder', 'frustsinesims', ...
           'fmt', 'frust_f%.4f_a2.0');
    struct('name', 'chevron_top', 'folder', 'topdrivensims', ...
           'fmt', 'topdriven_f%.4f_a2.0');
    struct('name', 'frust_top', 'folder', 'frusttopsims', ...
           'fmt', 'frusttop_f%.4f_a2.0');
    struct('name', 'stripe_top', 'folder', 'stripetopsims', ...
           'fmt', 'stripetop_f%.4f_a2.0');
};

% Frequencies to check
frequencies = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...
               0.001,  0.0012, 0.0015, 0.0018, ...
               0.002,  0.0025, 0.003,  0.004,  0.005, ...
               0.007,  0.01,   0.02,   0.05,   0.10];

total_fixed = 0;
total_generated = 0;

for ci = 1:length(sim_configs)
    cfg = sim_configs{ci};
    fprintf('Checking %s (%s)...\n', cfg.name, cfg.folder);

    for fi = 1:length(frequencies)
        freq = frequencies(fi);
        sim_name = sprintf(cfg.fmt, freq);

        % Check both direct folder and simulations subfolder
        paths_to_check = {
            fullfile(base_path, cfg.folder, sim_name);
            fullfile(base_path, cfg.folder, 'simulations', sim_name);
        };

        for pi = 1:length(paths_to_check)
            sim_path = paths_to_check{pi};
            plist_path = fullfile(sim_path, 'plist.mat');
            xyz_path = fullfile(sim_path, 'xyz_data.mat');

            if ~exist(plist_path, 'file')
                continue;
            end

            needs_regeneration = false;
            reason = '';

            % Check if xyz_data.mat exists
            if ~exist(xyz_path, 'file')
                needs_regeneration = true;
                reason = 'missing';
            else
                % Check if xyz_data.mat is corrupt
                try
                    info = whos('-file', xyz_path);
                    if isempty(info)
                        needs_regeneration = true;
                        reason = 'empty';
                    else
                        % Try to load it
                        loaded = load(xyz_path);
                        if ~isfield(loaded, 'xyz') || isempty(loaded.xyz)
                            needs_regeneration = true;
                            reason = 'no xyz field';
                        elseif any(isnan(loaded.xyz(:))) || any(isinf(loaded.xyz(:)))
                            needs_regeneration = true;
                            reason = 'contains NaN/Inf';
                        end
                    end
                catch ME
                    needs_regeneration = true;
                    reason = 'corrupt';
                end
            end

            if needs_regeneration
                fprintf('  f=%.4f: %s - regenerating from plist...', freq, reason);

                % Delete corrupt file if it exists
                if exist(xyz_path, 'file')
                    delete(xyz_path);
                    total_fixed = total_fixed + 1;
                else
                    total_generated = total_generated + 1;
                end

                try
                    % Load plist
                    loaded = load(plist_path);
                    if isfield(loaded, 'plist')
                        plist = loaded.plist;
                    else
                        fn = fieldnames(loaded);
                        plist = loaded.(fn{1});
                    end

                    % Convert plist to xyz based on format
                    if isstruct(plist) && isfield(plist, 'pos')
                        % Format 1: struct array with .pos field
                        N_frames = length(plist);
                        N_particles = size(plist(1).pos, 1);
                        xyz = zeros(N_particles, 3, N_frames);
                        for t = 1:N_frames
                            xyz(:,:,t) = plist(t).pos;
                        end

                    elseif iscell(plist)
                        % Format 2: cell array of position matrices
                        N_frames = length(plist);
                        N_particles = size(plist{1}, 1);
                        xyz = zeros(N_particles, 3, N_frames);
                        for t = 1:N_frames
                            xyz(:,:,t) = plist{t};
                        end

                    elseif isnumeric(plist) && size(plist, 2) >= 4
                        % Format 3: matrix [x, y, z, frame_id, ...]
                        frame_col = plist(:, 4);
                        all_frame_ids = unique(frame_col);
                        N_frames = length(all_frame_ids);

                        first_frame_mask = (frame_col == all_frame_ids(1));
                        N_particles = sum(first_frame_mask);
                        xyz = zeros(N_particles, 3, N_frames);

                        for t = 1:N_frames
                            mask = (frame_col == all_frame_ids(t));
                            frame_data = plist(mask, 1:3);
                            n_use = min(size(frame_data, 1), N_particles);
                            xyz(1:n_use, :, t) = frame_data(1:n_use, :);
                        end

                    elseif isnumeric(plist) && ndims(plist) == 3
                        % Format 4: already xyz format
                        xyz = plist;
                        N_particles = size(xyz, 1);
                        N_frames = size(xyz, 3);

                    else
                        error('Unknown format');
                    end

                    % Save xyz_data.mat
                    save(xyz_path, 'xyz', '-v7.3');
                    fprintf(' OK (%d particles, %d frames)\n', N_particles, N_frames);

                catch ME
                    fprintf(' FAILED: %s\n', ME.message);
                end
            end

            break;  % Found plist, don't check other paths
        end
    end
end

fprintf('\nXYZ regeneration complete.\n');
fprintf('  Fixed corrupt: %d\n', total_fixed);
fprintf('  Generated new: %d\n\n', total_generated);

%% ==================== 3. CREATE COMPARISON VIDEOS ====================
fprintf('============================================\n');
fprintf('   STEP 3: CREATE COMPARISON VIDEOS\n');
fprintf('============================================\n');

try
    create_interesting_comparison_videos();
    fprintf('Comparison videos complete.\n\n');
catch ME
    fprintf('WARNING: Video creation failed: %s\n\n', ME.message);
end

%% ==================== 4. GENERATE ALL ANALYSIS PLOTS ====================
fprintf('============================================\n');
fprintf('   STEP 4: GENERATE ALL ANALYSIS PLOTS\n');
fprintf('============================================\n');

output_base = paths.analysis_output;

% Create output directory
if ~exist(output_base, 'dir')
    mkdir(output_base);
end

% Experiment configurations - NOW INCLUDING RANDOM AND STRIPE_TOP
experiments = {
    struct('name', 'chevron_side', 'folder', 'drivensinesims', ...
           'fmt', 'sinusoidal_f%.4f_a2.0', 'top_driven', false, ...
           'desc', 'Chevron lattice with side-driven sinusoidal forcing');
    struct('name', 'stripe_side', 'folder', 'stripesinesims', ...
           'fmt', 'sinusoidal_f%.4f_a2.0_stripes', 'top_driven', false, ...
           'desc', 'Stripe domain lattice with side-driven forcing');
    struct('name', 'random_side', 'folder', 'randomsinesims', ...
           'fmt', 'sinusoidal_f%.4f_a2.0_random', 'top_driven', false, ...
           'desc', 'Random domain lattice with side-driven forcing');
    struct('name', 'frust_side', 'folder', 'frustsinesims', ...
           'fmt', 'frust_f%.4f_a2.0', 'top_driven', false, ...
           'desc', 'Frustrated lattice with side-driven forcing');
    struct('name', 'chevron_top', 'folder', 'topdrivensims', ...
           'fmt', 'topdriven_f%.4f_a2.0', 'top_driven', true, ...
           'desc', 'Chevron lattice with top-driven sinusoidal forcing');
    struct('name', 'frust_top', 'folder', 'frusttopsims', ...
           'fmt', 'frusttop_f%.4f_a2.0', 'top_driven', true, ...
           'desc', 'Frustrated lattice with top-driven forcing');
    struct('name', 'stripe_top', 'folder', 'stripetopsims', ...
           'fmt', 'stripetop_f%.4f_a2.0', 'top_driven', true, ...
           'desc', 'Stripe domain lattice with top-driven forcing');
};

% Analysis options
opts = struct();
opts.save_fig = true;
opts.save_png = true;
opts.save_mat = true;
opts.frame_range = [0 100];
opts.n_bins_spatial = 60;
opts.n_bins_kymo = 80;

% Physical parameters
params = struct();
params.particle_diameter = 10;
params.looseness = 1.06;
params.lattice_constant = params.particle_diameter * params.looseness;
params.box_size = [500, 300];

% Pre-create output folders
for exp_idx = 1:length(experiments)
    exp_output = fullfile(output_base, experiments{exp_idx}.name);
    if ~exist(exp_output, 'dir')
        mkdir(exp_output);
    end
    for fi = 1:length(frequencies)
        freq = frequencies(fi);
        freq_folder = fullfile(exp_output, sprintf('f%.4f', freq));
        if ~exist(freq_folder, 'dir')
            mkdir(freq_folder);
        end
    end
end

fprintf('Running analysis for %d experiments across %d frequencies...\n', ...
    length(experiments), length(frequencies));

% Process each experiment
for exp_idx = 1:length(experiments)
    exp = experiments{exp_idx};
    fprintf('\n--- Processing %s ---\n', upper(exp.name));

    exp_output = fullfile(output_base, exp.name);
    n_processed = 0;
    n_skipped = 0;

    for fi = 1:length(frequencies)
        freq = frequencies(fi);
        sim_name = sprintf(exp.fmt, freq);

        % Check both locations
        paths_to_check = {
            fullfile(base_path, exp.folder, sim_name);
            fullfile(base_path, exp.folder, 'simulations', sim_name);
        };

        xyz_loaded = false;
        xyz = [];

        for pi = 1:length(paths_to_check)
            sim_path = paths_to_check{pi};
            xyz_path = fullfile(sim_path, 'xyz_data.mat');

            if exist(xyz_path, 'file')
                try
                    loaded = load(xyz_path);
                    xyz = loaded.xyz;
                    xyz_loaded = true;
                    break;
                catch
                    continue;
                end
            end
        end

        if ~xyz_loaded
            n_skipped = n_skipped + 1;
            continue;
        end

        n_processed = n_processed + 1;
        freq_output = fullfile(exp_output, sprintf('f%.4f', freq));

        try
            % Run all analysis types
            run_single_frequency_analysis(xyz, freq, freq_output, params, opts, exp);
        catch ME
            fprintf('  f=%.4f: ERROR - %s\n', freq, ME.message);
        end
    end

    fprintf('  Processed: %d, Skipped: %d\n', n_processed, n_skipped);

    % Generate summary plots
    if n_processed > 0
        try
            generate_experiment_summary(exp_output, exp.name, frequencies, opts);
        catch ME
            fprintf('  Summary plots failed: %s\n', ME.message);
        end
    end
end

fprintf('\n============================================\n');
fprintf('   ALL STEPS COMPLETE\n');
fprintf('============================================\n');
fprintf('Analysis output: %s\n', output_base);
fprintf('Now launch analysis_viewer to browse results.\n');

%% ==================== HELPER FUNCTIONS ====================

function run_single_frequency_analysis(xyz, freq, output_dir, params, opts, exp)
    % Run all analysis types for a single frequency

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    N_particles = size(xyz, 1);
    N_frames = size(xyz, 3);

    % Compute mean positions and displacements
    x0 = mean(xyz(:, 1, 1:min(10, N_frames)), 3);
    y0 = mean(xyz(:, 2, 1:min(10, N_frames)), 3);
    z0 = mean(xyz(:, 3, 1:min(10, N_frames)), 3);

    dx = squeeze(xyz(:, 1, :)) - x0;
    dy = squeeze(xyz(:, 2, :)) - y0;
    dz = squeeze(xyz(:, 3, :)) - z0;

    % Time vector
    dt = 1;  % frame time
    t = (0:N_frames-1) * dt;

    %% 1. Bode Analysis (Amplitude & Phase vs Position)
    try
        n_bins = opts.n_bins_spatial;

        if exp.top_driven
            % For top-driven: bin by y position
            pos_coord = y0;
            coord_label = 'Y position';
        else
            % For side-driven: bin by x position
            pos_coord = x0;
            coord_label = 'X position';
        end

        bin_edges = linspace(min(pos_coord), max(pos_coord), n_bins+1);
        bin_centers = (bin_edges(1:end-1) + bin_edges(2:end)) / 2;

        amplitude_vs_pos = zeros(n_bins, 1);
        phase_vs_pos = zeros(n_bins, 1);

        for b = 1:n_bins
            in_bin = pos_coord >= bin_edges(b) & pos_coord < bin_edges(b+1);
            if sum(in_bin) < 5
                amplitude_vs_pos(b) = NaN;
                phase_vs_pos(b) = NaN;
                continue;
            end

            % Get mean displacement in this bin
            if exp.top_driven
                disp_bin = mean(dy(in_bin, :), 1);
            else
                disp_bin = mean(dx(in_bin, :), 1);
            end

            % FFT
            Y = fft(disp_bin);
            fs = 1 / dt;
            f_axis = (0:length(Y)-1) * fs / length(Y);

            % Find bin closest to drive frequency
            [~, freq_bin] = min(abs(f_axis - freq));

            amplitude_vs_pos(b) = abs(Y(freq_bin)) / N_frames;
            phase_vs_pos(b) = angle(Y(freq_bin));
        end

        % Unwrap phase
        phase_vs_pos = unwrap(phase_vs_pos);

        % Plot
        fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

        subplot(1, 2, 1);
        plot(bin_centers, amplitude_vs_pos, 'b-', 'LineWidth', 2);
        xlabel(coord_label);
        ylabel('Amplitude');
        title(sprintf('Amplitude vs %s (f=%.4f)', coord_label, freq));
        grid on;

        subplot(1, 2, 2);
        plot(bin_centers, rad2deg(phase_vs_pos), 'r-', 'LineWidth', 2);
        xlabel(coord_label);
        ylabel('Phase (deg)');
        title(sprintf('Phase vs %s (f=%.4f)', coord_label, freq));
        grid on;

        sgtitle(sprintf('Bode Analysis - %s', upper(exp.name)));

        if opts.save_png
            saveas(fig, fullfile(output_dir, 'bode_analysis.png'));
        end
        if opts.save_fig
            savefig(fig, fullfile(output_dir, 'bode_analysis.fig'));
        end
        if opts.save_mat
            save(fullfile(output_dir, 'bode_data.mat'), ...
                'bin_centers', 'amplitude_vs_pos', 'phase_vs_pos', 'freq');
        end
        close(fig);
    catch ME
        % Silent fail for individual analysis
    end

    %% 2. Fourier Analysis (Power Spectrum)
    try
        % Compute power spectrum from mean displacement
        mean_dx = mean(dx, 1);

        Y = fft(mean_dx);
        P = abs(Y).^2 / N_frames;
        fs = 1 / dt;
        f_axis = (0:length(Y)-1) * fs / length(Y);

        % Only positive frequencies
        n_half = floor(length(Y)/2);
        f_pos = f_axis(1:n_half);
        P_pos = P(1:n_half);

        % Find peak
        [peak_val, peak_idx] = max(P_pos(2:end));
        peak_freq = f_pos(peak_idx + 1);

        % Plot
        fig = figure('Position', [100 100 800 400], 'Visible', 'off');

        semilogy(f_pos, P_pos, 'b-', 'LineWidth', 1.5);
        hold on;
        xline(freq, 'r--', 'LineWidth', 2, 'Label', 'Drive freq');
        xline(peak_freq, 'g--', 'LineWidth', 1.5, 'Label', 'Peak');
        hold off;

        xlabel('Frequency');
        ylabel('Power');
        title(sprintf('Fourier Analysis - %s (f=%.4f)', upper(exp.name), freq));
        xlim([0 min(0.2, max(f_pos))]);
        grid on;
        legend('Power spectrum', 'Location', 'best');

        if opts.save_png
            saveas(fig, fullfile(output_dir, 'fourier_analysis.png'));
        end
        if opts.save_fig
            savefig(fig, fullfile(output_dir, 'fourier_analysis.fig'));
        end
        if opts.save_mat
            save(fullfile(output_dir, 'fourier_data.mat'), ...
                'f_pos', 'P_pos', 'peak_freq', 'freq');
        end
        close(fig);
    catch ME
        % Silent fail
    end

    %% 3. Penetration Depth
    try
        if exp.top_driven
            pos_coord = y0;
            disp_data = dy;
        else
            pos_coord = x0;
            disp_data = dx;
        end

        % Compute RMS amplitude per particle
        amp_per_particle = rms(disp_data, 2);

        % Bin by position
        n_bins = 30;
        bin_edges = linspace(min(pos_coord), max(pos_coord), n_bins+1);
        bin_centers = (bin_edges(1:end-1) + bin_edges(2:end)) / 2;
        amp_vs_pos = zeros(n_bins, 1);

        for b = 1:n_bins
            in_bin = pos_coord >= bin_edges(b) & pos_coord < bin_edges(b+1);
            if sum(in_bin) > 0
                amp_vs_pos(b) = mean(amp_per_particle(in_bin));
            end
        end

        % Fit exponential decay
        valid = amp_vs_pos > 0.01 * max(amp_vs_pos);
        if sum(valid) > 3
            log_amp = log(amp_vs_pos(valid));
            x_fit = bin_centers(valid)';
            p = polyfit(x_fit - x_fit(1), log_amp, 1);
            decay_length = -1 / p(1);
            A0 = exp(p(2));

            x_fit_line = linspace(min(x_fit), max(x_fit), 100);
            fit_line = A0 * exp(-abs(x_fit_line - x_fit(1)) / decay_length);
        else
            decay_length = NaN;
        end

        % Plot
        fig = figure('Position', [100 100 600 400], 'Visible', 'off');

        plot(bin_centers, amp_vs_pos, 'bo', 'MarkerSize', 8, 'LineWidth', 2);
        hold on;
        if ~isnan(decay_length)
            plot(x_fit_line, fit_line, 'r-', 'LineWidth', 2);
        end
        hold off;

        xlabel('Position');
        ylabel('RMS Amplitude');
        title(sprintf('Penetration Depth - %s (f=%.4f, delta=%.1f)', ...
            upper(exp.name), freq, decay_length));
        grid on;
        legend('Data', 'Exponential fit', 'Location', 'best');

        if opts.save_png
            saveas(fig, fullfile(output_dir, 'penetration_analysis.png'));
        end
        if opts.save_fig
            savefig(fig, fullfile(output_dir, 'penetration_analysis.fig'));
        end
        if opts.save_mat
            save(fullfile(output_dir, 'penetration_data.mat'), ...
                'bin_centers', 'amp_vs_pos', 'decay_length', 'freq');
        end
        close(fig);
    catch ME
        % Silent fail
    end

    %% 4. MSD (Mean Squared Displacement)
    try
        r0 = xyz(:, 1:2, 1);
        msd = zeros(N_frames, 1);
        for ff = 1:N_frames
            dr = xyz(:, 1:2, ff) - r0;
            msd(ff) = mean(sum(dr.^2, 2));
        end

        % Plot
        fig = figure('Position', [100 100 600 400], 'Visible', 'off');

        loglog(t(2:end), msd(2:end), 'b-', 'LineWidth', 1.5);
        xlabel('Time (frames)');
        ylabel('MSD (px^2)');
        title(sprintf('Mean Squared Displacement - %s (f=%.4f)', upper(exp.name), freq));
        grid on;

        if opts.save_png
            saveas(fig, fullfile(output_dir, 'msd_analysis.png'));
        end
        if opts.save_fig
            savefig(fig, fullfile(output_dir, 'msd_analysis.fig'));
        end
        if opts.save_mat
            save(fullfile(output_dir, 'msd_data.mat'), 't', 'msd', 'freq');
        end
        close(fig);
    catch ME
        % Silent fail
    end

    %% 5. Anisotropy Analysis (X vs Y response)
    try
        amp_x = rms(dx, 2);
        amp_y = rms(dy, 2);

        ratio = amp_x ./ amp_y;
        ratio(isinf(ratio) | isnan(ratio)) = [];
        mean_ratio = mean(ratio);

        % Plot
        fig = figure('Position', [100 100 800 400], 'Visible', 'off');

        subplot(1, 2, 1);
        scatter(amp_x, amp_y, 20, 'b', 'filled', 'MarkerFaceAlpha', 0.3);
        hold on;
        max_amp = max([amp_x; amp_y]);
        plot([0 max_amp], [0 max_amp], 'k--', 'LineWidth', 1);
        hold off;
        xlabel('X amplitude');
        ylabel('Y amplitude');
        title('X vs Y Response');
        axis equal;
        grid on;

        subplot(1, 2, 2);
        histogram(ratio, 30, 'FaceColor', 'b', 'FaceAlpha', 0.7);
        xlabel('Amplitude ratio (X/Y)');
        ylabel('Count');
        title(sprintf('Anisotropy Distribution (mean=%.2f)', mean_ratio));
        xline(1, 'r--', 'LineWidth', 2);
        grid on;

        sgtitle(sprintf('Anisotropy Analysis - %s (f=%.4f)', upper(exp.name), freq));

        if opts.save_png
            saveas(fig, fullfile(output_dir, 'anisotropy_analysis.png'));
        end
        if opts.save_fig
            savefig(fig, fullfile(output_dir, 'anisotropy_analysis.fig'));
        end
        if opts.save_mat
            save(fullfile(output_dir, 'anisotropy_data.mat'), ...
                'amp_x', 'amp_y', 'ratio', 'mean_ratio', 'freq');
        end
        close(fig);
    catch ME
        % Silent fail
    end
end

function generate_experiment_summary(exp_output, exp_name, frequencies, opts)
    % Generate summary plots across all frequencies

    % Collect data
    penetration_depths = [];
    peak_amplitudes = [];
    valid_freqs = [];

    for fi = 1:length(frequencies)
        freq = frequencies(fi);
        freq_folder = fullfile(exp_output, sprintf('f%.4f', freq));
        pen_file = fullfile(freq_folder, 'penetration_data.mat');

        if exist(pen_file, 'file')
            try
                data = load(pen_file);
                if ~isnan(data.decay_length) && data.decay_length > 0
                    penetration_depths(end+1) = data.decay_length;
                    peak_amplitudes(end+1) = max(data.amp_vs_pos);
                    valid_freqs(end+1) = freq;
                end
            catch
                continue;
            end
        end
    end

    if length(valid_freqs) < 2
        return;
    end

    % Plot penetration depth summary
    fig = figure('Position', [100 100 800 400], 'Visible', 'off');

    subplot(1, 2, 1);
    loglog(valid_freqs, penetration_depths, 'bo-', 'LineWidth', 2, 'MarkerSize', 10);
    xlabel('Driving Frequency');
    ylabel('Penetration Depth (px)');
    title('Penetration Depth vs Frequency');
    grid on;

    subplot(1, 2, 2);
    loglog(valid_freqs, peak_amplitudes, 'ro-', 'LineWidth', 2, 'MarkerSize', 10);
    xlabel('Driving Frequency');
    ylabel('Peak Amplitude (px)');
    title('Peak Response vs Frequency');
    grid on;

    sgtitle(sprintf('%s - Summary', upper(strrep(exp_name, '_', ' '))));

    if opts.save_png
        saveas(fig, fullfile(exp_output, 'penetration_summary.png'));
    end
    if opts.save_fig
        savefig(fig, fullfile(exp_output, 'penetration_summary.fig'));
    end
    close(fig);
end
