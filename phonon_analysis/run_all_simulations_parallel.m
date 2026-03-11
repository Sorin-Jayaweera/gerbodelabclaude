%% run_all_simulations_parallel.m
% PARALLEL SIMULATION RUNNER - Uses all CPU cores
%
% Runs multiple frequencies in parallel using parfor
% Each worker handles one frequency independently
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% ==================== CONFIGURATION ====================
paths = get_paths();

% Add required paths (for main session)
addpath(genpath(paths.colloid_work));
addpath(genpath(paths.simulations));
addpath(genpath(paths.phonon_analysis));

% Store paths for workers (parfor doesn't inherit addpath)
path_colloid_work = paths.colloid_work;
path_simulations = paths.simulations;
path_phonon_analysis = paths.phonon_analysis;

% Base path for all simulations
batch_base = paths.sims;

% Frequencies for all simulations
frequencies = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...
               0.001, 0.0012, 0.0015, 0.0018, ...
               0.002, 0.0025, 0.003, 0.004, 0.005, ...
               0.007, 0.01, 0.02, 0.05, 0.10];

% Common parameters
drive_amplitude = 2.0;
drive_width = 25;
fixed_width = 25;
num_frames = 20000;
data_saving_frequency = 2;
base_image_freq_low = 10;
base_image_freq_high = 2;
looseness = 1.06;
zmax = 0.45;

%% ==================== PARALLEL POOL SETUP ====================
num_cores = feature('numcores');
fprintf('Detected %d CPU cores\n', num_cores);

% Leave 2 cores free for system overhead to prevent crashes
num_workers = max(1, num_cores - 2);

% Batch size: restart pool after this many jobs to clear accumulated memory
jobs_per_batch = num_workers * 3;  % ~3 rounds per batch

% Disable image generation in parallel mode (generate later from plist)
generate_images_in_parallel = false;

%% ==================== SIMULATION CONFIGURATIONS ====================
% Each config: {batch_name, domain_style, name_fmt, drive_dir, width, height}
sim_configs = {
    % X-driven (side drive)
    'drivensinesims',   'zigzags',  'sinusoidal_f%.4f_a2.0',          'x', 800, 400;
    'stripesinesims',   'stripes',  'sinusoidal_f%.4f_a2.0_stripes',  'x', 800, 400;
    'randomsinesims',   'random',   'sinusoidal_f%.4f_a2.0_random',   'x', 800, 400;
    'frustsinesims',    'frust',    'frust_f%.4f_a2.0',               'x', 800, 400;

    % Y-driven (top drive)
    'topdrivensims',    'zigzags',  'topdriven_f%.4f_a2.0',           'y', 400, 800;
    'stripetopsims',    'stripes',  'stripetop_f%.4f_a2.0',           'y', 800, 400;
    'frusttopsims',     'frust',    'frusttop_f%.4f_a2.0',            'y', 400, 800;
};

%% ==================== CREATE FOLDER STRUCTURE ====================
if ~exist(batch_base, 'dir')
    mkdir(batch_base);
end

for c = 1:size(sim_configs, 1)
    batch_folder = fullfile(batch_base, sim_configs{c, 1});
    if ~exist(batch_folder, 'dir')
        mkdir(batch_folder);
    end
    sim_folder = fullfile(batch_folder, 'simulations');
    if ~exist(sim_folder, 'dir')
        mkdir(sim_folder);
    end
    analysis_folder = fullfile(batch_folder, 'analysis');
    if ~exist(analysis_folder, 'dir')
        mkdir(analysis_folder);
    end
end

%% ==================== BUILD JOB LIST ====================
% Create flat list of all jobs: {config_idx, frequency}
jobs = {};
for c = 1:size(sim_configs, 1)
    batch_name = sim_configs{c, 1};
    name_fmt = sim_configs{c, 3};
    simulations_folder = fullfile(batch_base, batch_name, 'simulations');

    for fi = 1:length(frequencies)
        f = frequencies(fi);
        sim_name = sprintf(name_fmt, f);
        sim_path = fullfile(simulations_folder, sim_name);

        % Only add if not already complete
        if ~exist(fullfile(sim_path, 'plist.mat'), 'file')
            jobs{end+1} = struct('config_idx', c, 'frequency', f);
        end
    end
