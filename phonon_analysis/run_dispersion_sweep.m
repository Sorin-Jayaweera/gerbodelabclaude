%% run_dispersion_sweep.m
% Run sinusoidal driving simulations at multiple frequencies to map dispersion relation
%
% SCIENCE:
%   Each frequency f_drive produces waves with wavelength λ
%   This gives one point on dispersion: ω = 2πf, k = 2π/λ
%   By sweeping frequencies, we map the full ω(k) curve
%
% IMAGE SAVING:
%   - First few drive cycles: HIGH frequency saving (every few frames)
%     -> Green title on images, to verify forcing is working
%   - After initial cycles: LOW frequency saving (every 1000 frames)
%     -> White title on images
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% ==================== ADD PATHS ====================
addpath('Z:\Colloid Cru\Colloid Work Folder');
addpath('Z:\Colloid Cru\Simulations');

%% ==================== BATCH FOLDER SETUP ====================
% All simulations for this batch go into a named folder with:
%   - simulations/  (contains each sinusoidal_f*_a* subfolder)
%   - analysis/     (for results from analyze_dispersion_sweep.m)
%   - description.txt (auto-generated setup documentation)

batch_name = 'drivensinesims';  % Name of this batch experiment
batch_base = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
batch_folder = fullfile(batch_base, batch_name);
simulations_folder = fullfile(batch_folder, 'simulations');
analysis_folder = fullfile(batch_folder, 'analysis');

%% ==================== FREQUENCY SWEEP PARAMETERS ====================

% Frequencies to sweep (oscillations per simulation frame)
% EXPANDED with MORE LOW frequencies for longer wavelength modes
% Note: f=0.01 means 100 frames per oscillation cycle
%       f=0.001 means 1000 frames per cycle
%       f=0.0005 means 2000 frames per cycle (very slow!)
%       Lower f = longer wavelength, clearer wave propagation
%
% FOCUS: Dense sampling in 5e-4 to 3e-3 range as requested

frequencies = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...   % Very low
               0.001, 0.0012, 0.0015, 0.0018, ...                     % Low
               0.002, 0.0025, 0.003, 0.004, 0.005, ...                % Low-mid
               0.007, 0.01, 0.02, 0.05, 0.10];                        % Higher (fewer)

% 20 frequencies × ~30 min each = ~10 hours
% DELETE existing simulation folders to re-run all

% Common parameters for all simulations
drive_amplitude = 2.0;       % Pixels
drive_width = 25;            % Driven region width (pixels from left edge)
fixed_width = 25;            % Fixed region width (pixels from right edge) - ABSORBING BC
num_frames = 30000;          % Total frames per simulation (increased for low freq)
data_saving_frequency = 10;  % Save position data every N frames

% IMAGE SAVING PARAMETERS
% Set high_freq_images_throughout = true to save images at high rate for entire sim
% WARNING: This creates MANY more images but allows detailed animation viewing
high_freq_images_throughout = true;   % <<< SET TO TRUE FOR DETAILED MOVIES
num_initial_cycles = 3;               % Number of drive cycles to save at high frequency (if not throughout)
images_per_cycle = 20;                % Images per cycle (every 0.05 cycles)
image_saving_frequency_late = 1000;   % Image frequency after initial cycles (ignored if high_freq_throughout)

% DOMAIN STRUCTURE
% Options: 'zigzags', 'stripes', 'random'
domain_style = 'zigzags';

% Crystal parameters - INCREASED SIZE for better wave propagation
sim_width = 800;   % Increased from 500 for longer propagation distance
sim_height = 400;  % Increased from 300 for more particles
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

