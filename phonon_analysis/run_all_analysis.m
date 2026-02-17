%% run_all_analysis.m
% COMPREHENSIVE ANALYSIS SCRIPT
% Runs all analysis functions on completed simulation data
%
% Priority order (highest to lowest):
%   1. analyze_attenuation_length - Key for understanding energy dissipation
%   2. analyze_spatial_coherence - Measures wave quality across crystal
%   3. analyze_group_velocity - Energy propagation speed (dω/dk)
%   4. analyze_mode_coupling - X-motion to Z-spin coupling
%   5. analyze_particle_MSD - Driven vs thermal motion
%   6. analyze_local_strain - Strain tensor from displacements
%   7. compute_structure_factor - Full S(k,ω)
%   8. analyze_defect_scattering - Domain boundary interactions
%   9. analyze_energy_flux - Energy flow visualization
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% ==================== ADD PATHS ====================
addpath(genpath('Z:\Colloid Cru\Colloid Work Folder'));
addpath(genpath('Z:\Colloid Cru\Simulations'));
addpath(genpath('Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\phonon_analysis'));

%% ==================== CONFIGURATION ====================
base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
output_base = fullfile(base_path, 'comprehensive_analysis');

if ~exist(output_base, 'dir')
    mkdir(output_base);
end

% Domain types to analyze
domains = {'zigzag', 'stripe', 'random', 'topdriven'};
batch_folders = {'drivensinesims', 'stripesinesims', 'randomsinesims', 'topdrivensims'};

% Progress file
progress_file = fullfile(output_base, 'analysis_progress.txt');

%% ==================== ANALYSIS TASK LIST ====================
% Each task: {name, function_handle, priority}
analysis_tasks = {
    'Attenuation Length',     @run_attenuation_analysis,     1;
    'Spatial Coherence',      @run_coherence_analysis,       2;
    'Group Velocity',         @run_group_velocity_analysis,  3;
    'Mode Coupling (X-Z)',    @run_mode_coupling_analysis,   4;
    'Particle MSD',           @run_msd_analysis,             5;
    'Local Strain',           @run_strain_analysis,          6;
    'Structure Factor S(k,w)', @run_structure_factor,        7;
    'Defect Scattering',      @run_defect_analysis,          8;
    'Energy Flux',            @run_energy_flux_analysis,     9;
};

%% ==================== RUN ALL ANALYSIS ====================
fprintf('============================================\n');
fprintf('   COMPREHENSIVE PHONON ANALYSIS\n');
fprintf('============================================\n');
fprintf('Start time: %s\n', datestr(now));
fprintf('Output: %s\n\n', output_base);

% Initialize progress file
fid = fopen(progress_file, 'w');
fprintf(fid, 'COMPREHENSIVE ANALYSIS STARTED: %s\n\n', datestr(now));
fclose(fid);

for t = 1:size(analysis_tasks, 1)
    task_name = analysis_tasks{t, 1};
    task_func = analysis_tasks{t, 2};
    priority = analysis_tasks{t, 3};

    fprintf('--------------------------------------------\n');
    fprintf('[P%d] %s\n', priority, task_name);
    fprintf('--------------------------------------------\n');

    % Log start
    fid = fopen(progress_file, 'a');
    fprintf(fid, '[%s] Starting: %s (Priority %d)\n', datestr(now, 'HH:MM:SS'), task_name, priority);
    fclose(fid);

    try
        tic;
        task_func(base_path, output_base, domains, batch_folders);
        elapsed = toc;

        fprintf('  Completed in %.1f seconds\n\n', elapsed);

        fid = fopen(progress_file, 'a');
        fprintf(fid, '[%s] Completed: %s (%.1fs)\n', datestr(now, 'HH:MM:SS'), task_name, elapsed);
        fclose(fid);

    catch ME
        fprintf('  ERROR: %s\n\n', ME.message);

        fid = fopen(progress_file, 'a');
        fprintf(fid, '[%s] FAILED: %s - %s\n', datestr(now, 'HH:MM:SS'), task_name, ME.message);
        fclose(fid);
    end
end

fprintf('============================================\n');
fprintf('   ANALYSIS COMPLETE\n');
fprintf('============================================\n');
fprintf('End time: %s\n', datestr(now));
fprintf('Results in: %s\n', output_base);

fid = fopen(progress_file, 'a');
fprintf(fid, '\nANALYSIS COMPLETED: %s\n', datestr(now));
fclose(fid);