end

total_jobs = length(jobs);
fprintf('\n==============================================\n');
fprintf('   PARALLEL SIMULATION RUN\n');
fprintf('==============================================\n');
fprintf('Total pending jobs: %d\n', total_jobs);
fprintf('Workers: %d\n', num_workers);
fprintf('Estimated batches: %d\n\n', ceil(total_jobs / num_workers));

if total_jobs == 0
    fprintf('All simulations already complete!\n');
    return;
end

%% ==================== PROGRESS FILE ====================
progress_file = fullfile(batch_base, 'parallel_progress.txt');
fid = fopen(progress_file, 'w');
fprintf(fid, 'PARALLEL RUN STARTED: %s\n', datestr(now));
fprintf(fid, 'Workers: %d\n', num_workers);
fprintf(fid, 'Total jobs: %d\n', total_jobs);
fprintf(fid, '==========================================\n\n');
fclose(fid);

%% ==================== RUN PARALLEL SIMULATIONS ====================
% Convert jobs cell to arrays for parfor
job_configs = zeros(total_jobs, 1);
job_freqs = zeros(total_jobs, 1);
for j = 1:total_jobs
    job_configs(j) = jobs{j}.config_idx;
    job_freqs(j) = jobs{j}.frequency;
end

% Pre-extract config data for parfor (avoid cell indexing in parfor)
config_batch_names = cell(size(sim_configs, 1), 1);
config_domain_styles = cell(size(sim_configs, 1), 1);
config_name_fmts = cell(size(sim_configs, 1), 1);
config_drive_dirs = cell(size(sim_configs, 1), 1);
config_widths = zeros(size(sim_configs, 1), 1);
config_heights = zeros(size(sim_configs, 1), 1);

for c = 1:size(sim_configs, 1)
    config_batch_names{c} = sim_configs{c, 1};
    config_domain_styles{c} = sim_configs{c, 2};
    config_name_fmts{c} = sim_configs{c, 3};
    config_drive_dirs{c} = sim_configs{c, 4};
    config_widths(c) = sim_configs{c, 5};
    config_heights(c) = sim_configs{c, 6};
end

% Results storage
results = cell(total_jobs, 1);

fprintf('Starting parallel execution...\n');
fprintf('Jobs per batch: %d (pool restarts between batches to clear memory)\n', jobs_per_batch);
tic;

