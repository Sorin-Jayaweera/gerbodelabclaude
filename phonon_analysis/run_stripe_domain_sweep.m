%% run_stripe_domain_sweep.m
% Run sinusoidal driving simulations with STRIPE domain structure
% Same frequencies as zigzag simulations for direct comparison
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% ==================== ADD PATHS ====================
addpath(genpath('Z:\Colloid Cru\Colloid Work Folder'));
addpath(genpath('Z:\Colloid Cru\Simulations'));

%% ==================== BATCH FOLDER SETUP ====================
batch_name = 'stripesinesims';  % STRIPE domain simulations
batch_base = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
batch_folder = fullfile(batch_base, batch_name);
simulations_folder = fullfile(batch_folder, 'simulations');
analysis_folder = fullfile(batch_folder, 'analysis');

%% ==================== FREQUENCY SWEEP PARAMETERS ====================
% Same frequencies as zigzag for comparison - INCLUDING 0.10 now
frequencies = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...
               0.001, 0.0012, 0.0015, 0.0018, ...
               0.002, 0.0025, 0.003, 0.004, 0.005, ...
               0.007, 0.01, 0.02, 0.05, 0.10];  % 0.10 included with higher sampling

% Common parameters
drive_amplitude = 2.0;
drive_width = 25;
fixed_width = 25;
num_frames = 20000;
data_saving_frequency = 10;  % Save every 10 frames = 2,000 data frames

% IMAGE SAVING - Save every data frame for smooth video viewing
% 2000 images total = one per data frame
image_saving_frequency = 10;  % Every 10 sim frames = 2000 images total

% DOMAIN STRUCTURE
domain_style = 'stripes';  % <<< STRIPES

% Crystal parameters
sim_width = 800;
sim_height = 400;
looseness = 1.06;
zmax = 0.45;

%% ==================== CREATE BATCH FOLDER STRUCTURE ====================
if ~exist(batch_folder, 'dir')
    mkdir(batch_folder);
end
if ~exist(simulations_folder, 'dir')
    mkdir(simulations_folder);
end
if ~exist(analysis_folder, 'dir')
    mkdir(analysis_folder);
end

% Write description file
description_file = fullfile(batch_folder, 'description.txt');
fid = fopen(description_file, 'w');
fprintf(fid, 'BATCH SIMULATION: %s\n', batch_name);
fprintf(fid, '==========================================\n\n');
fprintf(fid, 'PURPOSE:\n');
fprintf(fid, '  Sinusoidal boundary driving with STRIPE domain structure.\n');
fprintf(fid, '  Compare wave propagation with zigzag domains.\n\n');
fprintf(fid, 'DRIVING PARAMETERS:\n');
fprintf(fid, '  Drive amplitude: %.1f pixels\n', drive_amplitude);
fprintf(fid, '  Drive width: %d pixels from left edge\n', drive_width);
fprintf(fid, '  Fixed width: %d pixels from right edge (absorbing BC)\n', fixed_width);
fprintf(fid, '  Frequencies: %s\n', mat2str(frequencies, 4));
fprintf(fid, '  Number of frequencies: %d\n\n', length(frequencies));
fprintf(fid, 'CRYSTAL PARAMETERS:\n');
fprintf(fid, '  Domain style: %s\n', domain_style);
fprintf(fid, '  Simulation size: %d x %d pixels\n', sim_width, sim_height);
fprintf(fid, '  Looseness: %.3f\n', looseness);
fprintf(fid, '  Zmax: %.3f\n\n', zmax);
fprintf(fid, 'IMAGE SAVING:\n');
fprintf(fid, '  Every %d simulation frames = %d images per simulation\n', ...
    image_saving_frequency, floor(num_frames/image_saving_frequency));
