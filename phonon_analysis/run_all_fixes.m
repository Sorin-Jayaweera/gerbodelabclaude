%% run_all_fixes.m
% MASTER SCRIPT: Runs all fixes and regenerates outputs
%
% This script:
% 1. Converts plist.mat to xyz_data.mat for simulation viewer
% 2. Re-runs full analysis (fixes decomposition x0/y0 saving)
% 3. Creates lattice comparison images for analysis_viewer
% 4. Creates drive comparison videos (top vs side driven)
%
% RUN ORDER:
%   1. run_all_fixes.m (this script)
%   2. analysis_viewer.m (to browse results)
%   3. interactive_simulation_viewer.m (to view simulations)

clear; close all; clc;

fprintf('================================================\n');
fprintf('          RUNNING ALL FIXES                     \n');
fprintf('================================================\n');
fprintf('Start time: %s\n\n', datestr(now));

start_time = tic;

%% Step 1: Convert plist.mat to xyz_data.mat
fprintf('\n========== STEP 1: Converting plist to xyz_data ==========\n');
try
    convert_plist_to_xyz;
    fprintf('[OK] plist conversion complete\n');
catch ME
    fprintf('[WARN] plist conversion: %s\n', ME.message);
end

%% Step 2: Re-run full analysis (or just regenerate figures)
fprintf('\n========== STEP 2: Regenerating figures from saved data ==========\n');
fprintf('(This ensures decomposition plots have position data)\n');
try
    regenerate_figures;
    fprintf('[OK] Figure regeneration complete\n');
catch ME
    fprintf('[WARN] Figure regeneration: %s\n', ME.message);
end

%% Step 3: Create lattice comparison images
fprintf('\n========== STEP 3: Creating lattice comparison images ==========\n');
try
    create_lattice_comparison_images;
    fprintf('[OK] Lattice comparison images complete\n');
catch ME
    fprintf('[WARN] Lattice comparisons: %s\n', ME.message);
end

%% Step 4: Create drive comparison videos
fprintf('\n========== STEP 4: Creating drive comparison videos ==========\n');
try
    create_drive_comparison_videos;
    fprintf('[OK] Drive comparison videos complete\n');
catch ME
    fprintf('[WARN] Drive comparisons: %s\n', ME.message);
end

%% Summary
elapsed = toc(start_time);
fprintf('\n================================================\n');
fprintf('          ALL FIXES COMPLETE                    \n');
fprintf('================================================\n');
fprintf('Total time: %.1f minutes\n', elapsed/60);
fprintf('End time: %s\n\n', datestr(now));

fprintf('Next steps:\n');
fprintf('  1. Run analysis_viewer to browse analysis results\n');
fprintf('  2. Check "comparisons" folder for lattice comparisons\n');
fprintf('  3. Check "interesting videos/Comparisons" for drive videos\n');
fprintf('  4. Run interactive_simulation_viewer for simulation playback\n');