%% ==================== ANALYSIS FUNCTIONS ====================

function run_attenuation_analysis(base_path, output_base, domains, batch_folders)
    % Analyze amplitude decay with distance from drive
    fprintf('  Analyzing attenuation length...\n');
    output_dir = fullfile(output_base, 'attenuation');
    if ~exist(output_dir, 'dir'); mkdir(output_dir); end

    results = struct();

    for d = 1:length(domains)
        domain = domains{d};
        batch = batch_folders{d};
        batch_path = fullfile(base_path, batch, 'simulations');

        if ~exist(batch_path, 'dir'); continue; end

        [freqs, decay_lengths, amplitudes] = compute_attenuation(batch_path, domain);

        if ~isempty(freqs)
            results.(domain).frequencies = freqs;
            results.(domain).decay_lengths = decay_lengths;
            results.(domain).amplitudes = amplitudes;
        end
    end

    save(fullfile(output_dir, 'attenuation_results.mat'), 'results');
    plot_attenuation_comparison(results, output_dir);
end

function run_coherence_analysis(base_path, output_base, domains, batch_folders)
    % Measure spatial coherence of waves
    fprintf('  Analyzing spatial coherence...\n');
    output_dir = fullfile(output_base, 'coherence');
    if ~exist(output_dir, 'dir'); mkdir(output_dir); end

    results = struct();

    for d = 1:length(domains)
        domain = domains{d};
        batch = batch_folders{d};
        batch_path = fullfile(base_path, batch, 'simulations');

        if ~exist(batch_path, 'dir'); continue; end

        [freqs, coherence] = compute_spatial_coherence(batch_path, domain);

        if ~isempty(freqs)
            results.(domain).frequencies = freqs;
            results.(domain).coherence = coherence;
        end
    end

    save(fullfile(output_dir, 'coherence_results.mat'), 'results');
    plot_coherence_comparison(results, output_dir);
end

function run_group_velocity_analysis(base_path, output_base, domains, batch_folders)
    % Compute group velocity from dispersion relation
    fprintf('  Computing group velocity (dω/dk)...\n');
    output_dir = fullfile(output_base, 'group_velocity');
    if ~exist(output_dir, 'dir'); mkdir(output_dir); end

    results = struct();

    for d = 1:length(domains)
        domain = domains{d};

        % Load dispersion results if available
        disp_file = fullfile(base_path, batch_folders{d}, 'analysis', ...
            sprintf('dispersion_results_%s.mat', domain));

        if exist(disp_file, 'file')
            loaded = load(disp_file);
            disp_results = loaded.results;

            % Compute group velocity: v_g = dω/dk
            omega = disp_results.omega;
            k = disp_results.k;

            valid = ~isnan(k) & ~isnan(omega);
            if sum(valid) > 2
                k_valid = k(valid);
                omega_valid = omega(valid);
                [k_sorted, sort_idx] = sort(k_valid);
                omega_sorted = omega_valid(sort_idx);

                % Numerical derivative
                v_group = gradient(omega_sorted) ./ gradient(k_sorted);

                results.(domain).k = k_sorted;
                results.(domain).omega = omega_sorted;
                results.(domain).v_group = v_group;
                results.(domain).v_phase = omega_sorted ./ k_sorted;
            end
        end
    end

    save(fullfile(output_dir, 'group_velocity_results.mat'), 'results');
    plot_group_velocity(results, output_dir);
end

function run_mode_coupling_analysis(base_path, output_base, domains, batch_folders)
    % Analyze coupling between X displacement and Z spin
    fprintf('  Analyzing X-Z mode coupling...\n');
    output_dir = fullfile(output_base, 'mode_coupling');
    if ~exist(output_dir, 'dir'); mkdir(output_dir); end

    results = struct();

    for d = 1:length(domains)
        domain = domains{d};
        batch = batch_folders{d};
        batch_path = fullfile(base_path, batch, 'simulations');

        if ~exist(batch_path, 'dir'); continue; end

        [freqs, xz_correlation] = compute_mode_coupling(batch_path, domain);

        if ~isempty(freqs)
            results.(domain).frequencies = freqs;
            results.(domain).xz_correlation = xz_correlation;
        end
    end

    save(fullfile(output_dir, 'mode_coupling_results.mat'), 'results');
    plot_mode_coupling(results, output_dir);
end