fprintf(fid, '\nDATE STARTED: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fclose(fid);
fprintf('Batch folder: %s\n', batch_folder);

%% ==================== RUN SWEEP ====================
fprintf('==============================================\n');
fprintf('   STRIPE DOMAIN FREQUENCY SWEEP\n');
fprintf('==============================================\n');
fprintf('Frequencies to run: %d total\n', length(frequencies));
fprintf('Domain structure: %s\n', domain_style);
fprintf('Images per simulation: %d\n', floor(num_frames/image_saving_frequency));
fprintf('\n');

%% Pre-scan for completed simulations
fprintf('Checking for completed simulations...\n');
pending_indices = [];
for i = 1:length(frequencies)
    f = frequencies(i);
    sim_name = sprintf('sinusoidal_f%.4f_a%.1f_stripes', f, drive_amplitude);
    sim_full_path = fullfile(simulations_folder, sim_name);

    if exist(fullfile(sim_full_path, 'plist.mat'), 'file')
        fprintf('  [DONE] f=%.4f\n', f);
    else
        fprintf('  [TODO] f=%.4f\n', f);
        pending_indices(end+1) = i;
    end
end

fprintf('\n%d/%d remaining\n', length(pending_indices), length(frequencies));
if isempty(pending_indices)
    fprintf('All simulations complete!\n');
    return;
end

fprintf('Starting in 3 seconds... (Ctrl+C to cancel)\n');
pause(3);

%% Run pending simulations
for idx = 1:length(pending_indices)
    i = pending_indices(idx);
    drive_frequency = frequencies(i);
    frames_per_cycle = round(1 / drive_frequency);

    fprintf('\n----------------------------------------------\n');
    fprintf('Running %d/%d: f = %.4f (%s)\n', idx, length(pending_indices), drive_frequency, domain_style);
    fprintf('----------------------------------------------\n');

    sim_name = sprintf('sinusoidal_f%.4f_a%.1f_stripes', drive_frequency, drive_amplitude);
    sim_full_path = fullfile(simulations_folder, sim_name);

    % Clean up partial runs
    if exist(sim_full_path, 'dir')
        rmdir(sim_full_path, 's');
    end

    %% Initialize simulation
    sim = TDsim();
    sim.width = sim_width;
    sim.height = sim_height;
    sim.looseness = looseness;
    sim.zmax = zmax;
    sim.data_saving_frequency = data_saving_frequency;
    sim.image_saving_frequency = image_saving_frequency;
    sim.num_frames = num_frames;

    % Initialize crystal with STRIPE domains
    sim.initialize_grains_unfrust('stripes');

    % Identify driven particles (LEFT edge)
    driven_indices = sim.initial_particles(:,1) < drive_width;
    equilibrium_x = sim.initial_particles(driven_indices, 1);

    % Identify FIXED particles (RIGHT edge)
    fixed_indices = sim.initial_particles(:,1) > (sim_width - fixed_width);
    fixed_equilibrium_x = sim.initial_particles(fixed_indices, 1);
    fixed_equilibrium_y = sim.initial_particles(fixed_indices, 2);

    num_particles = size(sim.initial_particles, 1);
    fprintf('  Particles: %d total, %d driven, %d fixed\n', ...
        num_particles, sum(driven_indices), sum(fixed_indices));

    mkdir(sim_full_path);

    % Initialize storage
    total_data_frames = floor(num_frames / data_saving_frequency);
    plist = zeros(num_particles * total_data_frames, 4);
    plist_row = 1;

    % Set initial positions
    particles = sim.initial_particles;
    particles(driven_indices, 1) = equilibrium_x;
    sim.initial_particles = particles;
    sim.current_particles = particles;

    % Build neighbor list
    sim.neighbors = sim.getNeighbors(sim.cutoff_distance, 1, 8);
    particlesFromNeighborList = sim.current_particles;

    %% Run simulation
    tic;
    for frame = 1:num_frames
        % Apply sinusoidal drive
        drive_phase = drive_amplitude * sin(2 * pi * drive_frequency * frame);
        sim.current_particles(driven_indices, 1) = equilibrium_x + drive_phase;

        % Simulate frame
        sim.simulateFrame();

        % Re-enforce boundaries
        sim.current_particles(driven_indices, 1) = equilibrium_x + drive_phase;
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

        % Save images at fixed rate
        if mod(frame, image_saving_frequency) == 0
            cycle_number = frame / frames_per_cycle;
            phase_degrees = mod(frame, frames_per_cycle) / frames_per_cycle * 360;

            img = sim.makeSpinImage(sim.current_particles(:,1:3), ' ');
            fig = figure('Visible', 'off', 'Position', [100 100 800 500]);
            imshow(img);
            title(sprintf('STRIPES | f=%.4f | Frame %d | Cycle %.2f | Drive: %.2f px', ...
                drive_frequency, frame, cycle_number, drive_phase), ...
                'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold');
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
    sim_params.frames_per_cycle = frames_per_cycle;

    save(fullfile(sim_full_path, 'sim_params.mat'), 'sim_params');

    fprintf('  Completed in %.1f minutes\n', toc/60);
end

fprintf('\n==============================================\n');
fprintf('   STRIPE SWEEP COMPLETE!\n');
fprintf('==============================================\n');