% Process in batches with pool restart between batches
num_batches = ceil(total_jobs / jobs_per_batch);
for batch_idx = 1:num_batches
    batch_start = (batch_idx - 1) * jobs_per_batch + 1;
    batch_end = min(batch_idx * jobs_per_batch, total_jobs);
    batch_jobs = batch_start:batch_end;

    fprintf('\n--- BATCH %d/%d (jobs %d-%d) ---\n', batch_idx, num_batches, batch_start, batch_end);

    % Start/restart parallel pool for this batch
    pool = gcp('nocreate');
    if ~isempty(pool)
        delete(pool);
        pause(2);  % Let pool fully shut down
    end
    fprintf('Starting fresh parallel pool with %d workers...\n', num_workers);
    pool = parpool('local', num_workers);

    % Add paths to all workers BEFORE parfor (avoids transparency violation)
    parfevalOnAll(@addpath, 0, genpath(path_colloid_work));
    parfevalOnAll(@addpath, 0, genpath(path_simulations));
    parfevalOnAll(@addpath, 0, genpath(path_phonon_analysis));
    fprintf('Paths added to all workers.\n');

    % Run this batch
    batch_results = cell(length(batch_jobs), 1);

    parfor bi = 1:length(batch_jobs)
        j = batch_jobs(bi);
    c = job_configs(j);
    drive_frequency = job_freqs(j);

    % Get config for this job
    batch_name = config_batch_names{c};
    domain_style = config_domain_styles{c};
    name_fmt = config_name_fmts{c};
    drive_dir = config_drive_dirs{c};
    sim_width = config_widths(c);
    sim_height = config_heights(c);

    simulations_folder = fullfile(batch_base, batch_name, 'simulations');
    sim_name = sprintf(name_fmt, drive_frequency);
    sim_full_path = fullfile(simulations_folder, sim_name);

    frames_per_cycle = round(1 / drive_frequency);

    % Adaptive image saving
    if drive_frequency >= 0.02
        image_saving_frequency = base_image_freq_high;
    else
        image_saving_frequency = base_image_freq_low;
    end

    try
        % Paths already added via parfevalOnAll before parfor started

        fprintf('[Worker %d] Starting: %s f=%.4f\n', j, batch_name, drive_frequency);

        % Clean up partial runs
        if exist(sim_full_path, 'dir')
            rmdir(sim_full_path, 's');
        end
        mkdir(sim_full_path);

        %% Initialize simulation
        sim = TDsim();
        sim.width = sim_width;
        sim.height = sim_height;
        sim.looseness = looseness;
        sim.zmax = zmax;
        sim.data_saving_frequency = data_saving_frequency;
        sim.image_saving_frequency = image_saving_frequency;
        sim.num_frames = num_frames;

        % Initialize crystal with domain structure
        if strcmp(domain_style, 'frust')
            % initialize_grains_frust is a standalone function, not a method
            initialize_grains_frust(sim);
        else
            sim.initialize_grains_unfrust(domain_style);
        end

        num_particles = size(sim.initial_particles, 1);

        if strcmp(drive_dir, 'x')
            % X-driven: drive LEFT, fix RIGHT
            driven_indices = sim.initial_particles(:,1) < drive_width;
            equilibrium_drive = sim.initial_particles(driven_indices, 1);
            fixed_indices = sim.initial_particles(:,1) > (sim_width - fixed_width);
        else
            % Y-driven: drive TOP, fix BOTTOM
            driven_indices = sim.initial_particles(:,2) > (sim_height - drive_width);
            equilibrium_drive = sim.initial_particles(driven_indices, 2);
            fixed_indices = sim.initial_particles(:,2) < fixed_width;
        end

        fixed_equilibrium_x = sim.initial_particles(fixed_indices, 1);
        fixed_equilibrium_y = sim.initial_particles(fixed_indices, 2);

        % Initialize storage
        total_data_frames = floor(num_frames / data_saving_frequency);
        plist = zeros(num_particles * total_data_frames, 4);
        plist_row = 1;

        % Set initial positions
        particles = sim.initial_particles;
        sim.current_particles = particles;

        % Build neighbor list
        sim.neighbors = sim.getNeighbors(sim.cutoff_distance, 1, 8);
        particlesFromNeighborList = sim.current_particles;

        %% Run simulation
        sim_tic = tic;
        for frame = 1:num_frames
            % Apply sinusoidal drive
            drive_phase = drive_amplitude * sin(2 * pi * drive_frequency * frame);

            if strcmp(drive_dir, 'x')
                sim.current_particles(driven_indices, 1) = equilibrium_drive + drive_phase;
            else
                sim.current_particles(driven_indices, 2) = equilibrium_drive + drive_phase;
            end

            % Simulate frame
            sim.simulateFrame();

            % Re-enforce boundaries
            if strcmp(drive_dir, 'x')
                sim.current_particles(driven_indices, 1) = equilibrium_drive + drive_phase;
            else
                sim.current_particles(driven_indices, 2) = equilibrium_drive + drive_phase;
            end
            sim.current_particles(fixed_indices, 1) = fixed_equilibrium_x;
            sim.current_particles(fixed_indices, 2) = fixed_equilibrium_y;

            % Update neighbors if needed
            if any(sim.wraparoundDistancesTwoSets(sim.current_particles, particlesFromNeighborList) > sim.cutoff_distance - sim.particle_diam)
                sim.neighbors = sim.getNeighbors(sim.cutoff_distance, 1, 8);
                particlesFromNeighborList = sim.current_particles;
            end

            % Save position data
            if mod(frame, data_saving_frequency) == 0
                data_frame = frame / data_saving_frequency;
                idx_start = (plist_row - 1) * num_particles + 1;
                idx_end = plist_row * num_particles;
                plist(idx_start:idx_end, :) = [sim.current_particles(:,1:3), ...
                                                data_frame * ones(num_particles, 1)];
                plist_row = plist_row + 1;
            end

            % Skip image generation in parallel mode to save memory
            % Images can be generated later from plist.mat using generate_images_from_plist.m
            if generate_images_in_parallel && mod(frame, image_saving_frequency * 10) == 0
                try
                    img = sim.makeSpinImage(sim.current_particles(:,1:3), ' ');
                    imwrite(img, fullfile(sim_full_path, sprintf('%06d.png', frame)));
                    clear img;
                catch
                    % Ignore image errors - data is what matters
                end
            end

            sim.current_frame = frame;
        end

        % Clear large arrays before saving to reduce peak memory
        clear particles particlesFromNeighborList driven_indices fixed_indices;
        clear equilibrium_drive fixed_equilibrium_x fixed_equilibrium_y;

        %% Save results
        plist = plist(1:(plist_row-1)*num_particles, :);
        save(fullfile(sim_full_path, 'plist.mat'), 'plist', '-v7.3');

        sim_params = struct();
        sim_params.drive_frequency = drive_frequency;
        sim_params.drive_amplitude = drive_amplitude;
        sim_params.drive_width = drive_width;
        sim_params.fixed_width = fixed_width;
        sim_params.width = sim_width;
        sim_params.height = sim_height;
        sim_params.looseness = looseness;
        sim_params.zmax = zmax;
        sim_params.num_frames = num_frames;
        sim_params.data_saving_frequency = data_saving_frequency;
        sim_params.domain_style = domain_style;
        sim_params.drive_direction = drive_dir;
        sim_params.frames_per_cycle = frames_per_cycle;
        save(fullfile(sim_full_path, 'sim_params.mat'), 'sim_params');

        % Clear simulation object and plist to free memory
        clear sim plist;

        elapsed = toc(sim_tic);
        fprintf('[Worker %d] DONE: %s f=%.4f (%.1f min)\n', j, batch_name, drive_frequency, elapsed/60);

        batch_results{bi} = struct('status', 'success', 'batch', batch_name, 'freq', drive_frequency, 'time', elapsed);

    catch ME
        fprintf('[Worker %d] FAILED: %s f=%.4f - %s\n', j, batch_name, drive_frequency, ME.message);
        batch_results{bi} = struct('status', 'failed', 'batch', batch_name, 'freq', drive_frequency, 'error', ME.message);
    end
    end  % parfor

    % Copy batch results to main results array
    for bi = 1:length(batch_jobs)
        results{batch_jobs(bi)} = batch_results{bi};
    end

    % Force memory cleanup between batches
    clear batch_results;
    fprintf('Batch %d complete. Clearing pool for next batch...\n', batch_idx);
