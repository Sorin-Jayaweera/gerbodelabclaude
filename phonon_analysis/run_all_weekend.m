%% run_all_weekend.m
% MASTER RUN FILE - Run all simulations and analysis overnight/weekend
%
% This script:
%   1. Runs all pending simulations (stripe, random, top-driven, controls)
%   2. Runs all analysis for each domain type
%   3. Compares domain types
%   4. Generates summary figures
%
% PROGRESS TRACKING:
%   - Writes to 'progress.txt' after each step
%   - Check progress.txt to see where it crashed
%   - Set START_FROM_STEP to resume from a specific step
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% ==================== CONFIGURATION ====================
% Set this to resume from a specific step (1 = start from beginning)
START_FROM_STEP = 1;

% Base paths
base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
progress_file = fullfile(base_path, 'progress.txt');

% Add all required paths
addpath(genpath('Z:\Colloid Cru\Colloid Work Folder'));
addpath(genpath('Z:\Colloid Cru\Simulations'));
addpath(genpath(fullfile(base_path, 'phonon_analysis')));

%% ==================== TASK LIST ====================
% Each task is: {step_number, task_name, function_handle}
tasks = {
    % SIMULATIONS
    1,  'Stripe domain sweep (20 frequencies)',      @task_stripe_sweep;
    2,  'Random domain sweep (20 frequencies)',      @task_random_sweep;
    3,  'Top-driven zigzag sweep (20 frequencies)', @task_topdriven_sweep;
    4,  'Zigzag no-drive control',                   @task_zigzag_nodrive;
    5,  'Stripe no-drive control',                   @task_stripe_nodrive;

    % ANALYSIS - Zigzag (X-driven)
    6,  'Analyze zigzag dispersion',                 @() task_analyze_dispersion('drivensinesims', 'zigzag');
    7,  'Analyze zigzag frequency response',         @() task_analyze_freq_response('drivensinesims', 'zigzag');

    % ANALYSIS - Stripe (X-driven)
    8,  'Analyze stripe dispersion',                 @() task_analyze_dispersion('stripesinesims', 'stripe');
    9,  'Analyze stripe frequency response',         @() task_analyze_freq_response('stripesinesims', 'stripe');

    % ANALYSIS - Random (X-driven)
    10, 'Analyze random dispersion',                 @() task_analyze_dispersion('randomsinesims', 'random');
    11, 'Analyze random frequency response',         @() task_analyze_freq_response('randomsinesims', 'random');

    % ANALYSIS - Top-driven zigzag (Y-driven)
    12, 'Analyze top-driven dispersion',             @() task_analyze_dispersion('topdrivensims', 'topdriven');
    13, 'Analyze top-driven frequency response',     @() task_analyze_freq_response('topdrivensims', 'topdriven');

    % ANALYSIS - Controls
    14, 'Analyze control simulations (noise floor)', @task_analyze_controls;

    % COMPARISONS
    15, 'Compare zigzag vs stripe vs random',        @task_compare_domains;
    16, 'Compare X-drive vs Y-drive (zigzag)',       @task_compare_drive_directions;

    % SUMMARY
    17, 'Generate summary figures',                  @task_generate_summary;
};

%% ==================== HELPER FUNCTIONS ====================

function log_progress(progress_file, step, task_name, status, message)
    % Write progress to file
    timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    fid = fopen(progress_file, 'a');
    fprintf(fid, '[%s] Step %02d: %s - %s', timestamp, step, task_name, status);
    if nargin > 4 && ~isempty(message)
        fprintf(fid, ' (%s)', message);
    end
    fprintf(fid, '\n');
    fclose(fid);

    % Also print to console
    fprintf('[%s] Step %02d: %s - %s\n', timestamp, step, task_name, status);
end

%% ==================== MAIN EXECUTION LOOP ====================

fprintf('============================================\n');
fprintf('   WEEKEND RUN - ALL SIMULATIONS & ANALYSIS\n');
fprintf('============================================\n');
fprintf('Start time: %s\n', datestr(now));
fprintf('Progress file: %s\n', progress_file);
fprintf('Starting from step: %d\n\n', START_FROM_STEP);

% Initialize progress file if starting fresh
if START_FROM_STEP == 1
    fid = fopen(progress_file, 'w');
    fprintf(fid, '========================================\n');
    fprintf(fid, 'WEEKEND RUN STARTED: %s\n', datestr(now));
    fprintf(fid, '========================================\n\n');
    fclose(fid);
end

% Run each task
total_tasks = size(tasks, 1);
completed = 0;
failed = 0;

