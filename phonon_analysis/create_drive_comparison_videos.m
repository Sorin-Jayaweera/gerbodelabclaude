%% create_drive_comparison_videos.m
% Creates comparison videos of top-driven vs side-driven simulations
% at f=0.003 for each lattice type (chevron, stripe, frustrated)
%
% Plots wavefront view: distance from driving on X, displacement on Y
% Both drive directions overlaid on the same plot to compare propagation
%
% This version searches multiple paths and can load from plist.mat if
% xyz_data.mat doesn't exist.

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
n_bins = 60;

%% Helper function to find and load xyz data
    function xyz = load_xyz_data(folder, sim_fmt, freq_val, base)
        % Try multiple paths and data formats
        sim_name = sprintf(sim_fmt, freq_val);
        paths_to_check = {
            fullfile(base, folder, sim_name);
            fullfile(base, folder, 'simulations', sim_name);
        };

        xyz = [];
        for p = 1:length(paths_to_check)
            sim_path = paths_to_check{p};

            % Try xyz_data.mat first
            xyz_path = fullfile(sim_path, 'xyz_data.mat');
            if exist(xyz_path, 'file')
                d = load(xyz_path);
                xyz = d.xyz;
                fprintf('    Loaded xyz_data.mat from: %s\n', sim_path);
                return;
            end

            % Try plist.mat and convert
            plist_path = fullfile(sim_path, 'plist.mat');
            if exist(plist_path, 'file')
                fprintf('    Converting plist.mat from: %s\n', sim_path);
                loaded = load(plist_path);
                if isfield(loaded, 'plist')
                    plist = loaded.plist;
                else
                    fn = fieldnames(loaded);
                    plist = loaded.(fn{1});
                end

                N_frames = length(plist);
                if N_frames > 0
                    if isstruct(plist)
                        N_particles = size(plist(1).pos, 1);
                        xyz = zeros(N_particles, 3, N_frames);
                        for t = 1:N_frames
                            xyz(:,:,t) = plist(t).pos;
                        end
                    else
                        N_particles = size(plist{1}, 1);
                        xyz = zeros(N_particles, 3, N_frames);
                        for t = 1:N_frames
                            xyz(:,:,t) = plist{t};
                        end
                    end
                    return;
                end
            end
        end
    end

%% Process each simulation type
for si = 1:length(sim_types)
    st = sim_types{si};
    fprintf('\n=== Processing %s ===\n', st.name);

    % Load side-driven data
    xyz_side = [];
    if ~isempty(st.side_folder)
        xyz_side = load_xyz_data(st.side_folder, st.side_fmt, freq, base_path);
    end
    has_side = ~isempty(xyz_side);

    % Load top-driven data
    xyz_top = [];
    if ~isempty(st.top_folder)
        xyz_top = load_xyz_data(st.top_folder, st.top_fmt, freq, base_path);
    end
    has_top = ~isempty(xyz_top);

    if ~has_side && ~has_top
        fprintf('  [SKIP] No data found for %s\n', st.name);
        continue;
    end

    % Get dimensions
    n_frames = inf;
    if has_side
        [N_side, ~, n_frames_side] = size(xyz_side);
        n_frames = min(n_frames, n_frames_side);
        W_side = max(xyz_side(:,1,1));
        axis_len_side = W_side;
        edges_side = linspace(0, axis_len_side, n_bins+1);
        fprintf('  Side: %d particles, %d frames\n', N_side, n_frames_side);
    else
        fprintf('  [NOTE] Side-driven data not found\n');
    end

    if has_top
        [N_top, ~, n_frames_top] = size(xyz_top);
        n_frames = min(n_frames, n_frames_top);
        H_top = max(xyz_top(:,2,1));
        axis_len_top = H_top;
        edges_top = linspace(0, axis_len_top, n_bins+1);
        fprintf('  Top: %d particles, %d frames\n', N_top, n_frames_top);
    else
        fprintf('  [NOTE] Top-driven data not found\n');
    end

    ctrs = linspace(0, 1, n_bins);
    fprintf('  Using %d frames\n', n_frames);

    % Create video
    output_file = fullfile(output_folder, sprintf('%s_comparison_f%.4f.mp4', st.name, freq));
    fprintf('  Creating video: %s\n', output_file);

    v = VideoWriter(output_file, 'MPEG-4');
    v.FrameRate = fps;
    v.Quality = 95;
    open(v);

    fig = figure('Position', [100 100 1200 600], 'Color', 'k', 'Visible', 'off');

    for fr = 1:n_frames
        clf(fig);
        y_max_vals = [0.5];

        % Side-driven wavefront
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

        % Top-driven wavefront
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

        % Plot comparison
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
        set(ax, 'Color', 'k', 'XColor', 'w', 'YColor', 'w', 'GridColor', [0.3 0.3 0.3]);
        grid(ax, 'on');
        xlim(ax, [0 1]);

        y_max = max(y_max_vals);
        ylim(ax, [-y_max*1.1, y_max*1.1]);

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
