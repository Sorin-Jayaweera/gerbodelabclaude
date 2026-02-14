%% run_zigzag_nodrive.m
% Run a zigzag simulation with NO driving - baseline thermal noise control
% Compare with driven simulations to see background fluctuations
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% ==================== ADD PATHS ====================
addpath(genpath('Z:\Colloid Cru\Colloid Work Folder'));
addpath(genpath('Z:\Colloid Cru\Simulations'));

%% ==================== BATCH FOLDER SETUP ====================
batch_name = 'controlsims';
batch_base = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
batch_folder = fullfile(batch_base, batch_name);
simulations_folder = fullfile(batch_folder, 'simulations');

if ~exist(batch_folder, 'dir')
    mkdir(batch_folder);
end
if ~exist(simulations_folder, 'dir')
    mkdir(simulations_folder);
end

%% ==================== SIMULATION PARAMETERS ====================
num_frames = 20000;
data_saving_frequency = 2;    % 10,000 data frames
image_saving_frequency = 10;  % 2,000 images

% DOMAIN STRUCTURE
domain_style = 'zigzags';  % Zigzag control

% Crystal parameters - same as driven sims for comparison
sim_width = 800;
sim_height = 400;
looseness = 1.06;
zmax = 0.45;

% Fixed boundary widths
fixed_width = 25;

%% ==================== RUN SIMULATION ====================
sim_name = 'zigzag_nodrive_control';
sim_full_path = fullfile(simulations_folder, sim_name);

fprintf('============================================\n');
fprintf('ZIGZAG NO-DRIVE CONTROL SIMULATION\n');
fprintf('Domain: %s\n', domain_style);
fprintf('Size: %d x %d\n', sim_width, sim_height);
fprintf('Frames: %d (saving every %d = %d data frames)\n', ...
    num_frames, data_saving_frequency, num_frames/data_saving_frequency);
fprintf('Output: %s\n', sim_full_path);
fprintf('============================================\n\n');

% Skip if already exists
if exist(fullfile(sim_full_path, 'plist.mat'), 'file')
    fprintf('Already exists, skipping.\n');
    return;
end

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

% Identify FIXED particles on LEFT edge (to match driven sims)
fixed_left_indices = sim.initial_particles(:,1) < fixed_width;
fixed_left_x = sim.initial_particles(fixed_left_indices, 1);
fixed_left_y = sim.initial_particles(fixed_left_indices, 2);

% Identify FIXED particles on RIGHT edge
fixed_right_indices = sim.initial_particles(:,1) > (sim_width - fixed_width);
fixed_right_x = sim.initial_particles(fixed_right_indices, 1);
fixed_right_y = sim.initial_particles(fixed_right_indices, 2);

num_particles = size(sim.initial_particles, 1);
fprintf('Particles: %d total, %d fixed left, %d fixed right\n', ...
    num_particles, sum(fixed_left_indices), sum(fixed_right_indices));

mkdir(sim_full_path);

% Initialize storage
total_data_frames = floor(num_frames / data_saving_frequency);
plist = zeros(num_particles * total_data_frames, 4);
plist_row = 1;

% Set initial positions
sim.current_particles = sim.initial_particles;

% Build neighbor list
sim.neighbors = sim.getNeighbors(sim.cutoff_distance, 1, 8);
particlesFromNeighborList = sim.current_particles;

%% Run simulation
fprintf('Starting simulation at %s\n', datestr(now));
tic;

for frame = 1:num_frames
    % NO DRIVING - just thermal evolution

    % Simulate frame
    sim.simulateFrame();

    % Re-enforce fixed boundaries
    sim.current_particles(fixed_left_indices, 1) = fixed_left_x;
    sim.current_particles(fixed_left_indices, 2) = fixed_left_y;
    sim.current_particles(fixed_right_indices, 1) = fixed_right_x;
    sim.current_particles(fixed_right_indices, 2) = fixed_right_y;

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
        imwrite(img, fullfile(sim_full_path, sprintf('%06d.png', frame)));
    end

    % Progress update
    if mod(frame, 5000) == 0
        fprintf('  Frame %d/%d (%.0f%%), elapsed: %.1fs\n', ...
            frame, num_frames, 100*frame/num_frames, toc);
    end

    sim.current_frame = frame;
end

%% Save results
plist = plist(1:(plist_row-1)*num_particles, :);
save(fullfile(sim_full_path, 'plist.mat'), 'plist', '-v7.3');

sim_params = struct();
sim_params.domain_style = domain_style;
sim_params.width = sim_width;
sim_params.height = sim_height;
sim_params.looseness = looseness;
sim_params.zmax = zmax;
sim_params.num_frames = num_frames;
sim_params.data_saving_frequency = data_saving_frequency;
sim_params.image_saving_frequency = image_saving_frequency;
sim_params.driving = 'none';

save(fullfile(sim_full_path, 'sim_params.mat'), 'sim_params');

fprintf('\n============================================\n');
fprintf('DONE! Zigzag no-drive control saved to:\n');
fprintf('  %s\n', sim_full_path);
fprintf('Completed in %.1f minutes\n', toc/60);
fprintf('============================================\n');

% Clean up
clearvars sim plist;
close all force;