end  % batch loop

% Clean up final pool
pool = gcp('nocreate');
if ~isempty(pool)
    delete(pool);
end

total_time = toc;

%% ==================== FINAL SUMMARY ====================
fprintf('\n==============================================\n');
fprintf('   PARALLEL RUN COMPLETE\n');
fprintf('==============================================\n');
fprintf('Total time: %.1f minutes\n', total_time/60);
fprintf('Average per simulation: %.1f minutes\n', total_time/60/total_jobs);

% Count successes and failures
n_success = 0;
n_failed = 0;
for j = 1:total_jobs
    if strcmp(results{j}.status, 'success')
        n_success = n_success + 1;
    else
        n_failed = n_failed + 1;
    end
end

fprintf('Successful: %d\n', n_success);
fprintf('Failed: %d\n', n_failed);

% Write summary to progress file
fid = fopen(progress_file, 'a');
fprintf(fid, '\n==========================================\n');
fprintf(fid, 'RUN COMPLETED: %s\n', datestr(now));
fprintf(fid, 'Total time: %.1f minutes\n', total_time/60);
fprintf(fid, 'Successful: %d\n', n_success);
fprintf(fid, 'Failed: %d\n', n_failed);
if n_failed > 0
    fprintf(fid, '\nFailed jobs:\n');
    for j = 1:total_jobs
        if strcmp(results{j}.status, 'failed')
            fprintf(fid, '  %s f=%.4f: %s\n', results{j}.batch, results{j}.freq, results{j}.error);
        end
    end
end
fprintf(fid, '==========================================\n');
fclose(fid);

fprintf('\nProgress file: %s\n', progress_file);