% Write description file
description_file = fullfile(batch_folder, 'description.txt');
fid = fopen(description_file, 'w');
fprintf(fid, 'BATCH SIMULATION: %s\n', batch_name);
fprintf(fid, '==========================================\n\n');
fprintf(fid, 'PURPOSE:\n');
fprintf(fid, '  Sinusoidal boundary driving at multiple frequencies to measure\n');
fprintf(fid, '  phonon dispersion relation omega(k) in colloidal crystal.\n\n');
fprintf(fid, 'DRIVING PARAMETERS:\n');
fprintf(fid, '  Drive amplitude: %.1f pixels\n', drive_amplitude);
fprintf(fid, '  Drive width: %d pixels from left edge\n', drive_width);
fprintf(fid, '  Fixed width: %d pixels from right edge (absorbing BC)\n', fixed_width);
fprintf(fid, '  Frequencies: %s\n', mat2str(frequencies, 4));
fprintf(fid, '  Number of frequencies: %d\n\n', length(frequencies));
fprintf(fid, 'CRYSTAL PARAMETERS:\n');
fprintf(fid, '  Domain style: %s\n', domain_style);
fprintf(fid, '  Simulation size: %d x %d pixels\n', sim_width, sim_height);
fprintf(fid, '  Looseness: %.3f\n', looseness);
fprintf(fid, '  Zmax: %.3f\n\n', zmax);
fprintf(fid, 'SIMULATION PARAMETERS:\n');
fprintf(fid, '  Total frames per frequency: %d\n', num_frames);
fprintf(fid, '  Data saving frequency: every %d frames\n', data_saving_frequency);
fprintf(fid, '  Initial high-freq image saving: %d cycles, %d images/cycle\n', num_initial_cycles, images_per_cycle);
fprintf(fid, '  Late image saving: every %d frames\n\n', image_saving_frequency_late);
fprintf(fid, 'FOLDER STRUCTURE:\n');
fprintf(fid, '  simulations/   - Raw simulation output (.mat, images)\n');
fprintf(fid, '  analysis/      - Analysis results and figures\n\n');
fprintf(fid, 'DATE STARTED: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fclose(fid);
fprintf('Batch folder: %s\n', batch_folder);
fprintf('Description written to: description.txt\n\n');

%% ==================== RUN SWEEP ====================
fprintf('==============================================\n');
fprintf('   DISPERSION RELATION FREQUENCY SWEEP\n');
fprintf('==============================================\n');
fprintf('Frequencies to run: %s\n', mat2str(frequencies));
fprintf('Domain structure: %s\n', domain_style);
fprintf('Initial high-freq saving: %d cycles, %d images/cycle\n', num_initial_cycles, images_per_cycle);
fprintf('Estimated total time: %.1f hours (assuming ~30min each)\n', length(frequencies)*0.5);
fprintf('\n');

results = struct();
results.frequencies = frequencies;
results.wavelengths = zeros(size(frequencies));
results.amplitudes = zeros(size(frequencies));

%% Pre-scan: Check which simulations are already complete
fprintf('Checking for completed simulations in: %s\n', simulations_folder);
completed_count = 0;
pending_indices = [];
for i = 1:length(frequencies)
    drive_frequency = frequencies(i);
    if strcmp(domain_style, 'zigzags')
        sim_name = sprintf('sinusoidal_f%.4f_a%.1f', drive_frequency, drive_amplitude);
    else
        sim_name = sprintf('sinusoidal_f%.4f_a%.1f_%s', drive_frequency, drive_amplitude, domain_style);
    end

    % Check if COMPLETE (has plist.mat = finished saving) - USE FULL PATH
    sim_full_path = fullfile(simulations_folder, sim_name);
    plist_file = fullfile(sim_full_path, 'plist.mat');
    if exist(plist_file, 'file')
        fprintf('  [DONE] f=%.4f (%s)\n', drive_frequency, sim_name);
        completed_count = completed_count + 1;
    else
        fprintf('  [TODO] f=%.4f\n', drive_frequency);
        pending_indices(end+1) = i;
    end
end

fprintf('\n%d/%d complete, %d remaining\n', completed_count, length(frequencies), length(pending_indices));
if isempty(pending_indices)
    fprintf('All simulations complete! Run analyze_dispersion_sweep.m\n');
    return;
end

remaining_time = length(pending_indices) * 0.5;
fprintf('Estimated time for remaining: %.1f hours\n', remaining_time);
fprintf('Starting in 3 seconds... (Ctrl+C to cancel)\n');
pause(3);

%% Run pending simulations
for idx = 1:length(pending_indices)
    i = pending_indices(idx);
    drive_frequency = frequencies(i);

    % Calculate imaging schedule for this frequency
    frames_per_cycle = round(1 / drive_frequency);  % Frames for one complete oscillation
    initial_phase_frames = num_initial_cycles * frames_per_cycle;
    image_freq_initial = max(1, round(frames_per_cycle / images_per_cycle));

    fprintf('\n----------------------------------------------\n');
    fprintf('Running frequency %d/%d (pending %d/%d): f = %.4f\n', i, length(frequencies), idx, length(pending_indices), drive_frequency);
    fprintf('  Period: %d frames/cycle\n', frames_per_cycle);
    fprintf('  Initial phase: %d frames (%.0f cycles)\n', initial_phase_frames, num_initial_cycles);
    fprintf('  Image freq (initial): every %d frames\n', image_freq_initial);
    fprintf('  Image freq (late): every %d frames\n', image_saving_frequency_late);
    fprintf('----------------------------------------------\n');

    % Build simulation name and FULL PATH including domain style
    if strcmp(domain_style, 'zigzags')
        sim_name = sprintf('sinusoidal_f%.4f_a%.1f', drive_frequency, drive_amplitude);
    else
        sim_name = sprintf('sinusoidal_f%.4f_a%.1f_%s', drive_frequency, drive_amplitude, domain_style);
    end
    sim_full_path = fullfile(simulations_folder, sim_name);  % SAVE TO SIMULATIONS FOLDER

    % Double-check not complete (in case of race condition)
    if exist(fullfile(sim_full_path, 'plist.mat'), 'file')
        fprintf('  Already complete - SKIPPING\n');
        continue;
    end

    % Clean up partial runs (folder exists but no plist.mat)
    if exist(sim_full_path, 'dir')
        fprintf('  Removing incomplete folder %s...\n', sim_name);
        rmdir(sim_full_path, 's');
    end

    %% Initialize simulation
    sim = TDsim();
    sim.width = sim_width;
    sim.height = sim_height;
    sim.looseness = looseness;
    sim.zmax = zmax;
    sim.data_saving_frequency = data_saving_frequency;
    sim.image_saving_frequency = image_saving_frequency_late;  % Default (overridden below)
    sim.num_frames = num_frames;

    % Initialize crystal with specified domain structure
    if strcmp(domain_style, 'random')
        sim.initialize_grains_unfrust('random');
    elseif strcmp(domain_style, 'stripes')
        sim.initialize_grains_unfrust('stripes');
    else
        sim.initialize_grains_unfrust('zigzags');
    end

    % Identify driven particles (LEFT edge - sinusoidal motion)
    driven_indices = sim.initial_particles(:,1) < drive_width;
    equilibrium_x = sim.initial_particles(driven_indices, 1);

    % Identify FIXED particles (RIGHT edge - held stationary to prevent wraparound)
    fixed_indices = sim.initial_particles(:,1) > (sim_width - fixed_width);
    fixed_equilibrium_x = sim.initial_particles(fixed_indices, 1);
    fixed_equilibrium_y = sim.initial_particles(fixed_indices, 2);

    num_particles = size(sim.initial_particles, 1);

    fprintf('  Particles: %d total, %d driven (left), %d fixed (right)\n', ...
            num_particles, sum(driven_indices), sum(fixed_indices));

    % Create output folder
    mkdir(sim_full_path);

    % Initialize storage
    total_data_frames = floor(num_frames / data_saving_frequency);
    plist = zeros(num_particles * total_data_frames, 4);
    plist_row = 1;

    % Set initial drive position
    particles = sim.initial_particles;
    particles(driven_indices, 1) = equilibrium_x + drive_amplitude * sin(0);
    sim.initial_particles = particles;
    sim.current_particles = particles;

    % Build neighbor list
    sim.neighbors = sim.getNeighbors(sim.cutoff_distance, 1, 8);
    particlesFromNeighborList = sim.current_particles;

    %% Run simulation with driving
    tic;
    for frame = 1:num_frames
        % Apply sinusoidal drive
        drive_phase = drive_amplitude * sin(2 * pi * drive_frequency * frame);
        sim.current_particles(driven_indices, 1) = equilibrium_x + drive_phase;

        % Simulate frame
        sim.simulateFrame();

        % Re-enforce drive (left boundary - sinusoidal)
        sim.current_particles(driven_indices, 1) = equilibrium_x + drive_phase;

        % Re-enforce FIXED boundary (right boundary - stationary)
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

        %% IMAGE SAVING
        save_image = false;
        is_initial_phase = (frame <= initial_phase_frames);

        if high_freq_images_throughout
            % HIGH frequency saving throughout entire simulation
            if mod(frame, image_freq_initial) == 0
                save_image = true;
            end
        elseif is_initial_phase
            % HIGH frequency saving during initial cycles only
            if mod(frame, image_freq_initial) == 0
                save_image = true;
            end
        else
            % LOW frequency saving after initial cycles
            if mod(frame, image_saving_frequency_late) == 0
                save_image = true;
            end
        end

        if save_image
            % Calculate time info
            cycle_number = frame / frames_per_cycle;
            phase_in_cycle = mod(frame, frames_per_cycle) / frames_per_cycle * 360;  % degrees
            current_drive_pos = drive_phase;

            % Create filename with time info
            filename_base = sprintf('%06d_cyc%.2f_phase%03.0f', frame, cycle_number, phase_in_cycle);

            % Generate image
            img = sim.makeSpinImage(sim.current_particles(:,1:3), ' ');  % Don't save yet

            % Add title with time info
            fig = figure('Visible', 'off', 'Position', [100 100 800 500]);
            imshow(img);
            hold on;

            % Title color: GREEN for initial phase, WHITE for late phase
            if is_initial_phase
                title_color = [0 0.8 0];  % Green
                phase_label = 'INITIAL (verifying drive)';
            else
                title_color = [1 1 1];    % White
                phase_label = 'LATE';
            end

            title_str = sprintf('f=%.4f | Frame %d | Cycle %.2f | Phase %.0f° | Drive: %.2f px | %s', ...
                drive_frequency, frame, cycle_number, phase_in_cycle, current_drive_pos, phase_label);
            title(title_str, 'Color', title_color, 'FontSize', 12, 'FontWeight', 'bold');

            % Mark driven region with a line
            plot([drive_width drive_width], [0 sim_height], 'g--', 'LineWidth', 2);
            text(drive_width + 5, 20, 'Driven boundary', 'Color', 'g', 'FontSize', 10);

            % Save
            saveas(fig, fullfile(sim_full_path, [filename_base '.png']));
            close(fig);
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
    sim_params.drive_width = drive_width;
    sim_params.driven_indices = driven_indices;
    sim_params.equilibrium_x = equilibrium_x;
    sim_params.fixed_width = fixed_width;
    sim_params.fixed_indices = fixed_indices;
    sim_params.fixed_equilibrium_x = fixed_equilibrium_x;
    sim_params.fixed_equilibrium_y = fixed_equilibrium_y;
    sim_params.width = sim_width;
    sim_params.height = sim_height;
    sim_params.looseness = looseness;
    sim_params.zmax = zmax;
    sim_params.num_frames = num_frames;
    sim_params.data_saving_frequency = data_saving_frequency;
    sim_params.domain_style = domain_style;
    sim_params.frames_per_cycle = frames_per_cycle;
    sim_params.initial_phase_frames = initial_phase_frames;

    save(fullfile(sim_full_path, 'sim_params.mat'), 'sim_params');
    save(fullfile(sim_full_path, 'sim.mat'), 'sim');

    fprintf('  Completed in %.1f minutes\n', toc/60);
    fprintf('  Saved to: %s\n', sim_full_path);
end

fprintf('\n==============================================\n');
fprintf('   SWEEP COMPLETE!\n');
fprintf('==============================================\n');
fprintf('Run analyze_dispersion_sweep.m to extract dispersion relation\n');