function run_msd_analysis(base_path, output_base, domains, batch_folders)
    % Compute mean squared displacement
    fprintf('  Computing particle MSD...\n');
    output_dir = fullfile(output_base, 'msd');
    if ~exist(output_dir, 'dir'); mkdir(output_dir); end

    results = struct();

    for d = 1:length(domains)
        domain = domains{d};
        batch = batch_folders{d};
        batch_path = fullfile(base_path, batch, 'simulations');

        if ~exist(batch_path, 'dir'); continue; end

        [freqs, msd_values] = compute_msd(batch_path, domain);

        if ~isempty(freqs)
            results.(domain).frequencies = freqs;
            results.(domain).msd = msd_values;
        end
    end

    % Also analyze control (no drive)
    ctrl_path = fullfile(base_path, 'controlsims', 'simulations');
    if exist(ctrl_path, 'dir')
        [~, ctrl_msd] = compute_msd(ctrl_path, 'control');
        results.control_msd = ctrl_msd;
    end

    save(fullfile(output_dir, 'msd_results.mat'), 'results');
    plot_msd_comparison(results, output_dir);
end

function run_strain_analysis(base_path, output_base, domains, batch_folders)
    % Compute local strain from neighbor displacements
    fprintf('  Computing local strain tensor...\n');
    output_dir = fullfile(output_base, 'strain');
    if ~exist(output_dir, 'dir'); mkdir(output_dir); end

    % Placeholder - will implement detailed strain analysis
    fprintf('    [Strain analysis not yet fully implemented]\n');
end

function run_structure_factor(base_path, output_base, domains, batch_folders)
    % Compute dynamical structure factor S(k,ω)
    fprintf('  Computing structure factor S(k,ω)...\n');
    output_dir = fullfile(output_base, 'structure_factor');
    if ~exist(output_dir, 'dir'); mkdir(output_dir); end

    % Placeholder - computationally intensive
    fprintf('    [Structure factor calculation not yet fully implemented]\n');
end

function run_defect_analysis(base_path, output_base, domains, batch_folders)
    % Analyze wave scattering at domain boundaries
    fprintf('  Analyzing defect scattering...\n');
    output_dir = fullfile(output_base, 'defect_scattering');
    if ~exist(output_dir, 'dir'); mkdir(output_dir); end

    % Placeholder - requires defect identification
    fprintf('    [Defect scattering analysis not yet fully implemented]\n');
end

function run_energy_flux_analysis(base_path, output_base, domains, batch_folders)
    % Compute energy flux through crystal
    fprintf('  Computing energy flux...\n');
    output_dir = fullfile(output_base, 'energy_flux');
    if ~exist(output_dir, 'dir'); mkdir(output_dir); end

    % Placeholder
    fprintf('    [Energy flux analysis not yet fully implemented]\n');
end

%% ==================== HELPER FUNCTIONS ====================

function [freqs, decay_lengths, amplitudes] = compute_attenuation(batch_path, domain)
    freqs = [];
    decay_lengths = [];
    amplitudes = [];

    % Find simulations
    if strcmp(domain, 'topdriven')
        sim_dirs = dir(fullfile(batch_path, 'topdriven_f*'));
    else
        sim_dirs = dir(fullfile(batch_path, 'sinusoidal_f*'));
    end

    for i = 1:length(sim_dirs)
        plist_file = fullfile(batch_path, sim_dirs(i).name, 'plist.mat');
        params_file = fullfile(batch_path, sim_dirs(i).name, 'sim_params.mat');

        if ~exist(plist_file, 'file'); continue; end

        try
            % Extract frequency from folder name
            if strcmp(domain, 'topdriven')
                tokens = regexp(sim_dirs(i).name, 'topdriven_f([\d.]+)', 'tokens');
            else
                tokens = regexp(sim_dirs(i).name, 'sinusoidal_f([\d.]+)', 'tokens');
            end
            if isempty(tokens); continue; end
            f = str2double(tokens{1}{1});

            % Load data
            loaded = load(plist_file);
            plist = loaded.plist;

            params = load(params_file);
            width = params.sim_params.width;

            % Convert to xyz
            frames = unique(plist(:, 4));
            n_frames = length(frames);
            n_particles = sum(plist(:, 4) == frames(1));

            xyz = zeros(n_particles, 3, n_frames);
            for ff = 1:n_frames
                frame_mask = plist(:, 4) == frames(ff);
                xyz(:, :, ff) = plist(frame_mask, 1:3);
            end

            % Compute amplitude vs x position
            x0 = mean(xyz(:, 1, 1:min(10, n_frames)), 3);
            dx = xyz(:, 1, :) - x0;
            amp_per_particle = rms(dx, 3);

            % Bin by x
            n_bins = 20;
            bin_edges = linspace(50, width-50, n_bins+1);
            bin_centers = (bin_edges(1:end-1) + bin_edges(2:end)) / 2;
            amp_vs_x = zeros(n_bins, 1);

            for b = 1:n_bins
                in_bin = x0 >= bin_edges(b) & x0 < bin_edges(b+1);
                if sum(in_bin) > 0
                    amp_vs_x(b) = mean(amp_per_particle(in_bin));
                end
            end

            % Fit exponential decay
            valid = amp_vs_x > 0.01 * max(amp_vs_x);
            if sum(valid) > 3
                log_amp = log(amp_vs_x(valid));
                x_fit = bin_centers(valid)';
                p = polyfit(x_fit, log_amp, 1);
                decay_len = -1 / p(1);

                freqs(end+1) = f;
                decay_lengths(end+1) = decay_len;
                amplitudes(end+1) = exp(p(2));  % Amplitude at x=0
            end
        catch
            continue;
        end
    end

    [freqs, idx] = sort(freqs);
    decay_lengths = decay_lengths(idx);
    amplitudes = amplitudes(idx);
