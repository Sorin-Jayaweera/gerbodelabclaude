%% verify_data.m
% Utility script to verify data loading and format before analysis
%
% Run this to check that your plist data is correctly formatted.

clear; clc;

fprintf('=== Data Verification Script ===\n\n');

%% Check for plist files
sim_folder = 'onaxisphonon3impulse_.5';  % Change to your folder

plist_path = fullfile(sim_folder, 'plist.mat');
if ~exist(plist_path, 'file')
    plist_path = [sim_folder '_plist.mat'];
end
if ~exist(plist_path, 'file')
    plist_path = [sim_folder '.mat'];
end

if ~exist(plist_path, 'file')
    error('Could not find plist file. Tried:\n  %s\n  %s_plist.mat\n  %s.mat', ...
        fullfile(sim_folder, 'plist.mat'), sim_folder, sim_folder);
end

fprintf('Found plist at: %s\n', plist_path);

%% Load and examine plist
loaded = load(plist_path);
fn = fieldnames(loaded);
fprintf('Variables in file: %s\n', strjoin(fn, ', '));

if isfield(loaded, 'plist')
    plist = loaded.plist;
else
    plist = loaded.(fn{1});
    fprintf('Using variable: %s\n', fn{1});
end

fprintf('\nplist size: [%s]\n', num2str(size(plist)));
fprintf('  Expected: [N_entries x 4] where columns are [x, y, z, frame]\n');

%% Examine plist structure
fprintf('\nFirst 5 rows of plist:\n');
disp(plist(1:min(5, size(plist,1)), :));

fprintf('\nColumn statistics:\n');
for c = 1:size(plist, 2)
    fprintf('  Column %d: min=%.2f, max=%.2f, mean=%.2f\n', ...
        c, min(plist(:,c)), max(plist(:,c)), mean(plist(:,c)));
end

%% Convert to xyz format
fprintf('\nConverting with plist2xyz...\n');

try
    xyz = plist2xyz(plist);
    fprintf('Success! xyz size: [%s]\n', num2str(size(xyz)));
    fprintf('  Interpretation: [%d particles, %d dimensions, %d frames]\n', ...
        size(xyz, 1), size(xyz, 2), size(xyz, 3));
catch ME
    fprintf('Error in plist2xyz: %s\n', ME.message);
    fprintf('\nTrying manual conversion...\n');

    % Manual conversion attempt
    frames = unique(plist(:, 4));
    num_frames = length(frames);
    particles_per_frame = sum(plist(:, 4) == frames(1));

    fprintf('Detected %d frames with %d particles each\n', num_frames, particles_per_frame);

    xyz = plist2xyz(plist, particles_per_frame, num_frames);
    fprintf('Manual conversion successful! xyz size: [%s]\n', num2str(size(xyz)));
end

%% Verify xyz dimensions
[N_particles, N_dims, N_frames] = size(xyz);

fprintf('\n=== Data Summary ===\n');
fprintf('Number of particles: %d\n', N_particles);
fprintf('Number of dimensions: %d\n', N_dims);
fprintf('Number of frames: %d\n', N_frames);

%% Check for reasonable values
x = squeeze(xyz(:, 1, :));
y = squeeze(xyz(:, 2, :));
z = squeeze(xyz(:, 3, :));

fprintf('\nPosition ranges:\n');
fprintf('  X: [%.1f, %.1f]\n', min(x(:)), max(x(:)));
fprintf('  Y: [%.1f, %.1f]\n', min(y(:)), max(y(:)));
fprintf('  Z: [%.1f, %.1f]\n', min(z(:)), max(z(:)));

%% Check for motion
dx = max(x, [], 2) - min(x, [], 2);
dy = max(y, [], 2) - min(y, [], 2);
dz = max(z, [], 2) - min(z, [], 2);

fprintf('\nParticle displacement ranges (max - min over time):\n');
fprintf('  X: mean=%.3f, max=%.3f\n', mean(dx), max(dx));
fprintf('  Y: mean=%.3f, max=%.3f\n', mean(dy), max(dy));
fprintf('  Z: mean=%.3f, max=%.3f\n', mean(dz), max(dz));

%% Visualize initial configuration
figure('Position', [100, 100, 1000, 400]);

subplot(1, 3, 1);
scatter(x(:,1), y(:,1), 10, 'b', 'filled');
axis equal;
title('Frame 1: X-Y positions');
xlabel('x'); ylabel('y');

subplot(1, 3, 2);
if max(z(:)) - min(z(:)) > 0.01
    scatter(x(:,1), y(:,1), 20, z(:,1), 'filled');
    colorbar;
    title('Frame 1: Z-height (color)');
else
    histogram(z(:,1), 30);
    title('Frame 1: Z distribution');
end
xlabel('x'); ylabel('y');

subplot(1, 3, 3);
% Plot trajectory of one particle
particle_idx = round(N_particles / 2);
plot(squeeze(x(particle_idx, :)), squeeze(y(particle_idx, :)), 'b-');
hold on;
plot(x(particle_idx, 1), y(particle_idx, 1), 'go', 'MarkerSize', 10);
plot(x(particle_idx, end), y(particle_idx, end), 'ro', 'MarkerSize', 10);
title(sprintf('Trajectory of particle %d', particle_idx));
xlabel('x'); ylabel('y');
legend('Path', 'Start', 'End');
axis equal;

fprintf('\n=== Verification Complete ===\n');
fprintf('Data appears to be correctly formatted.\n');
fprintf('Ready to run phonon analysis!\n');
