%% run_topdriven_zigzag_sweep.m
% Run sinusoidal driving from TOP (Y-direction) on zigzag crystal
% TALL and NARROW geometry (flipped from standard)
% Tests directional asymmetry in zigzag wave propagation
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% ==================== ADD PATHS ====================
addpath(genpath('Z:\Colloid Cru\Colloid Work Folder'));
addpath(genpath('Z:\Colloid Cru\Simulations'));

%% ==================== BATCH FOLDER SETUP ====================
batch_name = 'topdrivensims';  % Top-driven zigzag
batch_base = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\sims';
batch_folder = fullfile(batch_base, batch_name);
simulations_folder = fullfile(batch_folder, 'simulations');
analysis_folder = fullfile(batch_folder, 'analysis');

%% ==================== FREQUENCY SWEEP PARAMETERS ====================
% Same frequencies as X-driven zigzag for comparison
frequencies = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...
               0.001, 0.0012, 0.0015, 0.0018, ...
               0.002, 0.0025, 0.003, 0.004, 0.005, ...
               0.007, 0.01, 0.02, 0.05, 0.10];

% Common parameters
drive_amplitude = 2.0;
drive_width = 25;      % Width of driven region at TOP
fixed_width = 25;      % Width of fixed region at BOTTOM
num_frames = 20000;
data_saving_frequency = 2;  % 10,000 data frames

% IMAGE SAVING - Adaptive
base_image_freq_low = 10;   % For f < 0.02: 2000 images
base_image_freq_high = 2;   % For f >= 0.02: 10000 images

% DOMAIN STRUCTURE
domain_style = 'zigzags';

% Crystal parameters - TALL and NARROW (flipped from standard)
% Standard is 800 wide x 400 tall
% This is 400 wide x 800 tall
sim_width = 400;   % NARROW
sim_height = 800;  % TALL
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

%% ==================== RUN FREQUENCY SWEEP ====================
fprintf('============================================\n');
fprintf('TOP-DRIVEN ZIGZAG FREQUENCY SWEEP\n');
fprintf('Geometry: %d x %d (TALL and NARROW)\n', sim_width, sim_height);
fprintf('Drive: Y-direction from TOP\n');
fprintf('Frequencies: %d values from %.4f to %.2f\n', ...
    length(frequencies), min(frequencies), max(frequencies));
fprintf('============================================\n\n');

%% Pre-scan for completed simulations
fprintf('Checking for completed simulations...\n');
pending_indices = [];
for i = 1:length(frequencies)
    f = frequencies(i);
    sim_name = sprintf('topdriven_f%.4f_a%.1f', f, drive_amplitude);
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

    % Adaptive image saving
    if drive_frequency < 0.02
        image_saving_frequency = base_image_freq_low;
    else
        image_saving_frequency = base_image_freq_high;
    end

    sim_name = sprintf('topdriven_f%.4f_a%.1f', drive_frequency, drive_amplitude);
    sim_full_path = fullfile(simulations_folder, sim_name);

    fprintf('--------------------------------------------\n');
    fprintf('Simulation %d/%d: f=%.4f (Y-direction)\n', idx, length(pending_indices), drive_frequency);
    fprintf('Output: %s\n', sim_full_path);
    fprintf('Image freq: %d (saving %d images)\n', image_saving_frequency, num_frames/image_saving_frequency);
    fprintf('--------------------------------------------\n');

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

    % Initialize crystal with ZIGZAG domains
    sim.initialize_grains_unfrust('zigzags');

    % Identify driven particles (TOP edge) - drive in Y direction
    driven_indices = sim.initial_particles(:,2) > (sim_height - drive_width);
    equilibrium_y = sim.initial_particles(driven_indices, 2);
    equilibrium_x = sim.initial_particles(driven_indices, 1);  % Keep X fixed too

    % Identify FIXED particles (BOTTOM edge)
    fixed_indices = sim.initial_particles(:,2) < fixed_width;
    fixed_equilibrium_x = sim.initial_particles(fixed_indices, 1);
    fixed_equilibrium_y = sim.initial_particles(fixed_indices, 2);

    num_particles = size(sim.initial_particles, 1);
    fprintf('  Particles: %d total, %d driven (top), %d fixed (bottom)\n', ...
        num_particles, sum(driven_indices), sum(fixed_indices));

    mkdir(sim_full_path);

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
        % Apply sinusoidal drive in Y DIRECTION
        drive_phase = drive_amplitude * sin(2 * pi * drive_frequency * frame);
        sim.current_particles(driven_indices, 2) = equilibrium_y + drive_phase;
        sim.current_particles(driven_indices, 1) = equilibrium_x;  % Keep X fixed

        % Simulate frame
        sim.simulateFrame();

        % Re-enforce boundaries
        sim.current_particles(driven_indices, 2) = equilibrium_y + drive_phase;
        sim.current_particles(driven_indices, 1) = equilibrium_x;
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
            cycle_number = frame / frames_per_cycle;
            img = sim.makeSpinImage(sim.current_particles(:,1:3), ' ');
            imwrite(img, fullfile(sim_full_path, sprintf('%06d.png', frame)));
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
    sim_params.drive_direction = 'y';
    sim_params.drive_location = 'top';
    sim_params.drive_width = drive_width;
    sim_params.fixed_width = fixed_width;
    sim_params.domain_style = domain_style;
    sim_params.width = sim_width;
    sim_params.height = sim_height;
    sim_params.num_frames = num_frames;
    sim_params.data_saving_frequency = data_saving_frequency;
    sim_params.image_saving_frequency = image_saving_frequency;
    sim_params.frames_per_cycle = frames_per_cycle;

    save(fullfile(sim_full_path, 'sim_params.mat'), 'sim_params');

    fprintf('  Completed in %.1f minutes\n', toc/60);

    % MEMORY CLEANUP - prevent MATLAB crash
    clearvars sim plist img;
    close all force;
    pause(1);
end

fprintf('\n============================================\n');
fprintf('TOP-DRIVEN ZIGZAG SWEEP COMPLETE!\n');
fprintf('Results saved to: %s\n', simulations_folder);
fprintf('============================================\n');