for i = 1:total_tasks
    step = tasks{i, 1};
    task_name = tasks{i, 2};
    task_func = tasks{i, 3};

    % Skip if before start step
    if step < START_FROM_STEP
        fprintf('Skipping step %d (before START_FROM_STEP)\n', step);
        continue;
    end

    % Log start
    log_progress(progress_file, step, task_name, 'STARTING', '');

    try
        tic;

        % Execute the task
        task_func();

        elapsed = toc;
        elapsed_str = sprintf('%.1f min', elapsed/60);
        log_progress(progress_file, step, task_name, 'COMPLETED', elapsed_str);
        completed = completed + 1;

        % Memory cleanup between tasks
        clearvars -except tasks progress_file START_FROM_STEP base_path total_tasks completed failed i;
        close all force;
        pause(2);

    catch ME
        elapsed = toc;
        error_msg = sprintf('%s (line %d)', ME.message, ME.stack(1).line);
        log_progress(progress_file, step, task_name, 'FAILED', error_msg);

        % Log full error to progress file
        fid = fopen(progress_file, 'a');
        fprintf(fid, '  ERROR DETAILS:\n');
        fprintf(fid, '    Message: %s\n', ME.message);
        fprintf(fid, '    Identifier: %s\n', ME.identifier);
        for s = 1:length(ME.stack)
            fprintf(fid, '    Stack[%d]: %s line %d\n', s, ME.stack(s).name, ME.stack(s).line);
        end
        fprintf(fid, '\n');
        fclose(fid);

        failed = failed + 1;

        % Continue to next task instead of stopping
        fprintf('  Continuing to next task...\n\n');
    end
end

%% ==================== FINAL SUMMARY ====================
fprintf('\n============================================\n');
fprintf('   RUN COMPLETE\n');
fprintf('============================================\n');
fprintf('End time: %s\n', datestr(now));
fprintf('Completed: %d/%d tasks\n', completed, total_tasks);
fprintf('Failed: %d tasks\n', failed);
fprintf('Progress file: %s\n', progress_file);

% Write final summary to progress file
fid = fopen(progress_file, 'a');
fprintf(fid, '\n========================================\n');
fprintf(fid, 'RUN COMPLETED: %s\n', datestr(now));
fprintf(fid, 'Completed: %d/%d tasks\n', completed, total_tasks);
fprintf(fid, 'Failed: %d tasks\n', failed);
fprintf(fid, '========================================\n');
fclose(fid);


%% ==================== TASK FUNCTIONS ====================

function task_stripe_sweep()
    run_stripe_domain_sweep;
end

function task_random_sweep()
    run_random_domain_sweep;
end

function task_topdriven_sweep()
    run_topdriven_zigzag_sweep;
end

function task_zigzag_nodrive()
    run_zigzag_nodrive;
end

function task_stripe_nodrive()
    run_stripe_nodrive;
end

function task_analyze_dispersion(batch_name, domain_type)
    % Analyze dispersion relation for a given batch
    fprintf('  Analyzing dispersion for %s...\n', domain_type);

    base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
    batch_folder = fullfile(base_path, batch_name);

    % Call the analysis script with modified batch folder
    analyze_dispersion_for_batch(batch_folder, domain_type);
end

function task_analyze_freq_response(batch_name, domain_type)
    % Analyze frequency response for a given batch
    fprintf('  Analyzing frequency response for %s...\n', domain_type);

    base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
    batch_folder = fullfile(base_path, batch_name);

    % Call the analysis script with modified batch folder
    analyze_freq_response_for_batch(batch_folder, domain_type);
end

function task_analyze_controls()
    % Analyze no-drive control simulations
    fprintf('  Analyzing control simulations...\n');

    base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
    control_folder = fullfile(base_path, 'controlsims', 'simulations');
    output_folder = fullfile(base_path, 'controlsims', 'analysis');

    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
    end

    % Analyze zigzag control
    zigzag_path = fullfile(control_folder, 'zigzag_nodrive_control');
    if exist(fullfile(zigzag_path, 'plist.mat'), 'file')
        analyze_noise_floor(zigzag_path, fullfile(output_folder, 'zigzag_noise'));
    end

    % Analyze stripe control
    stripe_path = fullfile(control_folder, 'stripe_nodrive_control');
    if exist(fullfile(stripe_path, 'plist.mat'), 'file')
        analyze_noise_floor(stripe_path, fullfile(output_folder, 'stripe_noise'));
    end
end

function task_compare_domains()
    % Compare zigzag, stripe, and random domain results
    fprintf('  Comparing domain types...\n');

    base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
    output_folder = fullfile(base_path, 'comparison_results');

    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
    end

    compare_domain_dispersions(base_path, output_folder);
end

function task_compare_drive_directions()
    % Compare X-driven vs Y-driven zigzag
    fprintf('  Comparing drive directions...\n');

    base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
    output_folder = fullfile(base_path, 'comparison_results');

    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
    end

    compare_drive_directions(base_path, output_folder);
end

function task_generate_summary()
    % Generate summary figures combining all results
    fprintf('  Generating summary figures...\n');

    base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
    output_folder = fullfile(base_path, 'summary_figures');

    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
    end

    generate_summary_figures(base_path, output_folder);
end
