%% create_drive_comparison_videos.m
% Creates comparison videos of top-driven vs side-driven simulations
% at f=0.003 for each lattice type (zigzag, stripe, chevron)
%
% Plots wavefront view: distance from driving on X, displacement on Y
% Both drive directions overlaid on the same plot to compare propagation

clear; close all; clc;

%% Configuration
base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\sims';
output_folder = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\interesting videos\Comparisons';

% Create output folder if needed
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% Frequency to analyze
freq = 0.003;

% Simulation types to compare
sim_types = {
    % name, side_folder, side_fmt, top_folder, top_fmt
    struct('name', 'zigzag', ...
           'side_folder', 'sidedriven', ...
           'side_fmt', 'sinusoidal_f%.4f_a2.0', ...
           'top_folder', 'topdriven', ...
           'top_fmt', 'sinusoidal_f%.4f_a2.0_top');
    struct('name', 'stripe', ...
           'side_folder', 'stripesinesims', ...
           'side_fmt', 'sinusoidal_f%.4f_a2.0_stripes', ...
           'top_folder', 'stripetopdrivensims', ...
           'top_fmt', 'sinusoidal_f%.4f_a2.0_stripes_top');
    struct('name', 'chevron', ...
           'side_folder', 'drivensinesims', ...
           'side_fmt', 'sinusoidal_f%.4f_a2.0', ...
           'top_folder', 'chevrontopdrivensims', ...
           'top_fmt', 'sinusoidal_f%.4f_a2.0_chevron_top');
};

% Video settings
fps = 30;
n_bins = 60;  % Number of position bins for wavefront

%% Process each simulation type
for si = 1:length(sim_types)
    st = sim_types{si};
    fprintf('\n=== Processing %s ===\n', st.name);

    % Load side-driven data
    side_path = fullfile(base_path, st.side_folder, sprintf(st.side_fmt, freq), 'xyz_data.mat');
    top_path = fullfile(base_path, st.top_folder, sprintf(st.top_fmt, freq), 'xyz_data.mat');

    % Check if both files exist
    if ~exist(side_path, 'file')
        fprintf('  [SKIP] Side-driven data not found: %s\n', side_path);
        continue;
    end
    if ~exist(top_path, 'file')
        fprintf('  [SKIP] Top-driven data not found: %s\n', top_path);
        continue;
    end

    fprintf('  Loading side-driven: %s\n', side_path);
    side_data = load(side_path);
    xyz_side = side_data.xyz;
    [N_side, ~, n_frames_side] = size(xyz_side);

    fprintf('  Loading top-driven: %s\n', top_path);
    top_data = load(top_path);
    xyz_top = top_data.xyz;
    [N_top, ~, n_frames_top] = size(xyz_top);

    % Use minimum number of frames
    n_frames = min(n_frames_side, n_frames_top);
    fprintf('  Particles: side=%d, top=%d | Frames: %d\n', N_side, N_top, n_frames);

    % Get axis lengths
    W_side = max(xyz_side(:,1,1));
    H_side = max(xyz_side(:,2,1));
    W_top = max(xyz_top(:,1,1));
    H_top = max(xyz_top(:,2,1));

    % For side-driven: distance from left edge (X), displacement in X direction
    % For top-driven: distance from top edge (Y), displacement in Y direction
    % We'll normalize both to compare

    axis_len_side = W_side;  % Side driven: X is distance
    axis_len_top = H_top;    % Top driven: Y is distance (from top)

    % Set up binning
    edges_side = linspace(0, axis_len_side, n_bins+1);
    edges_top = linspace(0, axis_len_top, n_bins+1);
    ctrs = linspace(0, 1, n_bins);  % Normalized centers for comparison

    % Create video
    output_file = fullfile(output_folder, sprintf('%s_comparison_f%.4f.mp4', st.name, freq));
    fprintf('  Creating video: %s\n', output_file);

    v = VideoWriter(output_file, 'MPEG-4');
    v.FrameRate = fps;
    v.Quality = 95;
    open(v);

    % Create figure
    fig = figure('Position', [100 100 1200 600], 'Color', 'k', 'Visible', 'off');

    for fr = 1:n_frames
        clf(fig);

        % === Side-driven wavefront ===
        x_side = xyz_side(:,1,fr);
        dx_side = xyz_side(:,1,fr) - xyz_side(:,1,1);  % X displacement

        % Bin by X position
        [~, ~, bin_side] = histcounts(x_side, edges_side);
        bin_mean_side = zeros(n_bins, 1);
        for b = 1:n_bins
            in_bin = (bin_side == b);
            if any(in_bin)
                bin_mean_side(b) = mean(dx_side(in_bin));
            end
        end

        % === Top-driven wavefront ===
        y_top = xyz_top(:,2,fr);
        dy_top = xyz_top(:,2,fr) - xyz_top(:,2,1);  % Y displacement

        % Distance from TOP (flip so top = 0)
        dist_from_top = H_top - y_top;

        % Bin by distance from top
        [~, ~, bin_top] = histcounts(dist_from_top, edges_top);
        bin_mean_top = zeros(n_bins, 1);
        for b = 1:n_bins
            in_bin = (bin_top == b);
            if any(in_bin)
                bin_mean_top(b) = mean(dy_top(in_bin));
            end
        end

        % === Plot comparison ===
        ax = axes(fig, 'Position', [0.1 0.15 0.85 0.75]);
        hold(ax, 'on');

        plot(ax, ctrs, bin_mean_side, 'c-', 'LineWidth', 2, 'DisplayName', 'Side-driven (X disp)');
        plot(ax, ctrs, bin_mean_top, 'r-', 'LineWidth', 2, 'DisplayName', 'Top-driven (Y disp)');

        xlabel(ax, 'Normalized Distance from Drive', 'Color', 'w', 'FontSize', 12);
        ylabel(ax, 'Mean Displacement (px)', 'Color', 'w', 'FontSize', 12);
        title(ax, sprintf('%s: Side vs Top Driven | f=%.4f | Frame %d/%d', ...
            upper(st.name), freq, fr, n_frames), 'Color', 'w', 'FontSize', 14);

        legend(ax, 'Location', 'northeast', 'TextColor', 'w', 'Color', [0.2 0.2 0.2]);

        % Styling
        set(ax, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'GridColor', [0.3 0.3 0.3]);
        grid(ax, 'on');
        xlim(ax, [0 1]);

        % Auto-scale Y but keep symmetric around 0 and consistent
        y_max = max([max(abs(bin_mean_side(:))), max(abs(bin_mean_top(:))), 0.5]);
        ylim(ax, [-y_max*1.1, y_max*1.1]);

        % Capture frame
        drawnow;
        frame_img = getframe(fig);
        writeVideo(v, frame_img);

        if mod(fr, 500) == 0
            fprintf('    Frame %d/%d\n', fr, n_frames);
        end
    end

    close(v);
    close(fig);
    fprintf('  Done! Saved: %s\n', output_file);
end

fprintf('\n=== All comparison videos created ===\n');