end

function [freqs, coherence] = compute_spatial_coherence(batch_path, domain)
    freqs = [];
    coherence = [];

    if strcmp(domain, 'topdriven')
        sim_dirs = dir(fullfile(batch_path, 'topdriven_f*'));
    else
        sim_dirs = dir(fullfile(batch_path, 'sinusoidal_f*'));
    end

    for i = 1:length(sim_dirs)
        plist_file = fullfile(batch_path, sim_dirs(i).name, 'plist.mat');

        if ~exist(plist_file, 'file'); continue; end

        try
            if strcmp(domain, 'topdriven')
                tokens = regexp(sim_dirs(i).name, 'topdriven_f([\d.]+)', 'tokens');
            else
                tokens = regexp(sim_dirs(i).name, 'sinusoidal_f([\d.]+)', 'tokens');
            end
            if isempty(tokens); continue; end
            f = str2double(tokens{1}{1});

            loaded = load(plist_file);
            plist = loaded.plist;

            frames = unique(plist(:, 4));
            n_frames = length(frames);
            n_particles = sum(plist(:, 4) == frames(1));

            xyz = zeros(n_particles, 3, n_frames);
            for ff = 1:n_frames
                frame_mask = plist(:, 4) == frames(ff);
                xyz(:, :, ff) = plist(frame_mask, 1:3);
            end

            % Coherence: correlation of x-displacement within vertical slices
            x0 = mean(xyz(:, 1, 1:min(10, n_frames)), 3);
            y0 = xyz(:, 2, 1);

            % Take a vertical slice in the middle
            mid_x = mean(x0);
            slice_width = 20;
            in_slice = abs(x0 - mid_x) < slice_width;

            if sum(in_slice) > 10
                dx_slice = squeeze(xyz(in_slice, 1, :)) - x0(in_slice);

                % Compute pairwise correlation
                n_slice = sum(in_slice);
                correlations = zeros(n_slice * (n_slice-1) / 2, 1);
                idx = 1;
                for p1 = 1:n_slice-1
                    for p2 = p1+1:n_slice
                        c = corrcoef(dx_slice(p1, :), dx_slice(p2, :));
                        correlations(idx) = c(1, 2);
                        idx = idx + 1;
                    end
                end

                freqs(end+1) = f;
                coherence(end+1) = mean(correlations);
            end
        catch
            continue;
        end
    end

    [freqs, idx] = sort(freqs);
    coherence = coherence(idx);
end

