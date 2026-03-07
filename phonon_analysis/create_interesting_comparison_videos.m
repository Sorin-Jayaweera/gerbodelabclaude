%% create_interesting_comparison_videos.m
% Creates comparison videos for analysis:
%
% 1. X vs Y drive comparisons (same lattice):
%    - chevron X vs chevron Y (topdriven)
%    - stripe X vs stripe Y (stripe_top)
%    - frust X vs frust Y
%
% 2. Cross-lattice comparisons (X-driven):
%    - stripe vs chevron
%    - stripe vs frust (frustrated zigzag)
%    - chevron vs random
%    - stripe vs random
%    - frust vs random
%
% Videos show wavefront profiles: X-displacement for X-driven, Y-displacement for Y-driven
% Output organized by frequency in "interesting videos" folder
%
% Author: Gerbode Lab
% Date: 2026

clear; close all; clc;

%% ==================== CONFIGURATION ====================
base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\sims';
output_base = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\interesting videos';

% Frequencies to create videos for
frequencies = [0.0005, 0.003, 0.01, 0.05];

% Video settings
fps = 30;
n_bins = 60;

% Simulation configurations
sim_configs = struct();

% X-driven simulations
sim_configs.chevron = struct('folder', 'drivensinesims', ...
    'fmt', 'sinusoidal_f%.4f_a2.0', 'drive', 'x', 'width', 800, 'height', 400);
sim_configs.stripe = struct('folder', 'stripesinesims', ...
    'fmt', 'sinusoidal_f%.4f_a2.0_stripes', 'drive', 'x', 'width', 800, 'height', 400);
sim_configs.frust = struct('folder', 'frustsinesims', ...
    'fmt', 'frust_f%.4f_a2.0', 'drive', 'x', 'width', 800, 'height', 400);
sim_configs.random = struct('folder', 'randomsinesims', ...
    'fmt', 'sinusoidal_f%.4f_a2.0_random', 'drive', 'x', 'width', 800, 'height', 400);

% Y-driven simulations
sim_configs.chevron_top = struct('folder', 'topdrivensims', ...
    'fmt', 'topdriven_f%.4f_a2.0', 'drive', 'y', 'width', 400, 'height', 800);
sim_configs.stripe_top = struct('folder', 'stripetopsims', ...
    'fmt', 'stripetop_f%.4f_a2.0', 'drive', 'y', 'width', 800, 'height', 400);
sim_configs.frust_top = struct('folder', 'frusttopsims', ...
    'fmt', 'frusttop_f%.4f_a2.0', 'drive', 'y', 'width', 400, 'height', 800);

% Define all comparisons to make
comparisons = {
    % X vs Y drive (same lattice)
    struct('name', 'chevron_Xdrive_vs_Ydrive', 'sim1', 'chevron', 'sim2', 'chevron_top', ...
           'label1', 'Chevron X-drive', 'label2', 'Chevron Y-drive', 'color1', [0.2 0.6 1.0], 'color2', [1.0 0.4 0.8]);
    struct('name', 'stripe_Xdrive_vs_Ydrive', 'sim1', 'stripe', 'sim2', 'stripe_top', ...
           'label1', 'Stripe X-drive', 'label2', 'Stripe Y-drive', 'color1', [0.2 0.6 1.0], 'color2', [1.0 0.4 0.8]);
    struct('name', 'frust_Xdrive_vs_Ydrive', 'sim1', 'frust', 'sim2', 'frust_top', ...
           'label1', 'Frust X-drive', 'label2', 'Frust Y-drive', 'color1', [1.0 0.7 0.2], 'color2', [0.2 0.9 0.9]);

    % Cross-lattice comparisons (X-driven)
    struct('name', 'stripe_vs_chevron', 'sim1', 'stripe', 'sim2', 'chevron', ...
           'label1', 'Stripe', 'label2', 'Chevron', 'color1', [0.2 0.8 0.2], 'color2', [0.2 0.6 1.0]);
    struct('name', 'stripe_vs_frust', 'sim1', 'stripe', 'sim2', 'frust', ...
           'label1', 'Stripe', 'label2', 'Frust Zigzag', 'color1', [0.2 0.8 0.2], 'color2', [1.0 0.7 0.2]);
    struct('name', 'chevron_vs_random', 'sim1', 'chevron', 'sim2', 'random', ...
           'label1', 'Chevron', 'label2', 'Random', 'color1', [0.2 0.6 1.0], 'color2', [0.7 0.7 0.7]);
    struct('name', 'stripe_vs_random', 'sim1', 'stripe', 'sim2', 'random', ...
           'label1', 'Stripe', 'label2', 'Random', 'color1', [0.2 0.8 0.2], 'color2', [0.7 0.7 0.7]);
    struct('name', 'frust_vs_random', 'sim1', 'frust', 'sim2', 'random', ...
           'label1', 'Frust Zigzag', 'label2', 'Random', 'color1', [1.0 0.7 0.2], 'color2', [0.7 0.7 0.7]);
};

%% ==================== HELPER FUNCTIONS ====================

