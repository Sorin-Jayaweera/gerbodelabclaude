function run_stripe_top_single(drive_frequency)
%% run_stripe_top_single.m
% Run sinusoidal driving from TOP (Y-direction) on STRIPE crystal
% Single frequency version - accepts frequency as input argument
%
% Usage: run_stripe_top_single(0.0005)
%
% Author: Gerbode Lab
% Date: 2026

if nargin < 1
    error('Usage: run_stripe_top_single(frequency), e.g., run_stripe_top_single(0.0005)');
end

%% ==================== ADD PATHS ====================
addpath(genpath('Z:\Colloid Cru\Colloid Work Folder'));
addpath(genpath('Z:\Colloid Cru\Simulations'));

%% ==================== BATCH FOLDER SETUP ====================
batch_name = 'stripetopsims';  % TOP-driven STRIPE simulations
batch_base = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\sims';
batch_folder = fullfile(batch_base, batch_name);
simulations_folder = fullfile(batch_folder, 'simulations');
analysis_folder = fullfile(batch_folder, 'analysis');

%% ==================== PARAMETERS ====================
drive_amplitude = 2.0;
drive_width = 25;
fixed_width = 25;
num_frames = 20000;
data_saving_frequency = 2;

% IMAGE SAVING - Adaptive based on frequency
base_image_freq_low = 10;   % For f < 0.02: 2000 images
base_image_freq_high = 2;   % For f >= 0.02: 10000 images

% DOMAIN STRUCTURE
domain_style = 'stripes';

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

fprintf('============================================\n');
fprintf('   TOP-DRIVEN STRIPE SINGLE FREQUENCY\n');
fprintf('============================================\n');
fprintf('Frequency: %.4f\n', drive_frequency);
fprintf('Domain structure: %s\n', domain_style);
fprintf('Drive direction: Y (from top)\n\n');

frames_per_cycle = round(1 / drive_frequency);

% Set image saving frequency based on drive frequency
if drive_frequency >= 0.02
    image_saving_frequency = base_image_freq_high;
else
    image_saving_frequency = base_image_freq_low;
end

sim_name = sprintf('stripetop_f%.4f_a%.1f', drive_frequency, drive_amplitude);
sim_full_path = fullfile(simulations_folder, sim_name);

% Check if already complete
if exist(fullfile(sim_full_path, 'plist.mat'), 'file')
    fprintf('[DONE] Simulation already complete: %s\n', sim_name);
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

% Initialize crystal with STRIPE domains
sim.initialize_grains_unfrust('stripes');

% Identify driven particles (TOP edge) - drive in Y direction
driven_indices = sim.initial_particles(:,2) > (sim_height - drive_width);
equilibrium_y = sim.initial_particles(driven_indices, 2);
equilibrium_x = sim.initial_particles(driven_indices, 1);

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

%% Save results - robust save with retry for network drives
plist = plist(1:(plist_row-1)*num_particles, :);

plist_file = fullfile(sim_full_path, 'plist.mat');
params_file = fullfile(sim_full_path, 'sim_params.mat');

% Try saving directly first, with retry on failure
save_success = false;
for attempt = 1:3
    try
        fprintf('  Saving plist (attempt %d)...\n', attempt);
        save(plist_file, 'plist', '-v7.3');
        save_success = true;
        break;
    catch ME
        fprintf('  Save failed: %s\n', ME.message);
        if attempt < 3
            fprintf('  Retrying in 5 seconds...\n');
            pause(5);
        end
    end
end

% If direct save failed, try temp file approach
if ~save_success
    fprintf('  Trying temp file approach...\n');
    temp_file = fullfile(tempdir, sprintf('plist_temp_%s.mat', datestr(now,'HHMMSS')));
    try
        save(temp_file, 'plist', '-v7.3');
        copyfile(temp_file, plist_file);
        delete(temp_file);
        save_success = true;
        fprintf('  Saved via temp file.\n');
    catch ME2
        fprintf('  FAILED to save plist: %s\n', ME2.message);
        fprintf('  Data lost for f=%.4f\n', drive_frequency);
    end
end

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

save(params_file, 'sim_params');

fprintf('  Completed in %.1f minutes\n', toc/60);

% MEMORY CLEANUP - prevent MATLAB crash
clearvars sim plist img;
close all force;

fprintf('\n============================================\n');
fprintf('TOP-DRIVEN STRIPE COMPLETE: f=%.4f\n', drive_frequency);
fprintf('Results saved to: %s\n', sim_full_path);
fprintf('============================================\n');

end
