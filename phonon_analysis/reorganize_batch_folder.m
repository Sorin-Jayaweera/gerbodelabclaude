%% reorganize_batch_folder.m
% Reorganizes existing batch simulation folder into cleaner structure:
%   batch_folder/
%   ├── description.txt
%   ├── simulations/     <- all sinusoidal_f* folders moved here
%   └── analysis/        <- analysis results go here
%
% Run this ONCE to reorganize existing drivensinesims folder

clear; clc;

%% Configuration
batch_folder = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\drivensinesims';
simulations_folder = fullfile(batch_folder, 'simulations');
analysis_folder = fullfile(batch_folder, 'analysis');

%% Create subfolders if needed
if ~exist(simulations_folder, 'dir')
    mkdir(simulations_folder);
    fprintf('Created: %s\n', simulations_folder);
end

if ~exist(analysis_folder, 'dir')
    mkdir(analysis_folder);
    fprintf('Created: %s\n', analysis_folder);
end

%% Find simulation folders to move
sim_dirs = dir(fullfile(batch_folder, 'sinusoidal_f*'));
fprintf('Found %d simulation folders to reorganize\n', length(sim_dirs));

%% Move each simulation folder
moved_count = 0;
for i = 1:length(sim_dirs)
    if sim_dirs(i).isdir
        old_path = fullfile(batch_folder, sim_dirs(i).name);
        new_path = fullfile(simulations_folder, sim_dirs(i).name);

        if exist(new_path, 'dir')
            fprintf('  SKIP (already exists): %s\n', sim_dirs(i).name);
            continue;
        end

        fprintf('  Moving: %s\n', sim_dirs(i).name);
        movefile(old_path, new_path);
        moved_count = moved_count + 1;
    end
end

%% Move any .mat files from analysis that are in root
mat_files = dir(fullfile(batch_folder, '*_results.mat'));
for i = 1:length(mat_files)
    old_path = fullfile(batch_folder, mat_files(i).name);
    new_path = fullfile(analysis_folder, mat_files(i).name);
    fprintf('  Moving results file: %s\n', mat_files(i).name);
    movefile(old_path, new_path);
end

%% Write/update description file
description_file = fullfile(batch_folder, 'description.txt');
if ~exist(description_file, 'file')
    fid = fopen(description_file, 'w');
    fprintf(fid, 'BATCH SIMULATION: drivensinesims\n');
    fprintf(fid, '==========================================\n\n');
    fprintf(fid, 'PURPOSE:\n');
    fprintf(fid, '  Sinusoidal boundary driving at multiple frequencies to measure\n');
    fprintf(fid, '  phonon dispersion relation omega(k) in colloidal crystal.\n\n');
    fprintf(fid, 'FOLDER STRUCTURE:\n');
    fprintf(fid, '  simulations/   - Raw simulation output (.mat, images)\n');
    fprintf(fid, '  analysis/      - Analysis results and figures\n\n');
    fprintf(fid, 'REORGANIZED: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fclose(fid);
    fprintf('Created description.txt\n');
end

%% Summary
fprintf('\n=== Reorganization Complete ===\n');
fprintf('Moved %d simulation folders to simulations/\n', moved_count);
fprintf('\nNew structure:\n');
fprintf('  %s\n', batch_folder);
fprintf('  ├── description.txt\n');
fprintf('  ├── simulations/  (%d folders)\n', length(dir(fullfile(simulations_folder, 'sinusoidal_f*'))));
fprintf('  └── analysis/\n');