function xyz = load_sim_data(base_path, config, freq)
    % Load simulation data, handling multiple formats
    sim_name = sprintf(config.fmt, freq);
    paths_to_check = {
        fullfile(base_path, config.folder, sim_name);
        fullfile(base_path, config.folder, 'simulations', sim_name);
    };

    xyz = [];
    for p = 1:length(paths_to_check)
        sim_path = paths_to_check{p};

        % Try xyz_data.mat first
        xyz_path = fullfile(sim_path, 'xyz_data.mat');
        if exist(xyz_path, 'file')
            try
                d = load(xyz_path);
                xyz = d.xyz;
                return;
            catch
                fprintf('WARNING: Corrupt xyz_data.mat in %s\n', sim_path);
                continue;
            end
        end

        % Try plist.mat and convert
        plist_path = fullfile(sim_path, 'plist.mat');
        if exist(plist_path, 'file')
            try
                loaded = load(plist_path);
            catch
                fprintf('WARNING: Corrupt plist.mat in %s\n', sim_path);
                continue;
            end
            if isfield(loaded, 'plist')
                plist = loaded.plist;
            else
                fn = fieldnames(loaded);
                plist = loaded.(fn{1});
            end

            % Handle different plist formats
            if isstruct(plist) && isfield(plist, 'pos')
                N_frames = length(plist);
                N_particles = size(plist(1).pos, 1);
                xyz = zeros(N_particles, 3, N_frames);
                for t = 1:N_frames
                    xyz(:,:,t) = plist(t).pos;
                end
            elseif iscell(plist)
                N_frames = length(plist);
                N_particles = size(plist{1}, 1);
                xyz = zeros(N_particles, 3, N_frames);
                for t = 1:N_frames
                    xyz(:,:,t) = plist{t};
                end
            elseif isnumeric(plist) && size(plist, 2) >= 4
                % Matrix format [x, y, z, frame_id]
                frame_col = plist(:, 4);
                all_frame_ids = unique(frame_col);
                N_frames = length(all_frame_ids);
                first_frame_mask = (frame_col == all_frame_ids(1));
                N_particles = sum(first_frame_mask);
                xyz = zeros(N_particles, 3, N_frames);
                for t = 1:N_frames
                    mask = (frame_col == all_frame_ids(t));
                    frame_data = plist(mask, 1:3);
                    n_use = min(size(frame_data, 1), N_particles);
                    xyz(1:n_use, :, t) = frame_data(1:n_use, :);
                end
            elseif isnumeric(plist) && ndims(plist) == 3
                xyz = plist;
            end
            if ~isempty(xyz)
                return;
            end
        end
    end
end

function [profile, ctrs_out] = compute_wavefront(xyz, frame, axis_len, use_y, n_bins, n_eq)
    % Compute binned displacement profile
    % Returns profile and bin centers as "distance from drive"
    % For Y-driven sims, flips so drive (at high Y) appears at position 0
    if nargin < 6, n_eq = 10; end

    n_frames = size(xyz, 3);
    n_eq = min(n_eq, n_frames);
    frame = min(frame, n_frames);

    edges = linspace(0, axis_len, n_bins+1);
    ctrs = (edges(1:end-1) + edges(2:end)) / 2;

    if use_y
        pos = xyz(:,2,frame);
        pos0 = mean(xyz(:,2,1:n_eq), 3);
    else
        pos = xyz(:,1,frame);
        pos0 = mean(xyz(:,1,1:n_eq), 3);
    end
    dpos = pos - pos0;

    % Bin and average
    bin_idx = discretize(pos0, edges);
    profile = zeros(n_bins, 1);
    for b = 1:n_bins
        mask = (bin_idx == b);
        if any(mask)
            profile(b) = mean(dpos(mask));
        end
    end

    % For Y-driven sims, drive is at HIGH Y, so compute distance from drive
    % and flip both centers and profile so drive appears at x=0
    if use_y
        % distance from drive = axis_len - Y_position
        % flip so ascending: [near drive, ..., far from drive]
        ctrs_out = flip(axis_len - ctrs);
        profile = flip(profile);
    else
        ctrs_out = ctrs;  % X-driven: low X is drive, already correct
    end
end

%% ==================== MAIN PROCESSING ====================
fprintf('============================================\n');
fprintf('   CREATING INTERESTING COMPARISON VIDEOS\n');
fprintf('============================================\n');
fprintf('Frequencies: %s\n', mat2str(frequencies));
fprintf('Comparisons: %d types\n', length(comparisons));
fprintf('Output: %s\n', output_base);
fprintf('\n');

total_videos = 0;
skipped_videos = 0;

