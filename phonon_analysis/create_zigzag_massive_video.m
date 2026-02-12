%% create_zigzag_massive_video.m
% Creates ONE massive video showing ALL 20 zigzag frequencies
% 4x5 grid layout - all frequencies visible simultaneously
%
% Author: Gerbode Lab
% Date: 2026

clear; clc;

%% Add paths
addpath(genpath('Z:\Colloid Cru\Colloid Work Folder'));
addpath(genpath('Z:\Colloid Cru\Simulations'));

%% Configuration
batch_folder = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\drivensinesims';
simulations_folder = fullfile(batch_folder, 'simulations');
output_folder = fullfile(batch_folder, 'videos');

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% All 20 frequencies from the sweep
all_freqs = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...
             0.001, 0.0012, 0.0015, 0.0018, ...
             0.002, 0.0025, 0.003, 0.004, 0.005, ...
             0.007, 0.01, 0.02, 0.05, 0.10];

%% Video parameters
frame_rate = 30;
n_video_frames = 600;  % 20 seconds at 30fps
grid_rows = 4;
grid_cols = 5;

fprintf('============================================\n');
fprintf('Creating MASSIVE video with all 20 frequencies\n');
fprintf('Layout: %dx%d grid\n', grid_rows, grid_cols);
fprintf('============================================\n');

%% Find and load all simulation data
sim_data = cell(length(all_freqs), 1);
sim_params_all = cell(length(all_freqs), 1);

for i = 1:length(all_freqs)
    f = all_freqs(i);

    % Find simulation folder
    sim_name = sprintf('sinusoidal_f%.4f_a2.0', f);
    sim_path = fullfile(simulations_folder, sim_name);
    plist_file = fullfile(sim_path, 'plist.mat');

    if ~exist(plist_file, 'file')
        fprintf('  [SKIP] f=%.4f - not found\n', f);
        continue;
    end

    fprintf('  Loading f=%.4f...', f);

    % Load data
    loaded = load(plist_file);
    plist = loaded.plist;

    % Load parameters
    params_file = fullfile(sim_path, 'sim_params.mat');
    if exist(params_file, 'file')
        params = load(params_file);
        sim_params_all{i} = params.sim_params;
    else
        sim_params_all{i} = struct('width', 800, 'height', 400, ...
            'drive_frequency', f, 'drive_amplitude', 2.0, ...
            'data_saving_frequency', 10);
    end

    % Convert plist to xyz array
    frames = unique(plist(:, 4));
    n_frames = length(frames);
    n_particles = sum(plist(:, 4) == frames(1));

    xyz = zeros(n_particles, 3, n_frames);
    for ff = 1:n_frames
        frame_mask = plist(:, 4) == frames(ff);
        xyz(:, :, ff) = plist(frame_mask, 1:3);
    end

    sim_data{i} = xyz;
    fprintf(' %d frames\n', n_frames);
end

%% Check how many simulations we have
valid_indices = find(~cellfun(@isempty, sim_data));
n_valid = length(valid_indices);
fprintf('\nFound %d/%d simulations\n', n_valid, length(all_freqs));

if n_valid == 0
    error('No simulations found!');
end

%% Determine common frame count
frame_counts = zeros(n_valid, 1);
for i = 1:n_valid
    idx = valid_indices(i);
    frame_counts(i) = size(sim_data{idx}, 3);
end
common_frames = min(frame_counts);
fprintf('Using %d common frames across all simulations\n', common_frames);

%% Create video writer
video_path = fullfile(output_folder, 'zigzag_ALL_20freq_massive.mp4');
vw = VideoWriter(video_path, 'MPEG-4');
vw.FrameRate = frame_rate;
vw.Quality = 95;
open(vw);

%% Generate video frames
fprintf('Generating %d video frames...\n', n_video_frames);

% Figure setup - large format for 4x5 grid
fig = figure('Visible', 'off', 'Position', [50 50 1800 1000], 'Color', 'k');

