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

%% ==================== FREQUENCY SWEEP PARAMETERS ====================

% Frequencies to sweep (oscillations per simulation frame)
% FULL OVERNIGHT RUN - 20 frequencies for dense dispersion curve (~10 hours)
% Note: f=0.01 means 100 frames per oscillation cycle
%       f=0.05 means 20 frames per oscillation cycle
%       Lower f = longer wavelength, easier to measure
%       Higher f = shorter wavelength, more attenuation

frequencies = [0.001, 0.002, 0.003, 0.004, 0.005, 0.006, 0.008, 0.01, ...
               0.012, 0.015, 0.018, 0.02, 0.025, 0.03, 0.04, 0.05, ...
               0.06, 0.07, 0.08, 0.10];

% 20 frequencies × ~30 min each = ~10 hours
% DELETE existing folders to re-run all:
%   In MATLAB: rmdir('sinusoidal_*', 's')  OR
%   Delete folders manually in Windows Explorer

% Common parameters for all simulations
drive_amplitude = 2.0;       % Pixels
drive_width = 25;            % Driven region width (pixels from left edge)
num_frames = 20000;          % Total frames per simulation
data_saving_frequency = 10;  % Save position data every N frames

% IMAGE SAVING PARAMETERS
num_initial_cycles = 3;              % Number of drive cycles to save at high frequency
images_per_cycle = 10;               % Images per cycle during initial phase
image_saving_frequency_late = 1000;  % Image frequency after initial cycles

% DOMAIN STRUCTURE
% Options: 'zigzags', 'stripes', 'random'
domain_style = 'zigzags';

% Crystal parameters
sim_width = 500;
sim_height = 300;
looseness = 1.06;
zmax = 0.45;

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
fprintf('Checking for completed simulations...\n');
completed_count = 0;
pending_indices = [];
for i = 1:length(frequencies)
    drive_frequency = frequencies(i);
    if strcmp(domain_style, 'zigzags')
        sim_name = sprintf('sinusoidal_f%.4f_a%.1f', drive_frequency, drive_amplitude);
    else
        sim_name = sprintf('sinusoidal_f%.4f_a%.1f_%s', drive_frequency, drive_amplitude, domain_style);
    end

    % Check if COMPLETE (has plist.mat = finished saving)
    plist_file = fullfile(sim_name, 'plist.mat');
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

    % Build simulation name including domain style
    if strcmp(domain_style, 'zigzags')
        sim_name = sprintf('sinusoidal_f%.4f_a%.1f', drive_frequency, drive_amplitude);
    else
        sim_name = sprintf('sinusoidal_f%.4f_a%.1f_%s', drive_frequency, drive_amplitude, domain_style);
    end

    % Double-check not complete (in case of race condition)
    if exist(fullfile(sim_name, 'plist.mat'), 'file')
        fprintf('  Already complete - SKIPPING\n');
        continue;
    end

    % Clean up partial runs (folder exists but no plist.mat)
    if exist(sim_name, 'dir')
        fprintf('  Removing incomplete folder %s...\n', sim_name);
        rmdir(sim_name, 's');
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

    % Identify driven particles
    driven_indices = sim.initial_particles(:,1) < drive_width;
    equilibrium_x = sim.initial_particles(driven_indices, 1);
    num_particles = size(sim.initial_particles, 1);

    fprintf('  Particles: %d total, %d driven\n', num_particles, sum(driven_indices));

    % Create output folder
    mkdir(sim_name);

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

        % Re-enforce drive
        sim.current_particles(driven_indices, 1) = equilibrium_x + drive_phase;

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

        %% IMAGE SAVING with two regimes
        save_image = false;
        is_initial_phase = (frame <= initial_phase_frames);

        if is_initial_phase
            % HIGH frequency saving during initial cycles
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
            saveas(fig, fullfile(sim_name, [filename_base '.png']));
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
    save(fullfile(sim_name, 'plist.mat'), 'plist', '-v7.3');

    sim_params = struct();
    sim_params.drive_frequency = drive_frequency;
    sim_params.drive_amplitude = drive_amplitude;
    sim_params.drive_width = drive_width;
    sim_params.driven_indices = driven_indices;
    sim_params.equilibrium_x = equilibrium_x;
    sim_params.width = sim_width;
    sim_params.height = sim_height;
    sim_params.looseness = looseness;
    sim_params.zmax = zmax;
    sim_params.num_frames = num_frames;
    sim_params.data_saving_frequency = data_saving_frequency;
    sim_params.domain_style = domain_style;
    sim_params.frames_per_cycle = frames_per_cycle;
    sim_params.initial_phase_frames = initial_phase_frames;

    save(fullfile(sim_name, 'sim_params.mat'), 'sim_params');
    save(fullfile(sim_name, 'sim.mat'), 'sim');

    fprintf('  Completed in %.1f minutes\n', toc/60);
    fprintf('  Saved to: %s\n', sim_name);
end

fprintf('\n==============================================\n');
fprintf('   SWEEP COMPLETE!\n');
fprintf('==============================================\n');
fprintf('Run analyze_dispersion_sweep.m to extract dispersion relation\n');