for fi = 1:length(frequencies)
    freq = frequencies(fi);
    freq_str = sprintf('f%.4f', freq);
    freq_folder = fullfile(output_base, freq_str);

    fprintf('\n=== Frequency: %.4f ===\n', freq);

    % Create frequency folder
    if ~exist(freq_folder, 'dir')
        mkdir(freq_folder);
    end

    for ci = 1:length(comparisons)
        comp = comparisons{ci};

        fprintf('  %s vs %s... ', comp.label1, comp.label2);

        % Check if video already exists
        video_name = sprintf('%s_%s.mp4', comp.name, freq_str);
        video_path = fullfile(freq_folder, video_name);

        % Load data for both simulations
        config1 = sim_configs.(comp.sim1);
        config2 = sim_configs.(comp.sim2);

        xyz1 = load_sim_data(base_path, config1, freq);
        xyz2 = load_sim_data(base_path, config2, freq);

        if isempty(xyz1)
            fprintf('SKIP (no data for %s)\n', comp.sim1);
            skipped_videos = skipped_videos + 1;
            continue;
        end
        if isempty(xyz2)
            fprintf('SKIP (no data for %s)\n', comp.sim2);
            skipped_videos = skipped_videos + 1;
            continue;
        end

        % Determine axis lengths and displacement axes
        use_y1 = strcmp(config1.drive, 'y');
        use_y2 = strcmp(config2.drive, 'y');

        if use_y1
            axis_len1 = config1.height;
        else
            axis_len1 = config1.width;
        end
        if use_y2
            axis_len2 = config2.height;
        else
            axis_len2 = config2.width;
        end

        % Use minimum frames
        n_frames1 = size(xyz1, 3);
        n_frames2 = size(xyz2, 3);
        n_frames = min(n_frames1, n_frames2);

        fprintf('creating video (%d frames)... ', n_frames);

        % Create figure
        fig = figure('Position', [100 100 1200 600], 'Color', 'k', 'Visible', 'off');

        % Create video writer
        vw = VideoWriter(video_path, 'MPEG-4');
        vw.FrameRate = fps;
        vw.Quality = 95;
        open(vw);

        % Compute global y-limits from first 100 frames
        % Start with drive amplitude (2.0 px) as minimum to ensure drive is visible
        sample_frames = min(100, n_frames);
        max_disp = 2.5;  % Drive amplitude is 2.0, add margin
        for sf = 1:sample_frames
            [p1, ~] = compute_wavefront(xyz1, sf, axis_len1, use_y1, n_bins);
            [p2, ~] = compute_wavefront(xyz2, sf, axis_len2, use_y2, n_bins);
            max_disp = max([max_disp, max(abs(p1)), max(abs(p2))]);
        end
        y_lim = [-max_disp*1.1, max_disp*1.1];

        % Generate frames
        for fr = 1:n_frames
            clf(fig);
            ax = axes(fig, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
            hold(ax, 'on');

            % Compute wavefront profiles
            [profile1, x1] = compute_wavefront(xyz1, fr, axis_len1, use_y1, n_bins);
            [profile2, x2] = compute_wavefront(xyz2, fr, axis_len2, use_y2, n_bins);

            % Normalize x-axis to "distance from drive" (0 to 1)
            x1_norm = x1 / axis_len1;
            x2_norm = x2 / axis_len2;

            % Plot both profiles
            plot(ax, x1_norm * 800, profile1, '-', 'LineWidth', 2.5, 'Color', comp.color1);
            plot(ax, x2_norm * 800, profile2, '-', 'LineWidth', 2.5, 'Color', comp.color2);

            % Reference line
            yline(ax, 0, '--', 'Color', [0.5 0.5 0.5]);

            % Labels and formatting
            xlim(ax, [0 800]);
            ylim(ax, y_lim);
            xlabel(ax, 'Distance from drive (px)', 'Color', 'w', 'FontSize', 12);
            ylabel(ax, 'Displacement (px)', 'Color', 'w', 'FontSize', 12);

            % Title with frame info
            title(ax, sprintf('f=%.4f | Frame %d/%d', freq, fr, n_frames), ...
                'Color', 'w', 'FontSize', 14);

            % Legend
            legend(ax, {sprintf('%s (disp %s)', comp.label1, upper(config1.drive)), ...
                        sprintf('%s (disp %s)', comp.label2, upper(config2.drive))}, ...
                'Location', 'northeast', 'TextColor', 'w', 'Color', [0.2 0.2 0.2], ...
                'FontSize', 11);

            set(ax, 'FontSize', 11);

            % Capture frame with consistent size
            frame_img = getframe(fig);
            frame_data = frame_img.cdata;

            % On first frame, store expected size
            if fr == 1
                expected_size = size(frame_data);
            else
                % Resize if size changed (can happen with MATLAB rendering)
                if ~isequal(size(frame_data), expected_size)
                    frame_data = imresize(frame_data, [expected_size(1), expected_size(2)]);
                end
            end
            writeVideo(vw, frame_data);

            % Progress
            if mod(fr, 500) == 0
                fprintf('%d/%d... ', fr, n_frames);
            end
        end

        close(vw);
        close(fig);

        fprintf('DONE\n');
        total_videos = total_videos + 1;

        % Memory cleanup
        clearvars xyz1 xyz2;
    end
end

fprintf('\n============================================\n');
fprintf('COMPARISON VIDEOS COMPLETE!\n');
fprintf('Created: %d videos\n', total_videos);
fprintf('Skipped: %d (missing data)\n', skipped_videos);
fprintf('Output: %s\n', output_base);
fprintf('============================================\n');