tic;
for vf = 1:n_video_frames
    % Map video frame to simulation frame
    sim_frame = round((vf - 1) / (n_video_frames - 1) * (common_frames - 1)) + 1;

    clf(fig);

    % Create 4x5 subplot grid
    for i = 1:length(all_freqs)
        f = all_freqs(i);

        % Check if we have data for this frequency
        if isempty(sim_data{i})
            % Empty subplot for missing data
            ax = subplot(grid_rows, grid_cols, i);
            set(ax, 'Color', [0.1 0.1 0.1]);
            title(ax, sprintf('f=%.4f\n(no data)', f), 'Color', 'r', 'FontSize', 8);
            axis(ax, 'off');
            continue;
        end

        xyz = sim_data{i};
        params = sim_params_all{i};

        % Get particle positions
        x = xyz(:, 1, sim_frame);
        y = xyz(:, 2, sim_frame);
        z = xyz(:, 3, sim_frame);

        % Calculate drive phase
        data_freq = params.data_saving_frequency;
        actual_sim_frame = sim_frame * data_freq;
        drive_phase = params.drive_amplitude * sin(2 * pi * f * actual_sim_frame);

        % Create subplot
        ax = subplot(grid_rows, grid_cols, i);
        hold(ax, 'on');

        % Color by z (spin)
        z_norm = (z - min(z)) / (max(z) - min(z) + eps);
        colors = [z_norm, zeros(size(z_norm)), 1 - z_norm];

        scatter(ax, x, y, 4, colors, 'filled');  % Smaller particles for dense grid

        % Mark driven region (subtle)
        patch(ax, [0, 25, 25, 0], [0, 0, params.height, params.height], ...
              'g', 'FaceAlpha', 0.15, 'EdgeColor', 'none');

        % Drive position indicator
        drive_x = 12.5 + drive_phase;
        plot(ax, [drive_x, drive_x], [0, params.height], 'g-', 'LineWidth', 1.5);

        % Format subplot
        set(ax, 'Color', 'k', 'XColor', 'none', 'YColor', 'none');
        xlim(ax, [0, params.width]);
        ylim(ax, [0, params.height]);
        axis(ax, 'equal');
        axis(ax, 'tight');

        % Title with frequency - color code by frequency range
        if f < 0.002
            title_color = [0.5 0.8 1];  % Light blue for low freq
        elseif f < 0.01
            title_color = [1 1 0.5];    % Yellow for mid freq
        else
            title_color = [1 0.5 0.5];  % Red for high freq
        end
        title(ax, sprintf('f=%.4f', f), 'Color', title_color, 'FontSize', 8, 'FontWeight', 'bold');

        hold(ax, 'off');
    end

    % Add super title with frame info
    annotation(fig, 'textbox', [0.3, 0.94, 0.4, 0.05], ...
        'String', sprintf('ZIGZAG ALL FREQUENCIES | Frame %d/%d', sim_frame, common_frames), ...
        'Color', 'w', 'FontSize', 16, 'FontWeight', 'bold', ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center');

    % Add frequency legend
    annotation(fig, 'textbox', [0.02, 0.94, 0.25, 0.05], ...
        'String', 'Low freq | Mid freq | High freq', ...
        'Color', 'w', 'FontSize', 10, ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'left');

    % Capture frame
    frame_img = getframe(fig);
    writeVideo(vw, frame_img);

    % Progress
    if mod(vf, 50) == 0
        elapsed = toc;
        rate = vf / elapsed;
        remaining = (n_video_frames - vf) / rate;
        fprintf('  Frame %d/%d (%.1f fps, ~%.0fs remaining)\n', ...
            vf, n_video_frames, rate, remaining);
    end
end

close(vw);
close(fig);

fprintf('\n============================================\n');
fprintf('DONE! Massive video created:\n');
fprintf('  %s\n', video_path);
fprintf('\nShows all 20 frequencies in 4x5 grid\n');
fprintf('Color coding: Blue=low, Yellow=mid, Red=high freq\n');
fprintf('============================================\n');
