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
% Folder names and formats must match run_full_analysis.m experiments
sim_types = {
    struct('name', 'chevron', ...
           'side_folder', 'drivensinesims', ...
           'side_fmt', 'sinusoidal_f%.4f_a2.0', ...
           'top_folder', 'topdrivensims', ...
           'top_fmt', 'topdriven_f%.4f_a2.0');
    struct('name', 'stripe', ...
           'side_folder', 'stripesinesims', ...
           'side_fmt', 'sinusoidal_f%.4f_a2.0_stripes', ...
           'top_folder', '', ...
           'top_fmt', '');  % No top-driven stripe sims
    struct('name', 'frustrated', ...
           'side_folder', 'frustsinesims', ...
           'side_fmt', 'frust_f%.4f_a2.0', ...
           'top_folder', 'frusttopsims', ...
           'top_fmt', 'frusttop_f%.4f_a2.0');
};

% Video settings
fps = 30;
n_bins = 60;  % Number of position bins for wavefront

%% Process each simulation type
for si = 1:length(sim_types)
    st = sim_types{si};
    fprintf('\n=== Processing %s ===\n', st.name);

    % Build paths
    side_path = fullfile(base_path, st.side_folder, sprintf(st.side_fmt, freq), 'xyz_data.mat');
    if ~isempty(st.top_folder)
        top_path = fullfile(base_path, st.top_folder, sprintf(st.top_fmt, freq), 'xyz_data.mat');
    else
        top_path = '';
    end

    % Check if at least one exists
    has_side = exist(side_path, 'file');
    has_top = ~isempty(top_path) && exist(top_path, 'file');

    if ~has_side && ~has_top
        fprintf('  [SKIP] No data found for %s\n', st.name);
        if ~has_side, fprintf('    Side: %s\n', side_path); end
        if ~isempty(top_path) && ~has_top, fprintf('    Top: %s\n', top_path); end
        continue;
    end
    if ~has_side
        fprintf('  [NOTE] Side-driven data not found, showing top-driven only\n');
    end
    if ~has_top
        fprintf('  [NOTE] Top-driven data not found, showing side-driven only\n');
    end

    % Load available data
    n_frames = inf;

    if has_side
        fprintf('  Loading side-driven: %s\n', side_path);
        side_data = load(side_path);
        xyz_side = side_data.xyz;
        [N_side, ~, n_frames_side] = size(xyz_side);
        n_frames = min(n_frames, n_frames_side);
        W_side = max(xyz_side(:,1,1));
        axis_len_side = W_side;
        edges_side = linspace(0, axis_len_side, n_bins+1);
        fprintf('  Side: %d particles, %d frames\n', N_side, n_frames_side);
    end

    if has_top
        fprintf('  Loading top-driven: %s\n', top_path);
        top_data = load(top_path);
        xyz_top = top_data.xyz;
        [N_top, ~, n_frames_top] = size(xyz_top);
        n_frames = min(n_frames, n_frames_top);
        H_top = max(xyz_top(:,2,1));
        axis_len_top = H_top;
        edges_top = linspace(0, axis_len_top, n_bins+1);
        fprintf('  Top: %d particles, %d frames\n', N_top, n_frames_top);
    end

    ctrs = linspace(0, 1, n_bins);  % Normalized centers for comparison
    fprintf('  Using %d frames\n', n_frames);

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

        y_max_vals = [0.5];  % minimum scale

        % === Side-driven wavefront ===
        bin_mean_side = zeros(n_bins, 1);
        if has_side
            x_side = xyz_side(:,1,fr);
            dx_side = xyz_side(:,1,fr) - xyz_side(:,1,1);
            [~, ~, bin_side] = histcounts(x_side, edges_side);
            for b = 1:n_bins
                in_bin = (bin_side == b);
                if any(in_bin)
                    bin_mean_side(b) = mean(dx_side(in_bin));
                end
            end
            y_max_vals(end+1) = max(abs(bin_mean_side(:)));
        end

        % === Top-driven wavefront ===
        bin_mean_top = zeros(n_bins, 1);
        if has_top
            y_top = xyz_top(:,2,fr);
            dy_top = xyz_top(:,2,fr) - xyz_top(:,2,1);
            dist_from_top = H_top - y_top;
            [~, ~, bin_top] = histcounts(dist_from_top, edges_top);
            for b = 1:n_bins
                in_bin = (bin_top == b);
                if any(in_bin)
                    bin_mean_top(b) = mean(dy_top(in_bin));
                end
            end
            y_max_vals(end+1) = max(abs(bin_mean_top(:)));
        end

        % === Plot comparison ===
        ax = axes(fig, 'Position', [0.1 0.15 0.85 0.75]);
        hold(ax, 'on');

        if has_side
            plot(ax, ctrs, bin_mean_side, 'c-', 'LineWidth', 2, 'DisplayName', 'Side-driven (X disp)');
        end
        if has_top
            plot(ax, ctrs, bin_mean_top, 'r-', 'LineWidth', 2, 'DisplayName', 'Top-driven (Y disp)');
        end

        xlabel(ax, 'Normalized Distance from Drive', 'Color', 'w', 'FontSize', 12);
        ylabel(ax, 'Mean Displacement (px)', 'Color', 'w', 'FontSize', 12);
        title(ax, sprintf('%s: Side vs Top Driven | f=%.4f | Frame %d/%d', ...
            upper(st.name), freq, fr, n_frames), 'Color', 'w', 'FontSize', 14);

        legend(ax, 'Location', 'northeast', 'TextColor', 'w', 'Color', [0.2 0.2 0.2]);

        % Styling
        set(ax, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'GridColor', [0.3 0.3 0.3]);
        grid(ax, 'on');
        xlim(ax, [0 1]);

        % Auto-scale Y but keep symmetric around 0
        y_max = max(y_max_vals);
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
