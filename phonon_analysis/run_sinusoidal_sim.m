%% run_sinusoidal_sim.m
% Sinusoidal driving simulation for phonon dispersion measurement
%
% Instead of a single impulse, this continuously oscillates particles
% at the left edge at a specific frequency. This forces waves into the
% crystal and allows measurement of wavelength -> dispersion relation.
%
% SCIENCE:
%   - Drive left edge at frequency f_drive
%   - Waves propagate into crystal with wavelength λ
%   - Dispersion relation: ω = 2πf_drive, k = 2π/λ
%   - By varying f_drive, we map out ω(k)
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% ==================== SIMULATION PARAMETERS ====================

% Driving parameters
drive_frequency = 0.01;      % Oscillations per frame (try 0.001 to 0.1)
drive_amplitude = 2.0;       % Pixels (displacement amplitude)
drive_width = 25;            % Width of driven region (pixels from left edge)

% Simulation parameters
sim_width = 500;
sim_height = 300;
looseness = 1.06;
zmax = 0.45;

% Timing - need enough cycles to establish steady-state wave
num_frames = 20000;          % Total frames
data_saving_frequency = 10;  % Save every 10 frames
image_saving_frequency = 500;

% Output
sim_name = sprintf('sinusoidal_f%.4f_a%.1f', drive_frequency, drive_amplitude);

%% ==================== CREATE SIMULATION ====================
fprintf('Creating sinusoidal driving simulation...\n');
fprintf('  Drive frequency: %.4f oscillations/frame\n', drive_frequency);
fprintf('  Drive amplitude: %.1f pixels\n', drive_amplitude);
fprintf('  Drive width: %d pixels from left edge\n', drive_width);

% Initialize TDsim
sim = TDsim();
sim.width = sim_width;
sim.height = sim_height;
sim.looseness = looseness;
sim.zmax = zmax;
sim.data_saving_frequency = data_saving_frequency;
sim.image_saving_frequency = image_saving_frequency;
sim.num_frames = num_frames;

% Initialize crystal structure
sim.initialize_grains_unfrust('zigzags');

% Store the equilibrium positions of driven particles
driven_indices = sim.initial_particles(:,1) < drive_width;
equilibrium_x = sim.initial_particles(driven_indices, 1);
num_driven = sum(driven_indices);

fprintf('  Number of driven particles: %d\n', num_driven);
fprintf('  Expected data frames: %d\n', floor(num_frames/data_saving_frequency));

%% ==================== RUN WITH SINUSOIDAL DRIVING ====================
% We need to modify the simulation to apply sinusoidal driving.
% Since TDsim doesn't have built-in driving, we'll run in chunks
% and apply the drive between chunks.

fprintf('\nStarting simulation with sinusoidal driving...\n');

% Create output folder
mkdir(sim_name);

% Initialize plist storage
total_data_frames = floor(num_frames / data_saving_frequency);
num_particles = size(sim.initial_particles, 1);
plist = zeros(num_particles * total_data_frames, 4);
plist_row = 1;

% Set initial positions with drive offset at t=0
phase_0 = drive_amplitude * sin(2 * pi * drive_frequency * 0);
particles = sim.initial_particles;
particles(driven_indices, 1) = equilibrium_x + phase_0;
sim.initial_particles = particles;
sim.current_particles = particles;

% Build initial neighbor list
sim.neighbors = sim.getNeighbors(sim.cutoff_distance, 1, 8);
particlesFromNeighborList = sim.current_particles;

% Simulation loop with driving
tic;
for frame = 1:num_frames

    % Apply sinusoidal drive BEFORE collision resolution
    % This effectively makes the driven particles follow a prescribed motion
    drive_phase = drive_amplitude * sin(2 * pi * drive_frequency * frame);
    sim.current_particles(driven_indices, 1) = equilibrium_x + drive_phase;

    % Run one frame of simulation (Brownian motion + collisions)
    sim.simulateFrame();

    % Re-apply drive AFTER simulation to enforce driven boundary
    % This ensures driven particles stay on the sinusoidal trajectory
    sim.current_particles(driven_indices, 1) = equilibrium_x + drive_phase;

    % Update neighbor list if needed
    if any(sim.wraparoundDistancesTwoSets(sim.current_particles, particlesFromNeighborList) > sim.cutoff_distance - sim.particle_diam)
        sim.neighbors = sim.getNeighbors(sim.cutoff_distance, 1, 8);
        particlesFromNeighborList = sim.current_particles;
    end

    % Save data at specified frequency
    if mod(frame, data_saving_frequency) == 0
        data_frame = frame / data_saving_frequency;
        idx_start = (plist_row - 1) * num_particles + 1;
        idx_end = plist_row * num_particles;
        plist(idx_start:idx_end, :) = [sim.current_particles(:,1:3), ...
                                        data_frame * ones(num_particles, 1)];
        plist_row = plist_row + 1;
    end

    % Save images at specified frequency
    if mod(frame, image_saving_frequency) == 0
        filename = fullfile(sim_name, sprintf('%06d', frame));
        sim.makeSpinImage(sim.current_particles(:,1:3), filename);
        fprintf('Frame %d/%d (%.1f%%), elapsed: %.1fs\n', ...
            frame, num_frames, 100*frame/num_frames, toc);
    end

    % Update frame counter
    sim.current_frame = frame;