function [freqs, xz_corr] = compute_mode_coupling(batch_path, domain)
    freqs = [];
    xz_corr = [];

    if strcmp(domain, 'topdriven')
        sim_dirs = dir(fullfile(batch_path, 'topdriven_f*'));
    else
        sim_dirs = dir(fullfile(batch_path, 'sinusoidal_f*'));
    end

    for i = 1:length(sim_dirs)
        plist_file = fullfile(batch_path, sim_dirs(i).name, 'plist.mat');

        if ~exist(plist_file, 'file'); continue; end

        try
            if strcmp(domain, 'topdriven')
                tokens = regexp(sim_dirs(i).name, 'topdriven_f([\d.]+)', 'tokens');
            else
                tokens = regexp(sim_dirs(i).name, 'sinusoidal_f([\d.]+)', 'tokens');
            end
            if isempty(tokens); continue; end
            f = str2double(tokens{1}{1});

            loaded = load(plist_file);
            plist = loaded.plist;

            frames = unique(plist(:, 4));
            n_frames = length(frames);
            n_particles = sum(plist(:, 4) == frames(1));

            xyz = zeros(n_particles, 3, n_frames);
            for ff = 1:n_frames
                frame_mask = plist(:, 4) == frames(ff);
                xyz(:, :, ff) = plist(frame_mask, 1:3);
            end

            % Compute correlation between x displacement and z change
            x0 = mean(xyz(:, 1, 1:min(10, n_frames)), 3);
            z0 = mean(xyz(:, 3, 1:min(10, n_frames)), 3);

            dx = squeeze(xyz(:, 1, :)) - x0;
            dz = squeeze(xyz(:, 3, :)) - z0;

            % Average correlation across particles
            particle_corrs = zeros(n_particles, 1);
            for p = 1:n_particles
                c = corrcoef(dx(p, :), dz(p, :));
                particle_corrs(p) = c(1, 2);
            end

            freqs(end+1) = f;
            xz_corr(end+1) = mean(abs(particle_corrs));

        catch
            continue;
        end
    end

    [freqs, idx] = sort(freqs);
    xz_corr = xz_corr(idx);
end

function [freqs, msd_values] = compute_msd(batch_path, domain)
    freqs = [];
    msd_values = [];

    if strcmp(domain, 'topdriven')
        sim_dirs = dir(fullfile(batch_path, 'topdriven_f*'));
    elseif strcmp(domain, 'control')
        sim_dirs = dir(fullfile(batch_path, '*_nodrive_*'));
    else
        sim_dirs = dir(fullfile(batch_path, 'sinusoidal_f*'));
    end

    for i = 1:length(sim_dirs)
        plist_file = fullfile(batch_path, sim_dirs(i).name, 'plist.mat');

        if ~exist(plist_file, 'file'); continue; end

        try
            if strcmp(domain, 'control')
                f = 0;  % No frequency for control
            elseif strcmp(domain, 'topdriven')
                tokens = regexp(sim_dirs(i).name, 'topdriven_f([\d.]+)', 'tokens');
                if isempty(tokens); continue; end
                f = str2double(tokens{1}{1});
            else
                tokens = regexp(sim_dirs(i).name, 'sinusoidal_f([\d.]+)', 'tokens');
                if isempty(tokens); continue; end
                f = str2double(tokens{1}{1});
            end

            loaded = load(plist_file);
            plist = loaded.plist;

            frames = unique(plist(:, 4));
            n_frames = length(frames);
            n_particles = sum(plist(:, 4) == frames(1));

            xyz = zeros(n_particles, 3, n_frames);
            for ff = 1:n_frames
                frame_mask = plist(:, 4) == frames(ff);
                xyz(:, :, ff) = plist(frame_mask, 1:3);
            end

            % MSD: <(r(t) - r(0))^2>
            r0 = xyz(:, 1:2, 1);
            msd_per_frame = zeros(n_frames, 1);
            for ff = 1:n_frames
                dr = xyz(:, 1:2, ff) - r0;
                msd_per_frame(ff) = mean(sum(dr.^2, 2));
            end

            freqs(end+1) = f;
            msd_values(end+1) = mean(msd_per_frame);

        catch
            continue;
        end
    end

    [freqs, idx] = sort(freqs);
    msd_values = msd_values(idx);
end

%% ==================== PLOTTING FUNCTIONS ====================

function plot_attenuation_comparison(results, output_dir)
    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1, 2, 1);
    hold on;
    domains = fieldnames(results);
    colors = lines(length(domains));
    for i = 1:length(domains)
        d = domains{i};
        if isfield(results.(d), 'frequencies')
            plot(results.(d).frequencies, results.(d).decay_lengths, 'o-', ...
                'Color', colors(i,:), 'LineWidth', 2, 'DisplayName', upper(d));
        end
    end
    hold off;
    xlabel('Frequency');
    ylabel('Decay length (px)');
    title('Attenuation Length');
    legend('Location', 'best');
    set(gca, 'XScale', 'log');
    grid on;

    subplot(1, 2, 2);
    hold on;
    for i = 1:length(domains)
        d = domains{i};
        if isfield(results.(d), 'frequencies')
            plot(results.(d).frequencies, results.(d).amplitudes, 's-', ...
                'Color', colors(i,:), 'LineWidth', 2, 'DisplayName', upper(d));
        end
    end
    hold off;
    xlabel('Frequency');
    ylabel('Source amplitude (px)');
    title('Response Amplitude');
    legend('Location', 'best');
    set(gca, 'XScale', 'log', 'YScale', 'log');
    grid on;

    saveas(fig, fullfile(output_dir, 'attenuation_comparison.png'));
    close(fig);
