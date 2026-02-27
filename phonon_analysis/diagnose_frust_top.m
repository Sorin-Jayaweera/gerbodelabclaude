%% diagnose_frust_top.m
% Diagnostic script to check FRUST_TOP simulation particle distribution
% Verifies if particles exist in the drive region at the top edge
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% Configuration
base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
sim_folder = fullfile(base_path, 'frusttopsims', 'simulations');

% Pick a frequency to check (e.g., 0.001)
test_freq = 0.001;
sim_name = sprintf('frusttop_f%.4f_a2.0', test_freq);
sim_path = fullfile(sim_folder, sim_name);

%% Change to simulation directory
fprintf('Changing to simulation directory...\n');
fprintf('  Path: %s\n', sim_path);

if ~exist(sim_path, 'dir')
    error('Simulation folder not found: %s', sim_path);
end

cd(sim_path);
fprintf('  Current directory: %s\n\n', pwd);

%% Load plist data
if ~exist('plist.mat', 'file')
    error('plist.mat not found in current directory');
end

fprintf('Loading plist.mat...\n');
load('plist.mat', 'plist');
fprintf('  Loaded %d rows\n\n', size(plist, 1));

%% Check first frame
frame1 = plist(plist(:,4) == 1, :);
fprintf('Frame 1 statistics:\n');
fprintf('  Total particles: %d\n', size(frame1, 1));
fprintf('  X range: [%.1f, %.1f]\n', min(frame1(:,1)), max(frame1(:,1)));
fprintf('  Y range: [%.1f, %.1f]\n', min(frame1(:,2)), max(frame1(:,2)));

%% Check drive region (top edge)
% For 800-tall simulation, drive region is Y > 775 (top 25 rows)
drive_threshold = 775;
sim_height = 800;
drive_width = 25;

fprintf('\nDrive region analysis (Y > %d):\n', drive_threshold);

in_drive_region = frame1(:,2) > drive_threshold;
num_driven = sum(in_drive_region);
fprintf('  Particles in drive region: %d\n', num_driven);
fprintf('  Percentage of total: %.1f%%\n', 100 * num_driven / size(frame1, 1));

if num_driven == 0
    fprintf('\n*** WARNING: No particles in drive region! ***\n');
    fprintf('This explains why the simulation appears passive.\n');
    fprintf('The crystal may not extend to the top edge.\n');

    % Check the actual top edge
    max_y = max(frame1(:,2));
    fprintf('\nActual top of crystal: Y = %.1f\n', max_y);
    fprintf('Expected top: Y = %d\n', sim_height);
    fprintf('Gap: %.1f pixels\n', sim_height - max_y);
else
    fprintf('\nDrive region appears populated correctly.\n');

    % Check if driven particles actually moved
    fprintf('\nChecking particle motion over time...\n');
    frames = unique(plist(:,4));
    num_frames = length(frames);

    % Get Y positions of driven particles across frames
    sample_frames = [1, min(10, num_frames), min(100, num_frames)];
    for i = 1:length(sample_frames)
        f = sample_frames(i);
        frame_data = plist(plist(:,4) == f, :);
        driven = frame_data(frame_data(:,2) > drive_threshold, :);
        if ~isempty(driven)
            fprintf('  Frame %d: %d driven particles, Y range [%.2f, %.2f]\n', ...
                f, size(driven,1), min(driven(:,2)), max(driven(:,2)));
        end
    end
end

%% Check fixed region (bottom edge)
fixed_threshold = 25;
fprintf('\nFixed region analysis (Y < %d):\n', fixed_threshold);

in_fixed_region = frame1(:,2) < fixed_threshold;
num_fixed = sum(in_fixed_region);
fprintf('  Particles in fixed region: %d\n', num_fixed);
fprintf('  Percentage of total: %.1f%%\n', 100 * num_fixed / size(frame1, 1));

%% Summary
fprintf('\n========================================\n');
fprintf('DIAGNOSTIC SUMMARY\n');
fprintf('========================================\n');
if num_driven == 0
    fprintf('STATUS: PROBLEM DETECTED\n');
    fprintf('The crystal does not extend into the drive region.\n');
    fprintf('Simulations need to be regenerated with initialize_grains_frust()\n');
    fprintf('modified to populate particles up to Y = %d.\n', sim_height);
else
    fprintf('STATUS: Drive region is populated\n');
    fprintf('If motion is still not visible, check:\n');
    fprintf('  1. Drive amplitude in sim_params.mat\n');
    fprintf('  2. Actual Y displacement over frames\n');
end
fprintf('========================================\n');
