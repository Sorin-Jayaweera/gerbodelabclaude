%% run_stripe_nodrive.m
% Run a stripe simulation with NO driving - baseline thermal noise control
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

%% ==================== SIMULATION PARAMETERS ====================
num_frames = 20000;
data_saving_frequency = 2;    % 10,000 data frames
image_saving_frequency = 10;  % 2,000 images

% DOMAIN STRUCTURE
domain_style = 'stripes';  % Stripe control

% Crystal parameters - same as driven sims for comparison
sim_width = 800;
sim_height = 400;
looseness = 1.06;
zmax = 0.45;

%% ==================== CREATE FOLDERS ====================
if ~exist(batch_folder, 'dir')
    mkdir(batch_folder);
end
if ~exist(simulations_folder, 'dir')
    mkdir(simulations_folder);
end

%% ==================== RUN SIMULATION ====================
sim_name = 'stripe_nodrive_control';
sim_full_path = fullfile(simulations_folder, sim_name);

fprintf('============================================\n');
fprintf('STRIPE NO-DRIVE CONTROL SIMULATION\n');
fprintf('Domain: %s\n', domain_style);
fprintf('Size: %d x %d\n', sim_width, sim_height);
fprintf('Frames: %d (saving every %d = %d data frames)\n', ...
    num_frames, data_saving_frequency, num_frames/data_saving_frequency);
fprintf('Output: %s\n', sim_full_path);
fprintf('============================================\n\n');

% Create simulation
sim = TDsim();
sim.Folder = sim_full_path;
sim.DataSavingFrequency = data_saving_frequency;
sim.ImageSavingFrequency = image_saving_frequency;
sim.NumFrames = num_frames;

% Create crystal with stripe domains
sim.addObject(buckledMonolayer(...
    'Lx', sim_width, ...
    'Ly', sim_height, ...
    'Looseness', looseness, ...
    'Style', domain_style, ...
    'Zmax', zmax));

% NO DRIVING - just let it evolve thermally

% Add fixed boundaries on left and right to match driven sims
sim.addObject(externalForce('Region', [0, 25, 0, sim_height], ...
    'ForceType', 'hold'));
sim.addObject(externalForce('Region', [sim_width-25, sim_width, 0, sim_height], ...
    'ForceType', 'hold'));

% Run simulation
fprintf('Starting simulation at %s\n', datestr(now));
tic;
sim.run();
elapsed = toc;
fprintf('Simulation completed in %.1f minutes\n', elapsed/60);

% Save parameters
sim_params = struct();
sim_params.domain_style = domain_style;
sim_params.width = sim_width;
sim_params.height = sim_height;
sim_params.num_frames = num_frames;
sim_params.data_saving_frequency = data_saving_frequency;
sim_params.image_saving_frequency = image_saving_frequency;
sim_params.driving = 'none';
save(fullfile(sim_full_path, 'sim_params.mat'), 'sim_params');

% Save plist
plist = sim.Data;
save(fullfile(sim_full_path, 'plist.mat'), 'plist', '-v7.3');

fprintf('\n============================================\n');
fprintf('DONE! Stripe no-drive control saved to:\n');
fprintf('  %s\n', sim_full_path);
fprintf('============================================\n');

% Clean up
clearvars sim plist;
close all force;
