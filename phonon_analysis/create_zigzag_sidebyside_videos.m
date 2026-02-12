%% create_zigzag_sidebyside_videos.m
% Creates TWO companion videos showing all 20 zigzag frequencies
% Video 1: Low frequencies (0.0004 - 0.0018) - 10 frequencies in 2x5 grid
% Video 2: High frequencies (0.002 - 0.10) - 10 frequencies in 2x5 grid
% Display side by side for presentations!
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

%% Define frequency groups - Split into LOW and HIGH
% All 20 frequencies from the sweep
all_freqs = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...
             0.001, 0.0012, 0.0015, 0.0018, ...
             0.002, 0.0025, 0.003, 0.004, 0.005, ...
             0.007, 0.01, 0.02, 0.05, 0.10];

% Split into two groups of 10
low_freqs = all_freqs(1:10);   % 0.0004 to 0.0018
high_freqs = all_freqs(11:20); % 0.002 to 0.10

%% Video parameters
frame_rate = 30;
n_video_frames = 600;  % 20 seconds at 30fps
grid_rows = 2;
grid_cols = 5;

%% Generate both videos
for video_num = 1:2
    if video_num == 1
        target_freqs = low_freqs;
        video_name = 'zigzag_ALL_lowfreq.mp4';
        title_prefix = 'ZIGZAG LOW FREQ';
    else
        target_freqs = high_freqs;
        video_name = 'zigzag_ALL_highfreq.mp4';
        title_prefix = 'ZIGZAG HIGH FREQ';
    end

    fprintf('\n============================================\n');
    fprintf('Creating Video %d: %s\n', video_num, video_name);
    fprintf('Frequencies: %.4f to %.4f\n', min(target_freqs), max(target_freqs));
    fprintf('============================================\n');

    %% Find and load all simulation data for this group
    sim_data = cell(length(target_freqs), 1);
    sim_params_all = cell(length(target_freqs), 1);

    for i = 1:length(target_freqs)
        f = target_freqs(i);

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
    fprintf('\nFound %d/%d simulations\n', n_valid, length(target_freqs));

    if n_valid == 0
        fprintf('No simulations found for this group, skipping video.\n');
        continue;
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
    video_path = fullfile(output_folder, video_name);
    vw = VideoWriter(video_path, 'MPEG-4');
    vw.FrameRate = frame_rate;
    vw.Quality = 95;
    open(vw);

    %% Generate video frames
    fprintf('Generating %d video frames...\n', n_video_frames);

    % Figure setup - wide format for 2x5 grid
    fig = figure('Visible', 'off', 'Position', [50 50 1600 700], 'Color', 'k');

    % Compute global amplitude scale for consistent visualization
    global_max_x = 0;
    for i = 1:n_valid
        idx = valid_indices(i);
        x_range = max(sim_data{idx}(:, 1, :), [], 'all') - min(sim_data{idx}(:, 1, :), [], 'all');
        global_max_x = max(global_max_x, x_range);
    end

    tic;
    for vf = 1:n_video_frames
        % Map video frame to simulation frame
        sim_frame = round((vf - 1) / (n_video_frames - 1) * (common_frames - 1)) + 1;

        clf(fig);

        % Create 2x5 subplot grid
        for i = 1:n_valid
            idx = valid_indices(i);
            f = target_freqs(idx);
            xyz = sim_data{idx};
            params = sim_params_all{idx};

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

            scatter(ax, x, y, 8, colors, 'filled');

            % Mark driven region
            patch(ax, [0, 25, 25, 0], [0, 0, params.height, params.height], ...
                  'g', 'FaceAlpha', 0.2, 'EdgeColor', 'none');

            % Drive position indicator
            drive_x = 12.5 + drive_phase;
            plot(ax, [drive_x, drive_x], [0, params.height], 'g-', 'LineWidth', 2);

            % Format subplot
            set(ax, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
            xlim(ax, [0, params.width]);
            ylim(ax, [0, params.height]);
            axis(ax, 'equal');
            set(ax, 'XTick', [], 'YTick', []);

            % Title with frequency
            title(ax, sprintf('f=%.4f', f), 'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold');

            hold(ax, 'off');
        end

        % Add super title
        annotation(fig, 'textbox', [0.35, 0.92, 0.3, 0.06], ...
            'String', sprintf('%s | Frame %d/%d', title_prefix, sim_frame, common_frames), ...
            'Color', 'w', 'FontSize', 14, 'FontWeight', 'bold', ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'center');

        % Capture frame
        frame_img = getframe(fig);
        writeVideo(vw, frame_img);

        % Progress
        if mod(vf, 100) == 0
            elapsed = toc;
            rate = vf / elapsed;
            remaining = (n_video_frames - vf) / rate;
            fprintf('  Frame %d/%d (%.1f fps, ~%.0fs remaining)\n', ...
                vf, n_video_frames, rate, remaining);
        end
    end

    close(vw);
    close(fig);

    fprintf('Video saved: %s\n', video_path);
end

fprintf('\n============================================\n');
fprintf('DONE! Two videos created:\n');
fprintf('  1. zigzag_ALL_lowfreq.mp4  (f=0.0004 to 0.0018)\n');
fprintf('  2. zigzag_ALL_highfreq.mp4 (f=0.002 to 0.10)\n');
fprintf('\nOpen both side by side for full frequency comparison!\n');
fprintf('============================================\n');