end

function plot_coherence_comparison(results, output_dir)
    fig = figure('Position', [100 100 600 400], 'Visible', 'off');

    hold on;
    domains = fieldnames(results);
    colors = lines(length(domains));
    for i = 1:length(domains)
        d = domains{i};
        if isfield(results.(d), 'frequencies')
            plot(results.(d).frequencies, results.(d).coherence, 'o-', ...
                'Color', colors(i,:), 'LineWidth', 2, 'DisplayName', upper(d));
        end
    end
    hold off;
    xlabel('Frequency');
    ylabel('Spatial coherence');
    title('Wave Coherence Across Crystal');
    legend('Location', 'best');
    set(gca, 'XScale', 'log');
    ylim([0 1]);
    grid on;

    saveas(fig, fullfile(output_dir, 'coherence_comparison.png'));
    close(fig);
end

function plot_group_velocity(results, output_dir)
    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1, 2, 1);
    hold on;
    domains = fieldnames(results);
    colors = lines(length(domains));
    for i = 1:length(domains)
        d = domains{i};
        if isfield(results.(d), 'k')
            plot(results.(d).k, results.(d).v_group, 'o-', ...
                'Color', colors(i,:), 'LineWidth', 2, 'DisplayName', upper(d));
        end
    end
    hold off;
    xlabel('Wavevector k');
    ylabel('Group velocity v_g');
    title('Group Velocity (dω/dk)');
    legend('Location', 'best');
    grid on;

    subplot(1, 2, 2);
    hold on;
    for i = 1:length(domains)
        d = domains{i};
        if isfield(results.(d), 'k')
            plot(results.(d).k, results.(d).v_group ./ results.(d).v_phase, 's-', ...
                'Color', colors(i,:), 'LineWidth', 2, 'DisplayName', upper(d));
        end
    end
    hold off;
    xlabel('Wavevector k');
    ylabel('v_g / v_p');
    title('Group/Phase Velocity Ratio');
    legend('Location', 'best');
    yline(1, '--k');
    grid on;

    saveas(fig, fullfile(output_dir, 'group_velocity.png'));
    close(fig);
end

function plot_mode_coupling(results, output_dir)
    fig = figure('Position', [100 100 600 400], 'Visible', 'off');

    hold on;
    domains = fieldnames(results);
    colors = lines(length(domains));
    for i = 1:length(domains)
        d = domains{i};
        if isfield(results.(d), 'frequencies')
            plot(results.(d).frequencies, results.(d).xz_correlation, 'o-', ...
                'Color', colors(i,:), 'LineWidth', 2, 'DisplayName', upper(d));
        end
    end
    hold off;
    xlabel('Frequency');
    ylabel('|Correlation(dx, dz)|');
    title('X-Z Mode Coupling');
    legend('Location', 'best');
    set(gca, 'XScale', 'log');
    grid on;

    saveas(fig, fullfile(output_dir, 'mode_coupling.png'));
    close(fig);
end

function plot_msd_comparison(results, output_dir)
    fig = figure('Position', [100 100 600 400], 'Visible', 'off');

    hold on;
    domains = fieldnames(results);
    colors = lines(length(domains));
    for i = 1:length(domains)
        d = domains{i};
        if strcmp(d, 'control_msd')
            continue;
        end
        if isfield(results.(d), 'frequencies')
            plot(results.(d).frequencies, results.(d).msd, 'o-', ...
                'Color', colors(i,:), 'LineWidth', 2, 'DisplayName', upper(d));
        end
    end

    % Add control as horizontal line
    if isfield(results, 'control_msd') && ~isempty(results.control_msd)
        yline(results.control_msd, '--k', 'LineWidth', 2, 'DisplayName', 'Control (no drive)');
    end

    hold off;
    xlabel('Frequency');
    ylabel('Mean Squared Displacement (px^2)');
    title('Particle MSD vs Drive Frequency');
    legend('Location', 'best');
    set(gca, 'XScale', 'log');
    grid on;

    saveas(fig, fullfile(output_dir, 'msd_comparison.png'));
    close(fig);
end
