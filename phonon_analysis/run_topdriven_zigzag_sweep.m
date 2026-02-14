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
batch_base = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
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

for i = 1:length(frequencies)
    f = frequencies(i);

    % Adaptive image saving
    if f < 0.02
        image_saving_frequency = base_image_freq_low;
    else
        image_saving_frequency = base_image_freq_high;
    end

    sim_name = sprintf('topdriven_f%.4f_a%.1f', f, drive_amplitude);
    sim_full_path = fullfile(simulations_folder, sim_name);

    fprintf('--------------------------------------------\n');
    fprintf('Simulation %d/%d: f=%.4f\n', i, length(frequencies), f);
    fprintf('Output: %s\n', sim_full_path);
    fprintf('Image freq: %d (saving %d images)\n', image_saving_frequency, num_frames/image_saving_frequency);
    fprintf('--------------------------------------------\n');

    % Skip if already exists
    if exist(fullfile(sim_full_path, 'plist.mat'), 'file')
        fprintf('  Already exists, skipping.\n\n');
        continue;
    end

    % Create simulation
    sim = TDsim();
    sim.Folder = sim_full_path;
    sim.DataSavingFrequency = data_saving_frequency;
    sim.ImageSavingFrequency = image_saving_frequency;
    sim.NumFrames = num_frames;

    % Create crystal with zigzag domains
    sim.addObject(buckledMonolayer(...
        'Lx', sim_width, ...
        'Ly', sim_height, ...
        'Looseness', looseness, ...
        'Style', domain_style, ...
        'Zmax', zmax));

    % SINUSOIDAL DRIVING FROM TOP (Y-direction)
    % Drive region at TOP of crystal
    sim.addObject(externalForce(...
        'Region', [0, sim_width, sim_height-drive_width, sim_height], ...
        'ForceType', 'sinusoidal_y', ...
        'Amplitude', drive_amplitude, ...
        'Frequency', f));

    % FIXED BOUNDARY AT BOTTOM
    sim.addObject(externalForce(...
        'Region', [0, sim_width, 0, fixed_width], ...
        'ForceType', 'hold'));

    % Run simulation
    fprintf('  Starting at %s\n', datestr(now));
    tic;
    sim.run();
    elapsed = toc;
    fprintf('  Completed in %.1f minutes\n', elapsed/60);

    % Save simulation parameters
    sim_params = struct();
    sim_params.drive_frequency = f;
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
    save(fullfile(sim_full_path, 'sim_params.mat'), 'sim_params');

    % Save plist as .mat
    plist = sim.Data;
    save(fullfile(sim_full_path, 'plist.mat'), 'plist', '-v7.3');
    fprintf('  Saved plist.mat (%d rows)\n\n', size(plist, 1));

    % MEMORY CLEANUP - prevent MATLAB crash
    clearvars sim plist;
    close all force;
    pause(1);  % Brief pause for memory to clear
end

fprintf('============================================\n');
fprintf('TOP-DRIVEN ZIGZAG SWEEP COMPLETE!\n');
fprintf('Results saved to: %s\n', simulations_folder);
fprintf('============================================\n');
