function generate_images_from_plist(sim_folder, output_folder, options)
%% generate_images_from_plist - Generate visualization images from saved plist data
%
% Usage:
%   generate_images_from_plist(sim_folder)
%   generate_images_from_plist(sim_folder, output_folder)
%   generate_images_from_plist(sim_folder, output_folder, options)
%
% Inputs:
%   sim_folder    - Path to simulation folder containing plist.mat
%   output_folder - Where to save images (default: sim_folder/generated_images)
%   options       - Struct with optional parameters:
%                   .frame_skip    - Only save every Nth frame (default: 1)
%                   .show_progress - Display progress bar (default: true)
%                   .particle_size - Size of particles in pixels (default: 10)
%
% This function loads the saved trajectory data and generates images
% that can be viewed as a video to see wave propagation.

%% Parse inputs
if nargin < 2 || isempty(output_folder)
    output_folder = fullfile(sim_folder, 'generated_images');
end
if nargin < 3
    options = struct();
end

% Default options
if ~isfield(options, 'frame_skip'), options.frame_skip = 1; end
if ~isfield(options, 'show_progress'), options.show_progress = true; end
if ~isfield(options, 'particle_size'), options.particle_size = 10; end

%% Load simulation data
plist_file = fullfile(sim_folder, 'plist.mat');
params_file = fullfile(sim_folder, 'sim_params.mat');

if ~exist(plist_file, 'file')
    error('plist.mat not found in %s', sim_folder);
end

fprintf('Loading data from %s...\n', sim_folder);
loaded = load(plist_file);
plist = loaded.plist;

% Load simulation parameters
if exist(params_file, 'file')
    params = load(params_file);
    sim_params = params.sim_params;
    box_width = sim_params.width;
    box_height = sim_params.height;
    drive_freq = sim_params.drive_frequency;
    drive_amp = sim_params.drive_amplitude;
    drive_width = sim_params.drive_width;
    if isfield(sim_params, 'fixed_width')
        fixed_width = sim_params.fixed_width;
    else
        fixed_width = 0;
    end
    data_saving_freq = sim_params.data_saving_frequency;
else
    % Defaults
    box_width = 800;
    box_height = 400;
    drive_freq = 0.01;
    drive_amp = 2.0;
    drive_width = 25;
    fixed_width = 25;
    data_saving_freq = 10;
    warning('sim_params.mat not found, using defaults');
end

%% Convert plist to xyz array
% plist format: [x, y, z, frame] for each particle at each frame
frames = unique(plist(:, 4));
n_frames = length(frames);
n_particles = sum(plist(:, 4) == frames(1));

fprintf('Data: %d particles, %d frames\n', n_particles, n_frames);

% Reshape to xyz array [particles, 3, frames]
xyz = zeros(n_particles, 3, n_frames);
for f = 1:n_frames
    frame_mask = plist(:, 4) == frames(f);
    xyz(:, :, f) = plist(frame_mask, 1:3);
end

%% Create output folder
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
    fprintf('Created output folder: %s\n', output_folder);
end

%% Generate images
fprintf('Generating %d images...\n', ceil(n_frames / options.frame_skip));

% Figure setup (invisible for speed)
fig = figure('Visible', 'off', 'Position', [100 100 1200 600], 'Color', 'k');

% Precompute some values
particle_radius = options.particle_size / 2;
frames_per_cycle = round(1 / drive_freq);

% Progress tracking
tic;
images_saved = 0;

for f = 1:options.frame_skip:n_frames
    % Get particle positions for this frame
    x = xyz(:, 1, f);
    y = xyz(:, 2, f);
    z = xyz(:, 3, f);  % Spin/height

    % Calculate simulation frame number and drive phase
    sim_frame = f * data_saving_freq;
    cycle_number = sim_frame / frames_per_cycle;
    phase_degrees = mod(sim_frame, frames_per_cycle) / frames_per_cycle * 360;
    drive_position = drive_amp * sin(2 * pi * drive_freq * sim_frame);

    % Clear figure
    clf(fig);

    % Create visualization
    ax = axes(fig);
    hold(ax, 'on');

    % Color particles by z (spin) - blue for down, red for up
    % Normalize z to [0, 1] for colormap
    z_norm = (z - min(z)) / (max(z) - min(z) + eps);
    colors = [z_norm, zeros(size(z_norm)), 1 - z_norm];  % Blue to red

    % Draw particles as circles
    scatter(ax, x, y, particle_radius^2 * 4, colors, 'filled');

    % Mark driven region
    patch(ax, [0, drive_width, drive_width, 0], [0, 0, box_height, box_height], ...
          'g', 'FaceAlpha', 0.15, 'EdgeColor', 'g', 'LineWidth', 2);

    % Mark fixed region (if exists)
    if fixed_width > 0
        patch(ax, [box_width - fixed_width, box_width, box_width, box_width - fixed_width], ...
              [0, 0, box_height, box_height], ...
              'r', 'FaceAlpha', 0.15, 'EdgeColor', 'r', 'LineWidth', 2);
    end

    % Add drive position indicator (green bar showing current displacement)
    drive_x = drive_width/2 + drive_position;
    plot(ax, [drive_x, drive_x], [0, box_height], 'g-', 'LineWidth', 3);

    % Formatting
    set(ax, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
    xlim(ax, [0, box_width]);
    ylim(ax, [0, box_height]);
    axis(ax, 'equal');

    % Title with timing info
    title_str = sprintf('f=%.4f | Frame %d/%d | Cycle %.2f | Phase %.0f° | Drive: %.2f px', ...
        drive_freq, f, n_frames, cycle_number, phase_degrees, drive_position);
    title(ax, title_str, 'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold');

    % Labels
    xlabel(ax, 'X (pixels)', 'Color', 'w');
    ylabel(ax, 'Y (pixels)', 'Color', 'w');

    % Add legend
    text(ax, box_width - 120, box_height - 20, 'Driven', 'Color', 'g', 'FontSize', 10);
    if fixed_width > 0
        text(ax, box_width - 120, box_height - 40, 'Fixed', 'Color', 'r', 'FontSize', 10);
    end

    hold(ax, 'off');

    % Save image
    filename = sprintf('frame_%06d.png', f);
    saveas(fig, fullfile(output_folder, filename));
    images_saved = images_saved + 1;

    % Progress update
    if options.show_progress && mod(images_saved, 100) == 0
        elapsed = toc;
        rate = images_saved / elapsed;
        remaining = (ceil(n_frames / options.frame_skip) - images_saved) / rate;
        fprintf('  Saved %d images (%.1f/sec, ~%.0fs remaining)\n', ...
            images_saved, rate, remaining);
    end
end

close(fig);

elapsed = toc;
fprintf('Done! Saved %d images in %.1f seconds (%.1f images/sec)\n', ...
    images_saved, elapsed, images_saved / elapsed);
fprintf('Images saved to: %s\n', output_folder);

end
