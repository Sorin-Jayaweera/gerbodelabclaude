%% run_full_analysis.m
% COMPREHENSIVE PHONON ANALYSIS SUITE
%
% This script performs complete analysis of all simulation types:
% - Runs top-driven simulations for side-driven geometries
% - Clears old analysis data
% - Generates all analysis plots for every frequency
% - Creates documentation
%
% Analysis types included:
% 1. Bode plots (amplitude & phase vs frequency)
% 2. Fourier analysis (temporal frequency decomposition)
% 3. Penetration depth (decay length vs frequency)
% 4. Resonant frequency detection
% 5. Anisotropy analysis (directional response)
% 6. Momentum space analysis (dispersion, optical/acoustic modes)
% 7. Resonant decomposition
% 8. Velocity autocorrelation & density of states
% 9. Mean squared displacement
% 10. Correlation functions
%
% PARALLELIZATION: Uses parfor to distribute frequency analyses across cores.
% Requires Parallel Computing Toolbox.
%
% Author: Gerbode Lab
% Date: 2026

clear; close all; clc;

%% ==================== CONFIGURATION ====================
% Base paths
base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\sims';
output_base = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\analysis_output';

% Create output directory
if ~exist(output_base, 'dir')
    mkdir(output_base);
end

% Experiment configurations
experiments = {
    % name, folder, name_format, is_top_driven, description
    struct('name', 'chevron_side', 'folder', 'drivensinesims', ...
           'fmt', 'sinusoidal_f%.4f_a2.0', 'top_driven', false, ...
           'desc', 'Chevron lattice with side-driven sinusoidal forcing');
    struct('name', 'stripe_side', 'folder', 'stripesinesims', ...
           'fmt', 'sinusoidal_f%.4f_a2.0_stripes', 'top_driven', false, ...
           'desc', 'Stripe domain lattice with side-driven forcing');
    struct('name', 'frust_side', 'folder', 'frustsinesims', ...
           'fmt', 'frust_f%.4f_a2.0', 'top_driven', false, ...
           'desc', 'Frustrated lattice with side-driven forcing');
    struct('name', 'chevron_top', 'folder', 'topdrivensims', ...
           'fmt', 'topdriven_f%.4f_a2.0', 'top_driven', true, ...
           'desc', 'Chevron lattice with top-driven sinusoidal forcing');
    struct('name', 'frust_top', 'folder', 'frusttopsims', ...
           'fmt', 'frusttop_f%.4f_a2.0', 'top_driven', true, ...
           'desc', 'Frustrated lattice with top-driven forcing');
};

% Frequencies to analyze
frequencies = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...
               0.001,  0.0012, 0.0015, 0.0018, ...
               0.002,  0.0025, 0.003,  0.004,  0.005, ...
               0.007,  0.01,   0.02,   0.05,   0.10];

% Analysis options
opts = struct();
opts.clear_old_analysis = true;    % Clear existing analysis data
opts.save_fig = true;              % Save .fig files (for MATLAB interaction)
opts.save_png = true;              % Save .png files (for documents)
opts.save_mat = true;              % Save .mat data files
opts.frame_range = [0 100];        % Percent range to load [start end]
opts.n_bins_spatial = 60;          % Spatial bins for wavefront
opts.n_bins_kymo = 80;             % Bins for kymograph
opts.create_videos = true;         % Create frequency evolution videos

% Physical parameters
params = struct();
params.particle_diameter = 10;     % pixels
params.looseness = 1.06;
params.lattice_constant = params.particle_diameter * params.looseness;
params.box_size = [500, 300];      % [Lx, Ly] pixels

% Parallelization options
use_parallel = true;               % Set to false to run sequentially
n_workers = [];                    % [] = use default pool size

%% ==================== CLEAR OLD ANALYSIS ====================
if opts.clear_old_analysis && exist(output_base, 'dir')
    fprintf('Clearing old analysis data...\n');
    % Keep the directory but remove contents
    old_files = dir(fullfile(output_base, '**/*'));
    for i = 1:length(old_files)
        if ~old_files(i).isdir
            delete(fullfile(old_files(i).folder, old_files(i).name));
        end
    end
    fprintf('Old analysis cleared.\n');
end

%% ==================== START PARALLEL POOL ====================
if use_parallel
    % Check if Parallel Computing Toolbox is available
    if ~license('test', 'Distrib_Computing_Toolbox')
        warning('Parallel Computing Toolbox not available. Running sequentially.');
        use_parallel = false;
    else
        % Start parallel pool if not already running
        pool = gcp('nocreate');
        if isempty(pool)
            if isempty(n_workers)
                pool = parpool;
            else
                pool = parpool(n_workers);
            end
            fprintf('Started parallel pool with %d workers.\n', pool.NumWorkers);
        else
            fprintf('Using existing parallel pool with %d workers.\n', pool.NumWorkers);
        end
    end
end

%% ==================== BUILD JOB LIST ====================
% Flatten experiments and frequencies into a single job array
jobs = {};
for exp_idx = 1:length(experiments)
    exp = experiments{exp_idx};
    for freq_idx = 1:length(frequencies)
        freq = frequencies(freq_idx);
        jobs{end+1} = struct('exp_idx', exp_idx, 'freq_idx', freq_idx, ...
                             'exp', exp, 'freq', freq);
    end
end
n_jobs = length(jobs);

fprintf('==========================================================\n');
fprintf('         COMPREHENSIVE PHONON ANALYSIS SUITE              \n');
fprintf('             (PARALLEL MODE: %s)                          \n', string(use_parallel));
fprintf('==========================================================\n');
fprintf('Experiments: %d\n', length(experiments));
fprintf('Frequencies: %d\n', length(frequencies));
fprintf('Total jobs: %d\n\n', n_jobs);