end

%% ==================== SAVE RESULTS ====================
fprintf('\nSaving results...\n');

% Trim plist to actual size
plist = plist(1:(plist_row-1)*num_particles, :);

% Save plist
save(fullfile(sim_name, 'plist.mat'), 'plist', '-v7.3');

% Save simulation parameters
sim_params = struct();
sim_params.drive_frequency = drive_frequency;
sim_params.drive_amplitude = drive_amplitude;
sim_params.drive_width = drive_width;
sim_params.num_driven = num_driven;
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

fprintf('Simulation complete!\n');
fprintf('Results saved to: %s\n', sim_name);
fprintf('  - plist.mat: particle positions (%d particles × %d frames)\n', ...
    num_particles, plist_row-1);
fprintf('  - sim_params.mat: simulation parameters\n');
fprintf('  - sim.mat: TDsim object\n');

%% ==================== QUICK VISUALIZATION ====================
fprintf('\nGenerating quick visualization...\n');

% Reshape plist to xyz format for quick look
frames_to_check = unique(plist(:,4));
n_frames = length(frames_to_check);

% Get positions for first and last few frames
figure('Position', [100, 100, 1200, 400]);

% Plot driven particle x-position over time
subplot(1,3,1);
% Find one driven particle and track it
test_particle = find(driven_indices, 1);
particle_frames = plist(plist(:,4) > 0, :);
% Extract x position of test particle across frames
x_driven = zeros(n_frames, 1);
for f = 1:n_frames
    frame_data = plist(plist(:,4) == f, :);
    if ~isempty(frame_data) && test_particle <= size(frame_data, 1)
        x_driven(f) = frame_data(test_particle, 1);
    end
end
plot(1:n_frames, x_driven, 'b-', 'LineWidth', 1);
xlabel('Data Frame');
ylabel('X position (pixels)');
title('Driven Particle Position');
grid on;

% Plot expected sinusoid
hold on;
expected = equilibrium_x(1) + drive_amplitude * sin(2*pi*drive_frequency*data_saving_frequency*(1:n_frames));
plot(1:n_frames, expected, 'r--', 'LineWidth', 1);
legend('Actual', 'Expected', 'Location', 'best');

% Plot a non-driven particle to see wave propagation
subplot(1,3,2);
% Find particle in middle of crystal
middle_x_idx = find(sim.initial_particles(:,1) > sim_width/2 & ...
                    sim.initial_particles(:,1) < sim_width/2 + 20, 1);
x_middle = zeros(n_frames, 1);
for f = 1:n_frames
    frame_data = plist(plist(:,4) == f, :);
    if ~isempty(frame_data) && middle_x_idx <= size(frame_data, 1)
        x_middle(f) = frame_data(middle_x_idx, 1);
    end
end
plot(1:n_frames, x_middle - mean(x_middle), 'g-', 'LineWidth', 1);
xlabel('Data Frame');
ylabel('X displacement (pixels)');
title('Middle Particle Response');
grid on;

% Power spectrum of middle particle
subplot(1,3,3);
if n_frames > 10
    x_detrend = x_middle - mean(x_middle);
    [pxx, f] = pwelch(x_detrend, [], [], [], 1);
    semilogy(f, pxx, 'k-', 'LineWidth', 1);
    hold on;
    xline(drive_frequency, 'r--', 'LineWidth', 2);
    xlabel('Frequency (1/frame)');
    ylabel('Power');
    title('Power Spectrum (middle particle)');
    legend('Measured', 'Drive freq', 'Location', 'best');
    grid on;
end

saveas(gcf, fullfile(sim_name, 'quick_check.png'));
fprintf('Quick check saved to: %s/quick_check.png\n', sim_name);
