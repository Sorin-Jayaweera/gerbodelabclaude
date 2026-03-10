%% run_all_simulations.m
% MASTER SIMULATION RUNNER - Runs all simulation types at all frequencies
%
% Simulation types (7 total):
%   X-driven (side): chevron, stripe, random, frust
%   Y-driven (top):  chevron_top, stripe_top, frust_top
%
% Each type runs at 20 frequencies from 0.0004 to 0.10
% Total: 140 simulations
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% ==================== CONFIGURATION ====================
paths = get_paths();

% Add required paths
addpath(genpath(paths.colloid_work));
addpath(genpath(paths.simulations));
addpath(genpath(paths.phonon_analysis));

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

%% ==================== PROGRESS FILE ====================
progress_file = fullfile(batch_base, 'simulation_progress.txt');
fid = fopen(progress_file, 'w');
fprintf(fid, 'SIMULATION RUN STARTED: %s\n', datestr(now));
fprintf(fid, '==========================================\n\n');
fclose(fid);

%% ==================== MAIN SIMULATION LOOP ====================
fprintf('==============================================\n');
fprintf('   RUNNING ALL SIMULATIONS\n');
fprintf('==============================================\n');
fprintf('Total configs: %d\n', size(sim_configs, 1));
fprintf('Frequencies per config: %d\n', length(frequencies));
fprintf('Total simulations: %d\n\n', size(sim_configs, 1) * length(frequencies));

total_completed = 0;
total_pending = 0;

for c = 1:size(sim_configs, 1)
    batch_name = sim_configs{c, 1};
    domain_style = sim_configs{c, 2};
    name_fmt = sim_configs{c, 3};
    drive_dir = sim_configs{c, 4};
    sim_width = sim_configs{c, 5};
    sim_height = sim_configs{c, 6};

    batch_folder = fullfile(batch_base, batch_name);
    simulations_folder = fullfile(batch_folder, 'simulations');

    fprintf('\n==============================================\n');
    fprintf('CONFIG: %s (%s, %s-driven)\n', batch_name, domain_style, drive_dir);
    fprintf('==============================================\n');

    % Check which frequencies need to run
    pending_freqs = [];
    for i = 1:length(frequencies)
        f = frequencies(i);
        sim_name = sprintf(name_fmt, f);
        sim_path = fullfile(simulations_folder, sim_name);

        if exist(fullfile(sim_path, 'plist.mat'), 'file')
            fprintf('  [DONE] f=%.4f\n', f);
            total_completed = total_completed + 1;
        else
            fprintf('  [TODO] f=%.4f\n', f);
            pending_freqs(end+1) = f;
            total_pending = total_pending + 1;
        end
    end

    if isempty(pending_freqs)
        fprintf('All frequencies complete for %s\n', batch_name);
        continue;
    end

    fprintf('\nRunning %d pending frequencies for %s...\n', length(pending_freqs), batch_name);

    % Run each pending frequency
    for fi = 1:length(pending_freqs)
        drive_frequency = pending_freqs(fi);
        frames_per_cycle = round(1 / drive_frequency);

        % Adaptive image saving
        if drive_frequency >= 0.02
            image_saving_frequency = base_image_freq_high;
        else
            image_saving_frequency = base_image_freq_low;
        end

        sim_name = sprintf(name_fmt, drive_frequency);
        sim_full_path = fullfile(simulations_folder, sim_name);

        fprintf('\n----------------------------------------------\n');
        fprintf('Running: %s | f=%.4f (%d/%d)\n', batch_name, drive_frequency, fi, length(pending_freqs));
        fprintf('----------------------------------------------\n');

        % Log to progress file
        fid = fopen(progress_file, 'a');
        fprintf(fid, '[%s] STARTING: %s f=%.4f\n', datestr(now), batch_name, drive_frequency);
        fclose(fid);

        % Clean up partial runs
        if exist(sim_full_path, 'dir')
            rmdir(sim_full_path, 's');
        end
        mkdir(sim_full_path);

        try
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
                sim.initialize_grains_frust();
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

            fprintf('  Particles: %d total, %d driven, %d fixed\n', ...
                num_particles, sum(driven_indices), sum(fixed_indices));

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
            tic;
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

                % Save images
                if mod(frame, image_saving_frequency) == 0
                    img = sim.makeSpinImage(sim.current_particles(:,1:3), ' ');
                    fig = figure('Visible', 'off', 'Position', [100 100 800 500]);
                    imshow(img);
                    title(sprintf('%s | f=%.4f | Frame %d', domain_style, drive_frequency, frame), ...
                        'Color', 'w', 'FontSize', 12);
                    saveas(fig, fullfile(sim_full_path, sprintf('%06d.png', frame)));
                    close(fig);
                end

                % Progress update
                if mod(frame, 5000) == 0
                    fprintf('    Frame %d/%d (%.0f%%), elapsed: %.1fs\n', ...
                        frame, num_frames, 100*frame/num_frames, toc);
                end

                sim.current_frame = frame;
            end

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

            elapsed = toc;
            fprintf('  Completed in %.1f minutes\n', elapsed/60);

            % Log completion
            fid = fopen(progress_file, 'a');
            fprintf(fid, '[%s] COMPLETED: %s f=%.4f (%.1f min)\n', datestr(now), batch_name, drive_frequency, elapsed/60);
            fclose(fid);

        catch ME
            fprintf('  ERROR: %s\n', ME.message);
            fid = fopen(progress_file, 'a');
            fprintf(fid, '[%s] FAILED: %s f=%.4f - %s\n', datestr(now), batch_name, drive_frequency, ME.message);
            fclose(fid);
        end

        % Memory cleanup
        clearvars sim plist img fig;
        close all force;
        pause(1);
    end
end

%% ==================== FINAL SUMMARY ====================
fprintf('\n==============================================\n');
fprintf('   ALL SIMULATIONS COMPLETE\n');
fprintf('==============================================\n');
fprintf('End time: %s\n', datestr(now));
fprintf('Progress file: %s\n', progress_file);

fid = fopen(progress_file, 'a');
fprintf(fid, '\n==========================================\n');
fprintf(fid, 'RUN COMPLETED: %s\n', datestr(now));
fprintf(fid, '==========================================\n');
fclose(fid);