%% ==================== CREATE OUTPUT FOLDERS ====================
% Pre-create all output folders (parfor can't create nested folders reliably)
for exp_idx = 1:length(experiments)
    exp_output = fullfile(output_base, experiments{exp_idx}.name);
    if ~exist(exp_output, 'dir')
        mkdir(exp_output);
    end
    for freq_idx = 1:length(frequencies)
        freq_str = sprintf('f%.4f', frequencies(freq_idx));
        freq_output = fullfile(exp_output, freq_str);
        if ~exist(freq_output, 'dir')
            mkdir(freq_output);
        end
    end
end

%% ==================== MAIN ANALYSIS LOOP (PARALLEL) ====================
% Results array for logging (cell array for parfor compatibility)
log_results = cell(n_jobs, 1);

fprintf('Starting analysis at %s...\n', datestr(now, 'HH:MM:SS'));
start_time = tic;

if use_parallel
    % Create DataQueue for progress updates
    progress_queue = parallel.pool.DataQueue;
    completed_count = 0;

    % Progress callback function
    afterEach(progress_queue, @(data) update_progress(data, n_jobs));

    parfor job_idx = 1:n_jobs
        job = jobs{job_idx};
        result = run_single_analysis(job, base_path, output_base, opts, params);
        log_results{job_idx} = result;
        % Send progress update
        send(progress_queue, struct('job_idx', job_idx, 'exp', job.exp.name, ...
             'freq', job.freq, 'result', result));
    end
else
    for job_idx = 1:n_jobs
        job = jobs{job_idx};
        fprintf('Job %d/%d: %s f=%.4f\n', job_idx, n_jobs, job.exp.name, job.freq);
        log_results{job_idx} = run_single_analysis(job, base_path, output_base, opts, params);
    end
end

elapsed = toc(start_time);
fprintf('\n*** PARALLEL ANALYSIS FINISHED at %s (%.1f minutes) ***\n', datestr(now, 'HH:MM:SS'), elapsed/60);

%% ==================== WRITE LOG FILE ====================
log_file = fullfile(output_base, 'analysis_log.txt');
fid = fopen(log_file, 'w');
fprintf(fid, 'Analysis Log - %s\n', datestr(now));
fprintf(fid, 'Parallel mode: %s\n', string(use_parallel));
fprintf(fid, '==========================================================\n\n');

% Group results by experiment
for exp_idx = 1:length(experiments)
    exp = experiments{exp_idx};
    fprintf(fid, '\nExperiment: %s\n', exp.name);
    fprintf(fid, 'Description: %s\n', exp.desc);

    for freq_idx = 1:length(frequencies)
        job_idx = (exp_idx - 1) * length(frequencies) + freq_idx;
        result = log_results{job_idx};
        fprintf(fid, '  Frequency %.4f: %s\n', frequencies(freq_idx), result);
    end
end
fclose(fid);

% Count results
n_success = sum(contains(log_results, 'SUCCESS'));
n_skipped = sum(contains(log_results, 'SKIPPED'));
n_error = sum(contains(log_results, 'ERROR'));

fprintf('\n==========================================================\n');
fprintf('              PARALLEL ANALYSIS COMPLETE                  \n');
fprintf('==========================================================\n');
fprintf('Success: %d | Skipped: %d | Errors: %d\n', n_success, n_skipped, n_error);

%% ==================== GENERATE CROSS-FREQUENCY PLOTS ====================
fprintf('\n========== Generating Cross-Frequency Analyses ==========\n');

for exp_idx = 1:length(experiments)
    exp = experiments{exp_idx};
    exp_name = exp.name;
    exp_output = fullfile(output_base, exp_name);

    if ~exist(exp_output, 'dir')
        continue;
    end

    fprintf('Processing %s...\n', exp_name);

    try
        % Bode plot across all frequencies
        generate_bode_summary(exp_output, exp_name, frequencies, opts);

        % Penetration depth vs frequency
        generate_penetration_summary(exp_output, exp_name, frequencies, opts);

        % Resonance summary
        generate_resonance_summary(exp_output, exp_name, frequencies, opts);

    catch ME
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

%% ==================== GENERATE DOCUMENTATION ====================
fprintf('\n========== Generating Documentation ==========\n');
generate_analysis_documentation(output_base, experiments, frequencies);

%% ==================== GENERATE FREQUENCY EVOLUTION VIDEOS ====================
if opts.create_videos
    fprintf('\n========== Generating Frequency Evolution Videos ==========\n');
    video_opts = struct();
    video_opts.frame_rate = 2;  % 2 fps - each frequency visible for 0.5 sec
    video_opts.video_format = 'mp4';
    video_opts.add_labels = true;
    stitch_frequency_videos(output_base, experiments, frequencies, video_opts);
end

%% ==================== SUMMARY ====================
fprintf('\n==========================================================\n');
fprintf('                  ANALYSIS COMPLETE                        \n');
fprintf('==========================================================\n');
fprintf('Output folder: %s\n', output_base);
fprintf('Log file: %s\n', log_file);
fprintf('Total jobs: %d (Success: %d, Skipped: %d, Errors: %d)\n', ...
    n_jobs, n_success, n_skipped, n_error);
fprintf('\nRun analysis_viewer.m to explore results interactively.\n');

%% ==================== PROGRESS UPDATE FUNCTION ====================
function update_progress(data, n_jobs)
    % Called each time a worker completes a job
    persistent count;
    if isempty(count)
        count = 0;
    end
    count = count + 1;

    % Status indicator
    if contains(data.result, 'SUCCESS')
        status = 'OK';
    elseif contains(data.result, 'SKIPPED')
        status = 'SKIP';
    else
        status = 'ERR';
    end

    fprintf('[%3d/%3d] %s | %s f=%.4f | %s\n', ...
        count, n_jobs, datestr(now, 'HH:MM:SS'), data.exp, data.freq, status);
end

%% ==================== SINGLE ANALYSIS FUNCTION ====================
function result = run_single_analysis(job, base_path, output_base, opts, params)
    % Run all analyses for a single experiment/frequency combination
    % Returns a log string for this job

    exp = job.exp;
    freq = job.freq;
    exp_name = exp.name;

    % Build paths
    sim_name = sprintf(exp.fmt, freq);
    sim_path = fullfile(base_path, exp.folder, 'simulations', sim_name);
    plist_path = fullfile(sim_path, 'plist.mat');
    params_path = fullfile(sim_path, 'sim_params.mat');

    freq_str = sprintf('f%.4f', freq);
    freq_output = fullfile(output_base, exp_name, freq_str);

    % Check if simulation exists
    if ~exist(plist_path, 'file')
        result = 'SKIPPED (not found)';
        return;
    end

    try
        % Load data
        [xyz, sim_params] = load_simulation_data(plist_path, params_path, opts, params);

        if isempty(xyz)
            result = 'SKIPPED (load failed)';
            return;
        end

        [N_particles, ~, N_frames] = size(xyz);

        % Prepare analysis context
        ctx = struct();
        ctx.xyz = xyz;
        ctx.freq = freq;
        ctx.exp_name = exp_name;
        ctx.is_top_driven = exp.top_driven;
        ctx.output_folder = freq_output;
        ctx.params = params;
        ctx.sim_params = sim_params;
        ctx.opts = opts;
        ctx.N_particles = N_particles;
        ctx.N_frames = N_frames;

        % Compute equilibrium positions
        n_eq = min(10, N_frames);
        ctx.x0 = mean(squeeze(xyz(:,1,1:n_eq)), 2);
        ctx.y0 = mean(squeeze(xyz(:,2,1:n_eq)), 2);
        ctx.z0 = mean(squeeze(xyz(:,3,1:n_eq)), 2);

        % Determine primary axis
        if ctx.is_top_driven
            ctx.primary_axis = 'Y';
            ctx.axis_len = sim_params.height;
        else
            ctx.primary_axis = 'X';
            ctx.axis_len = sim_params.width;
        end

        % ========== RUN ALL ANALYSES ==========
        run_bode_analysis(ctx);
        run_fourier_analysis(ctx);
        run_penetration_analysis(ctx);
        run_resonance_analysis(ctx);
        run_anisotropy_analysis(ctx);
        run_momentum_analysis(ctx);
        run_decomposition_analysis(ctx);
        run_vacf_analysis(ctx);
        run_msd_analysis(ctx);
        run_correlation_analysis(ctx);

        result = 'SUCCESS';

    catch ME
        result = sprintf('ERROR - %s', ME.message);
    end

    % Close all figures to free memory (important for parfor)
    close all;
end

%% ==================== ANALYSIS FUNCTIONS ====================

function [xyz, sim_params] = load_simulation_data(plist_path, params_path, opts, phys_params)
    % Load simulation data from plist.mat and sim_params.mat
    xyz = [];
    sim_params = struct('width', 500, 'height', 300);

    try
        % Load particle list
        loaded = load(plist_path);
        if isfield(loaded, 'plist')
            plist = loaded.plist;
        else
            fn = fieldnames(loaded);
            plist = loaded.(fn{1});
        end

        % Load simulation parameters if available
        if exist(params_path, 'file')
            p = load(params_path);
            if isfield(p, 'params')
                sim_params = p.params;
            elseif isfield(p, 'sim_params')
                sim_params = p.sim_params;
            else
                fn = fieldnames(p);
                sim_params = p.(fn{1});
            end
        end

        % Convert plist to xyz format
        xyz = plist2xyz_ranged(plist, opts.frame_range(1), opts.frame_range(2));

        % Unwrap periodic boundaries
        if ~isempty(xyz)
            xyz = unwrap_periodic(xyz, phys_params.box_size);
        end

    catch ME
        warning('Failed to load data: %s', ME.message);
    end
end

function run_bode_analysis(ctx)
    % Compute Bode plot (amplitude and phase vs position)

    xyz = ctx.xyz;
    x0 = ctx.x0; y0 = ctx.y0;
    N_frames = ctx.N_frames;
    n_bins = ctx.opts.n_bins_spatial;
    axis_len = ctx.axis_len;

    % Extract displacements
    if ctx.is_top_driven
        pos0 = y0;
        disp = squeeze(xyz(:,2,:)) - y0;
    else
        pos0 = x0;
        disp = squeeze(xyz(:,1,:)) - x0;
    end

    % Bin particles by position
    edges = linspace(0, axis_len, n_bins+1);
    ctrs = (edges(1:end-1) + edges(2:end)) / 2;
    bin_idx = discretize(pos0, edges);

    % Compute amplitude and phase for each bin
    amplitudes = zeros(n_bins, 1);
    phases = zeros(n_bins, 1);

    for b = 1:n_bins
        mask = (bin_idx == b);
        if sum(mask) < 3
            continue;
        end

        % Average displacement in this bin over time
        bin_disp = mean(disp(mask, :), 1);

        % FFT to find amplitude and phase at driving frequency
        Y = fft(bin_disp);

        % Find peak near driving frequency
        fs = 1;  % Assuming frame rate = 1
        f_axis = (0:N_frames-1) * fs / N_frames;
        [~, drive_idx] = min(abs(f_axis - ctx.freq));

        amplitudes(b) = abs(Y(drive_idx)) * 2 / N_frames;
        phases(b) = angle(Y(drive_idx));
    end

    % Unwrap phase
    phases = unwrap(phases);

    % Create figure
    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    plot(ctrs, amplitudes, 'b-', 'LineWidth', 2);
    xlabel(sprintf('%s Position (px)', ctx.primary_axis));
    ylabel('Amplitude (px)');
    title(sprintf('Bode Amplitude - %s f=%.4f', ctx.exp_name, ctx.freq));
    grid on;

    subplot(1,2,2);
    plot(ctrs, phases, 'r-', 'LineWidth', 2);
    xlabel(sprintf('%s Position (px)', ctx.primary_axis));
    ylabel('Phase (rad)');
    title('Bode Phase');
    grid on;

    % Save
    save_plot(fig, ctx.output_folder, 'bode', ctx.opts);

    % Save data
    if ctx.opts.save_mat
        bode_data = struct('ctrs', ctrs, 'amplitudes', amplitudes, 'phases', phases);
        save(fullfile(ctx.output_folder, 'bode_data.mat'), 'bode_data');
    end

    close(fig);
end

function run_fourier_analysis(ctx)
    % Temporal Fourier analysis of displacements

    xyz = ctx.xyz;
    x0 = ctx.x0; y0 = ctx.y0; z0 = ctx.z0;
    N_frames = ctx.N_frames;

    % Compute displacements
    ux = squeeze(xyz(:,1,:)) - x0;
    uy = squeeze(xyz(:,2,:)) - y0;
    uz = squeeze(xyz(:,3,:)) - z0;

    % Remove COM drift
    ux = ux - mean(ux, 1);
    uy = uy - mean(uy, 1);
    uz = uz - mean(uz, 1);

    % Apply window (window should be row vector to broadcast with [N_particles x N_frames])
    window = hann_window(N_frames);  % Row vector [1 x N_frames]
    Ux = fft(ux .* window, [], 2);
    Uy = fft(uy .* window, [], 2);
    Uz = fft(uz .* window, [], 2);

    % Power spectra
    Px = sum(abs(Ux).^2, 1) / N_frames;
    Py = sum(abs(Uy).^2, 1) / N_frames;
    Pz = sum(abs(Uz).^2, 1) / N_frames;
    P_total = Px + Py + Pz;

    % Frequency axis
    f = (0:N_frames-1) / N_frames;
    n_pos = floor(N_frames/2) + 1;
    f_pos = f(1:n_pos);

    % Create figure
    fig = figure('Position', [100 100 1200 400], 'Visible', 'off');

    subplot(1,3,1);
    semilogy(f_pos, P_total(1:n_pos), 'k-', 'LineWidth', 1.5);
    hold on;
    xline(ctx.freq, 'r--', 'LineWidth', 1.5);
    xlabel('Frequency (1/frame)');
    ylabel('Power Spectral Density');
    title(sprintf('Total Power Spectrum - %s f=%.4f', ctx.exp_name, ctx.freq));
    xlim([0 0.15]);
    grid on;

    subplot(1,3,2);
    semilogy(f_pos, Px(1:n_pos), 'r-', 'LineWidth', 1.5, 'DisplayName', 'X');
    hold on;
    semilogy(f_pos, Py(1:n_pos), 'b-', 'LineWidth', 1.5, 'DisplayName', 'Y');
    semilogy(f_pos, Pz(1:n_pos), 'g-', 'LineWidth', 1.5, 'DisplayName', 'Z');
    xlabel('Frequency');
    ylabel('Power');
    title('Component Spectra');
    legend('Location', 'northeast');
    xlim([0 0.15]);
    grid on;

    subplot(1,3,3);
    % Participation ratio (mode localization)
    participation = zeros(1, n_pos);
    for iw = 1:n_pos
        amp = abs(Ux(:,iw)).^2 + abs(Uy(:,iw)).^2 + abs(Uz(:,iw)).^2;
        amp_norm = amp / (sum(amp) + eps);
        participation(iw) = 1 / (ctx.N_particles * sum(amp_norm.^2) + eps);
    end
    plot(f_pos, participation, 'm-', 'LineWidth', 1.5);
    xlabel('Frequency');
    ylabel('Participation Ratio');
    title('Mode Localization (1=extended, 0=localized)');
    ylim([0 1]);
    xlim([0 0.15]);
    grid on;

    save_plot(fig, ctx.output_folder, 'fourier', ctx.opts);

    if ctx.opts.save_mat
        fourier_data = struct('f', f_pos, 'P_total', P_total(1:n_pos), ...
            'Px', Px(1:n_pos), 'Py', Py(1:n_pos), 'Pz', Pz(1:n_pos), ...
            'participation', participation);
        save(fullfile(ctx.output_folder, 'fourier_data.mat'), 'fourier_data');
    end

    close(fig);
end

function run_penetration_analysis(ctx)
    % Analyze penetration depth (decay of amplitude with distance from drive)

    xyz = ctx.xyz;
    x0 = ctx.x0; y0 = ctx.y0;
    N_frames = ctx.N_frames;
    n_bins = ctx.opts.n_bins_spatial;
    axis_len = ctx.axis_len;

    % Get displacement
    if ctx.is_top_driven
        pos0 = y0;
        disp = squeeze(xyz(:,2,:)) - y0;
    else
        pos0 = x0;
        disp = squeeze(xyz(:,1,:)) - x0;
    end

    % Bin particles
    edges = linspace(0, axis_len, n_bins+1);
    ctrs = (edges(1:end-1) + edges(2:end)) / 2;
    bin_idx = discretize(pos0, edges);

    % Compute RMS amplitude for each bin
    rms_amp = zeros(n_bins, 1);
    for b = 1:n_bins
        mask = (bin_idx == b);
        if sum(mask) < 3
            continue;
        end
        bin_disp = disp(mask, :);
        rms_amp(b) = sqrt(mean(bin_disp(:).^2));
    end

    % Fit exponential decay
    valid = rms_amp > 0;
    if sum(valid) > 5
        try
            % Log-linear fit for exponential decay
            log_amp = log(rms_amp(valid) + eps);
            p = polyfit(ctrs(valid), log_amp, 1);
            decay_rate = -p(1);
            penetration_depth = 1 / (decay_rate + eps);
            fit_amp = exp(polyval(p, ctrs));
        catch
            penetration_depth = NaN;
            fit_amp = nan(size(ctrs));
        end
    else
        penetration_depth = NaN;
        fit_amp = nan(size(ctrs));
    end

    % Create figure
    fig = figure('Position', [100 100 800 400], 'Visible', 'off');

    subplot(1,2,1);
    plot(ctrs, rms_amp, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 4);
    hold on;
    if ~isnan(penetration_depth)
        plot(ctrs, fit_amp, 'r--', 'LineWidth', 2);
    end
    xlabel(sprintf('%s Position (px)', ctx.primary_axis));
    ylabel('RMS Amplitude (px)');
    title(sprintf('Amplitude Decay - %s f=%.4f', ctx.exp_name, ctx.freq));
    legend('Data', sprintf('Fit: \\delta = %.1f px', penetration_depth), 'Location', 'northeast');
    grid on;

    subplot(1,2,2);
    semilogy(ctrs, rms_amp, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 4);
    hold on;
    if ~isnan(penetration_depth)
        semilogy(ctrs, fit_amp, 'r--', 'LineWidth', 2);
    end
    xlabel(sprintf('%s Position (px)', ctx.primary_axis));
    ylabel('RMS Amplitude (log scale)');
    title(sprintf('Penetration Depth: %.1f px', penetration_depth));
    grid on;

    save_plot(fig, ctx.output_folder, 'penetration', ctx.opts);

    if ctx.opts.save_mat
        pen_data = struct('ctrs', ctrs, 'rms_amp', rms_amp, ...
            'penetration_depth', penetration_depth, 'fit_amp', fit_amp);
        save(fullfile(ctx.output_folder, 'penetration_data.mat'), 'pen_data');
    end

    close(fig);
end

function run_resonance_analysis(ctx)
    % Detect resonant frequencies and estimate Q-factors

    xyz = ctx.xyz;
    x0 = ctx.x0; y0 = ctx.y0; z0 = ctx.z0;
    N_frames = ctx.N_frames;

    % Compute total power spectrum
    ux = squeeze(xyz(:,1,:)) - x0;
    uy = squeeze(xyz(:,2,:)) - y0;
    uz = squeeze(xyz(:,3,:)) - z0;

    ux = ux - mean(ux, 1);
    uy = uy - mean(uy, 1);
    uz = uz - mean(uz, 1);

    window = hann_window(N_frames);  % Row vector for broadcasting
    Ux = fft(ux .* window, [], 2);
    Uy = fft(uy .* window, [], 2);
    Uz = fft(uz .* window, [], 2);

    P_total = sum(abs(Ux).^2 + abs(Uy).^2 + abs(Uz).^2, 1) / N_frames;

    f = (0:N_frames-1) / N_frames;
    n_pos = floor(N_frames/2) + 1;
    f_pos = f(1:n_pos);
    P_pos = P_total(1:n_pos);

    % Find peaks
    [peaks, locs] = findpeaks(P_pos, 'MinPeakProminence', max(P_pos)*0.01, ...
        'SortStr', 'descend');

    % Estimate Q-factors for top peaks
    n_peaks = min(5, length(peaks));
    peak_freqs = f_pos(locs(1:n_peaks));
    peak_powers = peaks(1:n_peaks);
    q_factors = zeros(n_peaks, 1);

    for i = 1:n_peaks
        % Find half-power width
        half_power = peak_powers(i) / 2;
        loc = locs(i);

        % Find left half-power point
        left_idx = find(P_pos(1:loc) < half_power, 1, 'last');
        if isempty(left_idx), left_idx = 1; end

        % Find right half-power point
        right_idx = find(P_pos(loc:end) < half_power, 1, 'first') + loc - 1;
        if isempty(right_idx), right_idx = n_pos; end

        width = f_pos(right_idx) - f_pos(left_idx);
        q_factors(i) = peak_freqs(i) / (width + eps);
    end

    % Create figure
    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    semilogy(f_pos, P_pos, 'b-', 'LineWidth', 1.5);
    hold on;
    semilogy(peak_freqs, peak_powers, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
    xline(ctx.freq, 'g--', 'LineWidth', 1.5);
    xlabel('Frequency (1/frame)');
    ylabel('Power');
    title(sprintf('Resonance Detection - %s f=%.4f', ctx.exp_name, ctx.freq));
    xlim([0 0.15]);
    grid on;

    subplot(1,2,2);
    if n_peaks > 0
        bar(1:n_peaks, q_factors);
        xticks(1:n_peaks);
        xticklabels(arrayfun(@(x) sprintf('%.4f', x), peak_freqs, 'UniformOutput', false));
        xlabel('Peak Frequency');
        ylabel('Q-Factor');
        title('Quality Factors');
        grid on;
    else
        text(0.5, 0.5, 'No peaks detected', 'HorizontalAlignment', 'center');
    end

    save_plot(fig, ctx.output_folder, 'resonance', ctx.opts);

    if ctx.opts.save_mat
        res_data = struct('f', f_pos, 'P', P_pos, 'peak_freqs', peak_freqs, ...
            'peak_powers', peak_powers, 'q_factors', q_factors);
        save(fullfile(ctx.output_folder, 'resonance_data.mat'), 'res_data');
    end

    close(fig);
end

function run_anisotropy_analysis(ctx)
    % Analyze directional anisotropy of response

    xyz = ctx.xyz;
    x0 = ctx.x0; y0 = ctx.y0;

    % Compute displacements
    ux = squeeze(xyz(:,1,:)) - x0;
    uy = squeeze(xyz(:,2,:)) - y0;

    % RMS displacements
    rms_x = sqrt(mean(ux(:).^2));
    rms_y = sqrt(mean(uy(:).^2));
    anisotropy_ratio = rms_x / (rms_y + eps);

    % Displacement distribution
    all_ux = ux(:);
    all_uy = uy(:);

    % Create figure
    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,3,1);
    histogram(all_ux, 50, 'FaceColor', 'r', 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    hold on;
    histogram(all_uy, 50, 'FaceColor', 'b', 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    xlabel('Displacement (px)');
    ylabel('Count');
    title(sprintf('Displacement Distribution - %s', ctx.exp_name));
    legend(sprintf('X (RMS=%.3f)', rms_x), sprintf('Y (RMS=%.3f)', rms_y));

    subplot(1,3,2);
    scatter(all_ux(1:100:end), all_uy(1:100:end), 1, 'k', 'filled', 'MarkerFaceAlpha', 0.3);
    xlabel('X Displacement');
    ylabel('Y Displacement');
    title(sprintf('X-Y Correlation (ratio=%.2f)', anisotropy_ratio));
    axis equal;
    grid on;

    subplot(1,3,3);
    % Directional power
    angles = atan2(all_uy, all_ux);
    polarhistogram(angles, 36, 'FaceColor', 'c');
    title('Displacement Direction');

    save_plot(fig, ctx.output_folder, 'anisotropy', ctx.opts);

    if ctx.opts.save_mat
        anis_data = struct('rms_x', rms_x, 'rms_y', rms_y, ...
            'anisotropy_ratio', anisotropy_ratio);
        save(fullfile(ctx.output_folder, 'anisotropy_data.mat'), 'anis_data');
    end

    close(fig);
end

function run_momentum_analysis(ctx)
    % Momentum space analysis (simplified dispersion)

    xyz = ctx.xyz;
    x0 = ctx.x0; y0 = ctx.y0;
    N_frames = ctx.N_frames;
    N_particles = ctx.N_particles;

    % Displacements
    ux = squeeze(xyz(:,1,:)) - x0;
    uy = squeeze(xyz(:,2,:)) - y0;
    ux = ux - mean(ux, 1);
    uy = uy - mean(uy, 1);

    % Temporal FFT
    window = hann_window(N_frames);  % Row vector for broadcasting
    Ux = fft(ux .* window, [], 2);
    Uy = fft(uy .* window, [], 2);

    % Frequency axis
    f = (0:N_frames-1) / N_frames;
    n_pos = floor(N_frames/2) + 1;
    f_pos = f(1:n_pos);

    % Simple k-space: use x-position as proxy for wavevector
    % Sort particles by x-position
    [~, sort_idx] = sort(x0);
    k_proxy = (1:N_particles)' / N_particles * 2 * pi;  % Normalized k

    % Build S(k, omega) using sorted positions
    Ux_sorted = Ux(sort_idx, :);
    Uy_sorted = Uy(sort_idx, :);

    % Compute spatial FFT along sorted particle direction
    n_k = 30;
    S_k_omega = zeros(n_k, n_pos);

    for iw = 1:n_pos
        % Spatial FFT of Fourier amplitudes
        Sk = fft(Ux_sorted(:, iw), n_k) + fft(Uy_sorted(:, iw), n_k);
        S_k_omega(:, iw) = abs(Sk).^2;
    end

    k_axis = (0:n_k-1) / n_k * 2 * pi;

    % Create figure
    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    imagesc(f_pos, k_axis, log10(S_k_omega + 1));
    xlabel('Frequency (1/frame)');
    ylabel('k (rad)');
    title(sprintf('S(k,\\omega) - %s f=%.4f', ctx.exp_name, ctx.freq));
    colorbar;
    axis xy;
    xlim([0 0.15]);

    subplot(1,2,2);
    % Integrated structure factor
    S_k = sum(S_k_omega, 2);
    plot(k_axis, S_k, 'b-', 'LineWidth', 1.5);
    xlabel('k (rad)');
    ylabel('S(k)');
    title('Integrated Structure Factor');
    grid on;

    save_plot(fig, ctx.output_folder, 'momentum', ctx.opts);

    if ctx.opts.save_mat
        mom_data = struct('k', k_axis, 'f', f_pos, 'S_k_omega', S_k_omega, 'S_k', S_k);
        save(fullfile(ctx.output_folder, 'momentum_data.mat'), 'mom_data');
    end

    close(fig);
end

function run_decomposition_analysis(ctx)
    % Resonant mode decomposition using SVD/PCA

    xyz = ctx.xyz;
    x0 = ctx.x0; y0 = ctx.y0;
    N_frames = ctx.N_frames;
    N_particles = ctx.N_particles;

    % Displacement matrix
    ux = squeeze(xyz(:,1,:)) - x0;
    uy = squeeze(xyz(:,2,:)) - y0;

    % Stack into displacement matrix [2*N_particles x N_frames]
    U = [ux; uy];
    U = U - mean(U, 2);  % Zero mean

    % SVD decomposition
    n_modes = min(20, min(size(U)));
    [modes, S, V] = svds(U, n_modes);

    singular_values = diag(S);
    explained_variance = singular_values.^2 / sum(singular_values.^2);
    cumulative_variance = cumsum(explained_variance);

    % Create figure
    fig = figure('Position', [100 100 1200 400], 'Visible', 'off');

    subplot(1,3,1);
    bar(explained_variance * 100);
    xlabel('Mode');
    ylabel('Variance Explained (%)');
    title(sprintf('Mode Decomposition - %s', ctx.exp_name));
    xlim([0.5 n_modes+0.5]);
    grid on;

    subplot(1,3,2);
    plot(cumulative_variance * 100, 'b-o', 'LineWidth', 1.5);
    xlabel('Number of Modes');
    ylabel('Cumulative Variance (%)');
    title('Cumulative Explained Variance');
    ylim([0 100]);
    grid on;

    subplot(1,3,3);
    % Show first mode shape
    mode1_x = modes(1:N_particles, 1);
    mode1_y = modes(N_particles+1:end, 1);
    scatter(x0, y0, 20, sqrt(mode1_x.^2 + mode1_y.^2), 'filled');
    colormap(hot);
    colorbar;
    axis equal;
    title('Mode 1 Amplitude');
    xlabel('X'); ylabel('Y');

    save_plot(fig, ctx.output_folder, 'decomposition', ctx.opts);

    if ctx.opts.save_mat
        decomp_data = struct('singular_values', singular_values, ...
            'explained_variance', explained_variance, ...
            'modes', modes, 'temporal', V);
        save(fullfile(ctx.output_folder, 'decomposition_data.mat'), 'decomp_data');
    end

    close(fig);
end

function run_vacf_analysis(ctx)
    % Velocity autocorrelation function and density of states

    xyz = ctx.xyz;
    N_frames = ctx.N_frames;

    % Compute velocities (finite difference)
    vx = diff(squeeze(xyz(:,1,:)), 1, 2);
    vy = diff(squeeze(xyz(:,2,:)), 1, 2);
    vz = diff(squeeze(xyz(:,3,:)), 1, 2);

    % VACF
    max_lag = min(500, floor(N_frames/2));
    vacf = zeros(max_lag+1, 1);

    for lag = 0:max_lag
        if lag == 0
            vacf(1) = mean(vx(:).^2 + vy(:).^2 + vz(:).^2);
        else
            v1 = [vx(:, 1:end-lag); vy(:, 1:end-lag); vz(:, 1:end-lag)];
            v2 = [vx(:, 1+lag:end); vy(:, 1+lag:end); vz(:, 1+lag:end)];
            vacf(lag+1) = mean(sum(v1 .* v2, 1));
        end
    end

    vacf_norm = vacf / vacf(1);
    t_lag = 0:max_lag;

    % DOS from Fourier transform of VACF
    vacf_padded = [vacf_norm; zeros(1024 - length(vacf_norm), 1)];
    dos = real(fft(vacf_padded));
    dos = dos(1:512);
    f_dos = (0:511) / 1024;

    % Create figure
    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    plot(t_lag, vacf_norm, 'b-', 'LineWidth', 1.5);
    xlabel('Lag (frames)');
    ylabel('VACF (normalized)');
    title(sprintf('Velocity Autocorrelation - %s', ctx.exp_name));
    grid on;

    subplot(1,2,2);
    plot(f_dos, dos, 'r-', 'LineWidth', 1.5);
    xlabel('Frequency');
    ylabel('DOS');
    title('Density of States (from VACF)');
    xlim([0 0.2]);
    grid on;

    save_plot(fig, ctx.output_folder, 'vacf_dos', ctx.opts);

    if ctx.opts.save_mat
        vacf_data = struct('t_lag', t_lag, 'vacf', vacf_norm, 'f_dos', f_dos, 'dos', dos);
        save(fullfile(ctx.output_folder, 'vacf_data.mat'), 'vacf_data');
    end

    close(fig);
end

function run_msd_analysis(ctx)
    % Mean squared displacement analysis

    xyz = ctx.xyz;
    x0 = ctx.x0; y0 = ctx.y0;
    N_frames = ctx.N_frames;

    % Displacement from initial position (not equilibrium)
    x = squeeze(xyz(:,1,:));
    y = squeeze(xyz(:,2,:));

    max_lag = min(500, floor(N_frames/2));
    msd = zeros(max_lag+1, 1);

    for lag = 0:max_lag
        dx = x(:, 1+lag:end) - x(:, 1:end-lag);
        dy = y(:, 1+lag:end) - y(:, 1:end-lag);
        msd(lag+1) = mean(dx(:).^2 + dy(:).^2);
    end

    t_lag = 0:max_lag;

    % Fit to determine diffusion vs subdiffusion
    % MSD ~ t^alpha, alpha=1 for diffusion, <1 for subdiffusion, >1 for superdiffusion
    valid = t_lag > 5 & t_lag < max_lag/2;
    if sum(valid) > 10
        p = polyfit(log(t_lag(valid)), log(msd(valid)+eps), 1);
        alpha = p(1);
        fit_msd = exp(polyval(p, log(t_lag+1)));
    else
        alpha = NaN;
        fit_msd = nan(size(t_lag));
    end

    % Create figure
    fig = figure('Position', [100 100 800 400], 'Visible', 'off');

    subplot(1,2,1);
    plot(t_lag, msd, 'b-', 'LineWidth', 1.5);
    xlabel('Lag (frames)');
    ylabel('MSD (px^2)');
    title(sprintf('Mean Squared Displacement - %s', ctx.exp_name));
    grid on;

    subplot(1,2,2);
    loglog(t_lag+1, msd, 'b-', 'LineWidth', 1.5);
    hold on;
    if ~isnan(alpha)
        loglog(t_lag+1, fit_msd, 'r--', 'LineWidth', 1.5);
    end
    xlabel('Lag (frames)');
    ylabel('MSD (px^2)');
    title(sprintf('Log-Log MSD (\\alpha = %.2f)', alpha));
    legend('Data', sprintf('Fit: t^{%.2f}', alpha), 'Location', 'northwest');
    grid on;

    save_plot(fig, ctx.output_folder, 'msd', ctx.opts);

    if ctx.opts.save_mat
        msd_data = struct('t_lag', t_lag, 'msd', msd, 'alpha', alpha);
        save(fullfile(ctx.output_folder, 'msd_data.mat'), 'msd_data');
    end

    close(fig);
end

function run_correlation_analysis(ctx)
    % Spatial and temporal correlation functions

    xyz = ctx.xyz;
    x0 = ctx.x0; y0 = ctx.y0;
    N_particles = ctx.N_particles;

    % Use middle frame for spatial correlation
    mid_frame = round(ctx.N_frames / 2);
    ux = xyz(:,1,mid_frame) - x0;
    uy = xyz(:,2,mid_frame) - y0;

    % Compute pairwise distances and displacement correlations
    n_bins = 30;
    max_r = ctx.axis_len / 2;
    r_edges = linspace(0, max_r, n_bins+1);
    r_ctrs = (r_edges(1:end-1) + r_edges(2:end)) / 2;

    corr_xx = zeros(n_bins, 1);
    corr_yy = zeros(n_bins, 1);
    counts = zeros(n_bins, 1);

    % Sample pairs (for speed)
    n_sample = min(1000, N_particles);
    sample_idx = randperm(N_particles, n_sample);

    for i = 1:n_sample
        pi = sample_idx(i);
        for j = i+1:n_sample
            pj = sample_idx(j);

            r = sqrt((x0(pi)-x0(pj))^2 + (y0(pi)-y0(pj))^2);
            bin = discretize(r, r_edges);

            if ~isnan(bin)
                corr_xx(bin) = corr_xx(bin) + ux(pi)*ux(pj);
                corr_yy(bin) = corr_yy(bin) + uy(pi)*uy(pj);
                counts(bin) = counts(bin) + 1;
            end
        end
    end

    valid = counts > 0;
    corr_xx(valid) = corr_xx(valid) ./ counts(valid);
    corr_yy(valid) = corr_yy(valid) ./ counts(valid);

    % Create figure
    fig = figure('Position', [100 100 800 400], 'Visible', 'off');

    subplot(1,2,1);
    plot(r_ctrs, corr_xx, 'r-', 'LineWidth', 1.5, 'DisplayName', 'C_{xx}');
    hold on;
    plot(r_ctrs, corr_yy, 'b-', 'LineWidth', 1.5, 'DisplayName', 'C_{yy}');
    xlabel('Distance (px)');
    ylabel('Correlation');
    title(sprintf('Spatial Correlation - %s', ctx.exp_name));
    legend('Location', 'northeast');
    grid on;

    subplot(1,2,2);
    plot(r_ctrs, corr_xx + corr_yy, 'k-', 'LineWidth', 1.5);
    xlabel('Distance (px)');
    ylabel('Total Correlation');
    title('Total Displacement Correlation');
    grid on;

    save_plot(fig, ctx.output_folder, 'correlation', ctx.opts);

    if ctx.opts.save_mat
        corr_data = struct('r', r_ctrs, 'corr_xx', corr_xx, 'corr_yy', corr_yy);
        save(fullfile(ctx.output_folder, 'correlation_data.mat'), 'corr_data');
    end

    close(fig);
end

%% ==================== SUMMARY GENERATORS ====================

function generate_bode_summary(exp_output, exp_name, frequencies, opts)
    % Generate Bode plot summary across all frequencies

    all_freqs = [];
    all_amps = [];
    all_phases = [];

    for i = 1:length(frequencies)
        freq = frequencies(i);
        freq_str = sprintf('f%.4f', freq);
        data_path = fullfile(exp_output, freq_str, 'bode_data.mat');

        if exist(data_path, 'file')
            d = load(data_path);
            all_freqs(end+1) = freq;
            % Use amplitude at 1/4 distance from drive (representative)
            idx = round(length(d.bode_data.amplitudes) / 4);
            all_amps(end+1) = d.bode_data.amplitudes(idx);
            all_phases(end+1) = d.bode_data.phases(idx);
        end
    end

    if isempty(all_freqs)
        return;
    end

    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    semilogx(all_freqs, 20*log10(all_amps + eps), 'bo-', 'LineWidth', 1.5, 'MarkerSize', 8);
    xlabel('Driving Frequency');
    ylabel('Amplitude (dB)');
    title(sprintf('Bode Amplitude - %s', exp_name));
    grid on;

    subplot(1,2,2);
    semilogx(all_freqs, unwrap(all_phases) * 180/pi, 'ro-', 'LineWidth', 1.5, 'MarkerSize', 8);
    xlabel('Driving Frequency');
    ylabel('Phase (degrees)');
    title('Bode Phase');
    grid on;

    save_plot(fig, exp_output, 'bode_summary', opts);
    close(fig);
end

function generate_penetration_summary(exp_output, exp_name, frequencies, opts)
    % Generate penetration depth vs frequency plot

    all_freqs = [];
    all_depths = [];

    for i = 1:length(frequencies)
        freq = frequencies(i);
        freq_str = sprintf('f%.4f', freq);
        data_path = fullfile(exp_output, freq_str, 'penetration_data.mat');

        if exist(data_path, 'file')
            d = load(data_path);
            if ~isnan(d.pen_data.penetration_depth) && d.pen_data.penetration_depth > 0
                all_freqs(end+1) = freq;
                all_depths(end+1) = d.pen_data.penetration_depth;
            end
        end
    end

    if isempty(all_freqs)
        return;
    end

    fig = figure('Position', [100 100 600 400], 'Visible', 'off');

    loglog(all_freqs, all_depths, 'go-', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    xlabel('Driving Frequency');
    ylabel('Penetration Depth (px)');
    title(sprintf('Penetration Depth vs Frequency - %s', exp_name));
    grid on;

    save_plot(fig, exp_output, 'penetration_summary', opts);
    close(fig);
end

function generate_resonance_summary(exp_output, exp_name, frequencies, opts)
    % Generate resonance summary plot

    all_drive_freqs = [];
    all_peak_freqs = [];
    all_q_factors = [];

    for i = 1:length(frequencies)
        freq = frequencies(i);
        freq_str = sprintf('f%.4f', freq);
        data_path = fullfile(exp_output, freq_str, 'resonance_data.mat');

        if exist(data_path, 'file')
            d = load(data_path);
            if ~isempty(d.res_data.peak_freqs)
                all_drive_freqs(end+1) = freq;
                all_peak_freqs(end+1) = d.res_data.peak_freqs(1);  % Dominant peak
                if ~isempty(d.res_data.q_factors)
                    all_q_factors(end+1) = d.res_data.q_factors(1);
                else
                    all_q_factors(end+1) = NaN;
                end
            end
        end
    end

    if isempty(all_drive_freqs)
        return;
    end

    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    loglog(all_drive_freqs, all_peak_freqs, 'mo-', 'LineWidth', 2, 'MarkerSize', 8);
    hold on;
    loglog(all_drive_freqs, all_drive_freqs, 'k--', 'LineWidth', 1);
    xlabel('Driving Frequency');
    ylabel('Peak Response Frequency');
    title(sprintf('Response vs Drive - %s', exp_name));
    legend('Peak Response', '1:1 Line', 'Location', 'northwest');
    grid on;

    subplot(1,2,2);
    valid_q = ~isnan(all_q_factors);
    if any(valid_q)
        semilogx(all_drive_freqs(valid_q), all_q_factors(valid_q), 'co-', 'LineWidth', 2, 'MarkerSize', 8);
        xlabel('Driving Frequency');
        ylabel('Q-Factor');
        title('Quality Factor vs Frequency');
        grid on;
    end

    save_plot(fig, exp_output, 'resonance_summary', opts);
    close(fig);
end

%% ==================== UTILITY FUNCTIONS ====================

function save_plot(fig, folder, name, opts)
    % Save figure as both .fig and .png
    if opts.save_fig
        savefig(fig, fullfile(folder, [name '.fig']));
    end
    if opts.save_png
        saveas(fig, fullfile(folder, [name '.png']));
    end
end

function xyz = plist2xyz_ranged(plist, start_pct, end_pct)
    % Convert plist to xyz format with frame range

    if isempty(plist)
        xyz = [];
        return;
    end

    frame_col = plist(:, end);
    unique_frames = unique(frame_col);
    n_frames_total = length(unique_frames);

    start_frame = max(1, round(start_pct/100 * n_frames_total));
    end_frame = min(n_frames_total, round(end_pct/100 * n_frames_total));

    frames_to_use = unique_frames(start_frame:end_frame);
    n_frames = length(frames_to_use);

    % Determine particle count from first frame
    first_frame_mask = (frame_col == unique_frames(1));
    n_particles = sum(first_frame_mask);

    xyz = zeros(n_particles, 3, n_frames);

    for f = 1:n_frames
        frame_mask = (frame_col == frames_to_use(f));
        frame_data = plist(frame_mask, :);

        if size(frame_data, 1) == n_particles
            xyz(:, 1, f) = frame_data(:, 1);  % X
            xyz(:, 2, f) = frame_data(:, 2);  % Y
            if size(frame_data, 2) >= 3
                xyz(:, 3, f) = frame_data(:, 3);  % Z
            end
        end
    end
end

function xyz = unwrap_periodic(xyz, box_size)
    % Unwrap periodic boundary crossings
    [N, ~, T] = size(xyz);

    for dim = 1:2
        L = box_size(dim);
        for t = 2:T
            delta = xyz(:, dim, t) - xyz(:, dim, t-1);
            jumps = round(delta / L);
            xyz(:, dim, t:end) = xyz(:, dim, t:end) - jumps * L;
        end
    end
end

function w = hann_window(N)
    % Hann window function
    n = 0:N-1;
    w = 0.5 * (1 - cos(2*pi*n / (N-1)));
end

function generate_analysis_documentation(output_base, experiments, frequencies)
    % Generate documentation for all analysis types

    doc_path = fullfile(output_base, 'analysis_methods.md');
    fid = fopen(doc_path, 'w');

    fprintf(fid, '# Phonon Analysis Documentation\n\n');
    fprintf(fid, 'Generated: %s\n\n', datestr(now));
    fprintf(fid, '---\n\n');

    % Overview
    fprintf(fid, '## Overview\n\n');
    fprintf(fid, 'This documentation describes the analysis methods used to characterize\n');
    fprintf(fid, 'phonon modes and mechanical response in colloidal crystal simulations.\n\n');
    fprintf(fid, 'Experiments analyzed:\n');
    for i = 1:length(experiments)
        fprintf(fid, '- **%s**: %s\n', experiments{i}.name, experiments{i}.desc);
    end
    fprintf(fid, '\nFrequencies: %.4f to %.4f (1/frame)\n\n', min(frequencies), max(frequencies));
    fprintf(fid, '---\n\n');

    % Analysis descriptions
    analyses = {
        struct('name', 'Bode Analysis', 'file', 'bode', ...
            'desc', 'Measures amplitude and phase of displacement response as a function of position from the drive.', ...
            'theory', 'For a linear viscoelastic system, the amplitude decays exponentially with distance, and the phase accumulates linearly, indicating wave propagation.', ...
            'interpret', 'Amplitude decay rate indicates energy dissipation. Phase slope gives the wavelength/wavevector.');

        struct('name', 'Fourier Analysis', 'file', 'fourier', ...
            'desc', 'Decomposes displacement time series into frequency components using FFT.', ...
            'theory', 'Peaks in the power spectrum correspond to resonant modes of the system. The driving frequency should appear prominently.', ...
            'interpret', 'Sharp peaks indicate coherent oscillations. Broad peaks suggest damped modes. Multiple peaks may indicate mode coupling.');

        struct('name', 'Penetration Depth', 'file', 'penetration', ...
            'desc', 'Measures how far mechanical disturbances propagate into the crystal before decaying.', ...
            'theory', 'In an overdamped system, penetration depth delta ~ sqrt(stiffness/damping) / omega. Higher frequencies penetrate less.', ...
            'interpret', 'Larger penetration depth means better mechanical transmission. Frequency dependence reveals material properties.');

        struct('name', 'Resonance Detection', 'file', 'resonance', ...
            'desc', 'Identifies resonant frequencies and estimates quality factors (Q) from peak widths.', ...
            'theory', 'Q = f_resonance / bandwidth. High Q means low damping, sharp resonances. Low Q means overdamped response.', ...
            'interpret', 'Q > 1 indicates underdamped oscillations. Multiple resonances suggest multi-mode behavior.');

        struct('name', 'Anisotropy Analysis', 'file', 'anisotropy', ...
            'desc', 'Compares mechanical response in different directions (X vs Y).', ...
            'theory', 'Isotropic materials have equal response in all directions. Anisotropy arises from lattice structure or defects.', ...
            'interpret', 'Ratio > 1 means stronger response in X direction. Angular distribution shows preferred directions.');

        struct('name', 'Momentum Space Analysis', 'file', 'momentum', ...
            'desc', 'Computes the dynamical structure factor S(k, omega) to reveal dispersion relations.', ...
            'theory', 'Phonon dispersion shows omega(k) relationship. Linear dispersion = acoustic modes. Flat bands = optical modes.', ...
            'interpret', 'Bright bands indicate phonon modes. Slope gives group velocity. Band gaps indicate forbidden frequencies.');

        struct('name', 'Resonant Decomposition', 'file', 'decomposition', ...
            'desc', 'Uses SVD/PCA to decompose motion into orthogonal modes ordered by variance.', ...
            'theory', 'Each mode captures a collective motion pattern. First modes capture most variance (dominant motion).', ...
            'interpret', 'Rapid variance decay means few dominant modes. Slow decay means complex, multi-scale dynamics.');

        struct('name', 'Velocity Autocorrelation & DOS', 'file', 'vacf_dos', ...
            'desc', 'Computes velocity autocorrelation function and derives density of states via Fourier transform.', ...
            'theory', 'VACF decay indicates memory timescale. DOS peaks correspond to phonon band edges.', ...
            'interpret', 'Oscillations in VACF indicate caged motion. DOS shape reflects system dimensionality and interactions.');

        struct('name', 'Mean Squared Displacement', 'file', 'msd', ...
            'desc', 'Measures how particle positions spread over time.', ...
            'theory', 'MSD ~ t^alpha. alpha=1: normal diffusion, alpha<1: subdiffusion (caged), alpha>1: superdiffusion.', ...
            'interpret', 'For driven systems, expect oscillatory MSD superimposed on drift. Alpha < 1 indicates confinement.');

        struct('name', 'Correlation Functions', 'file', 'correlation', ...
            'desc', 'Computes spatial correlations of displacements at different separations.', ...
            'theory', 'Correlation length indicates how far mechanical information propagates. Decay form reveals interaction range.', ...
            'interpret', 'Long correlation length means collective behavior. Short range means localized response.');
    };

    fprintf(fid, '## Analysis Methods\n\n');

    for i = 1:length(analyses)
        a = analyses{i};
        fprintf(fid, '### %d. %s\n\n', i, a.name);
        fprintf(fid, '**File prefix:** `%s`\n\n', a.file);
        fprintf(fid, '**Description:** %s\n\n', a.desc);
        fprintf(fid, '**Theory:** %s\n\n', a.theory);
        fprintf(fid, '**Interpretation:** %s\n\n', a.interpret);
        fprintf(fid, '---\n\n');
    end

    % File structure
    fprintf(fid, '## Output File Structure\n\n');
    fprintf(fid, '```\n');
    fprintf(fid, 'analysis_output/\n');
    fprintf(fid, '├── analysis_methods.md          # This documentation\n');
    fprintf(fid, '├── analysis_log.txt             # Processing log\n');
    fprintf(fid, '├── <experiment_name>/\n');
    fprintf(fid, '│   ├── bode_summary.png/fig     # Cross-frequency Bode plot\n');
    fprintf(fid, '│   ├── penetration_summary.png  # Penetration vs frequency\n');
    fprintf(fid, '│   ├── resonance_summary.png    # Resonance summary\n');
    fprintf(fid, '│   └── f<frequency>/\n');
    fprintf(fid, '│       ├── bode.png/fig         # Bode analysis\n');
    fprintf(fid, '│       ├── fourier.png/fig      # Fourier analysis\n');
    fprintf(fid, '│       ├── penetration.png/fig  # Penetration depth\n');
    fprintf(fid, '│       ├── resonance.png/fig    # Resonance detection\n');
    fprintf(fid, '│       ├── anisotropy.png/fig   # Anisotropy\n');
    fprintf(fid, '│       ├── momentum.png/fig     # Momentum space\n');
    fprintf(fid, '│       ├── decomposition.png/fig # Mode decomposition\n');
    fprintf(fid, '│       ├── vacf_dos.png/fig     # VACF and DOS\n');
    fprintf(fid, '│       ├── msd.png/fig          # Mean squared displacement\n');
    fprintf(fid, '│       ├── correlation.png/fig  # Correlation functions\n');
    fprintf(fid, '│       └── *_data.mat           # Raw data for each analysis\n');
    fprintf(fid, '```\n\n');

    fprintf(fid, '## Running the Analysis Viewer\n\n');
    fprintf(fid, 'To explore results interactively:\n\n');
    fprintf(fid, '```matlab\n');
    fprintf(fid, 'analysis_viewer\n');
    fprintf(fid, '```\n\n');
    fprintf(fid, 'The viewer provides:\n');
    fprintf(fid, '- File tree navigation on the left\n');
    fprintf(fid, '- Plot display in the center\n');
    fprintf(fid, '- Description panel on the right showing:\n');
    fprintf(fid, '  - How the plot was generated\n');
    fprintf(fid, '  - What to expect based on theory\n');
    fprintf(fid, '  - Full file path for copying\n');

    fclose(fid);
    fprintf('Documentation generated: %s\n', doc_path);
end
