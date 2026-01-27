%% run_dispersion_sweep.m
% Run sinusoidal driving simulations at multiple frequencies to map dispersion relation
%
% SCIENCE:
%   Each frequency f_drive produces waves with wavelength λ
%   This gives one point on dispersion: ω = 2πf, k = 2π/λ
%   By sweeping frequencies, we map the full ω(k) curve
%
% RECOMMENDATION:
%   Start with f=0.01 (already done), then run this sweep
%   Lower frequencies = longer wavelengths (easier to see)
%   Higher frequencies = shorter wavelengths (may be attenuated)
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% ==================== FREQUENCY SWEEP PARAMETERS ====================

% Frequencies to sweep (oscillations per data frame)
% Range from slow to fast oscillations
% Note: f=0.01 means 100 frames per oscillation cycle
%       f=0.05 means 20 frames per oscillation cycle
frequencies = [0.002, 0.005, 0.01, 0.02, 0.03, 0.05];

% You already ran f=0.01, so you can skip it:
% frequencies = [0.002, 0.005, 0.02, 0.03, 0.05];

% Common parameters for all simulations
drive_amplitude = 2.0;       % Pixels
drive_width = 25;            % Driven region width
num_frames = 20000;          % Frames per simulation
data_saving_frequency = 10;
image_saving_frequency = 1000;

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
fprintf('Estimated total time: %.1f hours (assuming ~30min each)\n', length(frequencies)*0.5);
fprintf('\n');

results = struct();
results.frequencies = frequencies;
results.wavelengths = zeros(size(frequencies));
results.amplitudes = zeros(size(frequencies));

for i = 1:length(frequencies)
    drive_frequency = frequencies(i);

    fprintf('\n----------------------------------------------\n');
    fprintf('Running frequency %d/%d: f = %.4f\n', i, length(frequencies), drive_frequency);
    fprintf('----------------------------------------------\n');

    sim_name = sprintf('sinusoidal_f%.4f_a%.1f', drive_frequency, drive_amplitude);

    % Check if already exists
    if exist(sim_name, 'dir')
        fprintf('  Folder %s already exists - SKIPPING\n', sim_name);
        fprintf('  (Delete folder to re-run)\n');
        continue;
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

    % Initialize crystal
    sim.initialize_grains_unfrust('zigzags');

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

        % Save data
        if mod(frame, data_saving_frequency) == 0
            data_frame = frame / data_saving_frequency;
            idx_start = (plist_row - 1) * num_particles + 1;
            idx_end = plist_row * num_particles;
            plist(idx_start:idx_end, :) = [sim.current_particles(:,1:3), ...
                                            data_frame * ones(num_particles, 1)];
            plist_row = plist_row + 1;
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

    save(fullfile(sim_name, 'sim_params.mat'), 'sim_params');
    save(fullfile(sim_name, 'sim.mat'), 'sim');

    fprintf('  Completed in %.1f minutes\n', toc/60);
    fprintf('  Saved to: %s\n', sim_name);
end

fprintf('\n==============================================\n');
fprintf('   SWEEP COMPLETE!\n');
fprintf('==============================================\n');
fprintf('Run analyze_dispersion_sweep.m to extract dispersion relation\n');
