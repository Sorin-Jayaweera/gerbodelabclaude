%% cleanup_frust_top.m
% Delete all existing FRUST_TOP simulations so they can be regenerated
% Run this before run_frust_stripe_top_sweep.m to start fresh
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% Configuration
base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\sims';
sim_folder = fullfile(base_path, 'frusttopsims', 'simulations');

%% Check folder exists
if ~exist(sim_folder, 'dir')
    fprintf('Simulations folder not found: %s\n', sim_folder);
    fprintf('Nothing to clean up.\n');
    return;
end

%% Find all frusttop simulations
cd(sim_folder);
sim_dirs = dir('frusttop_*');
sim_dirs = sim_dirs([sim_dirs.isdir]);

if isempty(sim_dirs)
    fprintf('No FRUST_TOP simulations found.\n');
    return;
end

fprintf('Found %d FRUST_TOP simulations to delete:\n', length(sim_dirs));
for i = 1:length(sim_dirs)
    fprintf('  %s\n', sim_dirs(i).name);
end

%% Confirm deletion
fprintf('\n');
response = input('Delete all these simulations? (yes/no): ', 's');

if ~strcmpi(response, 'yes')
    fprintf('Aborted. No files deleted.\n');
    return;
end

%% Delete simulations
fprintf('\nDeleting simulations...\n');
for i = 1:length(sim_dirs)
    full_path = fullfile(sim_folder, sim_dirs(i).name);
    fprintf('  Deleting %s...\n', sim_dirs(i).name);
    rmdir(full_path, 's');
end

fprintf('\nDone! Deleted %d simulations.\n', length(sim_dirs));
fprintf('Run run_frust_stripe_top_sweep.m to regenerate with fixed drive region.\n');
