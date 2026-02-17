function interactive_simulation_viewer()
%% INTERACTIVE_SIMULATION_VIEWER
% Multi-panel viewer for comparing simulations across domain types
%
% Features:
%   - Frequency slider to select which frequency to view
%   - View modes: Wavefront profile, Kymograph, Particle positions
%   - Playback controls: Play, Pause, Step, Speed
%   - Side-by-side comparison of zigzag, stripe, random, topdriven
%
% Author: Gerbode Lab
% Date: 2026

%% ==================== CONFIGURATION ====================
base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';

% Simulation types and their folders
sim_types = {'zigzag', 'stripe', 'random', 'topdriven'};
sim_folders = {'drivensinesims', 'stripesinesims', 'randomsinesims', 'topdrivensims'};
sim_patterns = {'sinusoidal_f%.4f_a2.0', 'sinusoidal_f%.4f_a2.0_stripes', ...
                'sinusoidal_f%.4f_a2.0_random', 'topdriven_f%.4f_a2.0'};

% Available frequencies
all_frequencies = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...
                   0.001, 0.0012, 0.0015, 0.0018, ...
                   0.002, 0.0025, 0.003, 0.004, 0.005, ...
                   0.007, 0.01, 0.02, 0.05, 0.10];

%% ==================== CREATE FIGURE ====================
fig = uifigure('Name', 'Simulation Viewer', 'Position', [50 50 1400 900]);
fig.Color = [0.15 0.15 0.15];

% Store app data
app = struct();
app.base_path = base_path;
app.sim_types = sim_types;
app.sim_folders = sim_folders;
app.sim_patterns = sim_patterns;
app.frequencies = all_frequencies;
app.current_freq_idx = 1;
app.current_frame = 1;
app.view_mode = 'particles';  % 'particles', 'wavefront', 'kymograph'
app.is_playing = false;
app.play_speed = 1;
app.loaded_data = struct();
app.timer = [];

%% ==================== CONTROL PANEL (Left side) ====================
control_panel = uipanel(fig, 'Title', 'Controls', ...
    'Position', [10 10 200 880], ...
    'BackgroundColor', [0.2 0.2 0.2], ...
    'ForegroundColor', 'white');

% Frequency selection
uilabel(control_panel, 'Text', 'Frequency:', ...
    'Position', [10 830 180 20], 'FontColor', 'white');

app.freq_slider = uislider(control_panel, ...
    'Position', [10 790 180 3], ...
    'Limits', [1 length(all_frequencies)], ...
    'Value', 1, ...
    'MajorTicks', 1:5:length(all_frequencies), ...
    'MinorTicks', []);
app.freq_slider.ValueChangedFcn = @(src, evt) freq_changed(fig, app, src.Value);

app.freq_label = uilabel(control_panel, 'Text', sprintf('f = %.4f', all_frequencies(1)), ...
    'Position', [10 755 180 25], 'FontColor', 'cyan', 'FontSize', 14, ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% View mode buttons
uilabel(control_panel, 'Text', 'View Mode:', ...
    'Position', [10 710 180 20], 'FontColor', 'white');

app.btn_particles = uibutton(control_panel, 'Text', 'Particles', ...
    'Position', [10 680 60 25], 'BackgroundColor', [0.3 0.6 0.3]);
app.btn_particles.ButtonPushedFcn = @(src, evt) set_view_mode(fig, app, 'particles');

app.btn_wavefront = uibutton(control_panel, 'Text', 'Wavefront', ...
    'Position', [75 680 60 25], 'BackgroundColor', [0.4 0.4 0.4]);
app.btn_wavefront.ButtonPushedFcn = @(src, evt) set_view_mode(fig, app, 'wavefront');

app.btn_kymograph = uibutton(control_panel, 'Text', 'Kymograph', ...
    'Position', [140 680 55 25], 'BackgroundColor', [0.4 0.4 0.4]);
app.btn_kymograph.ButtonPushedFcn = @(src, evt) set_view_mode(fig, app, 'kymograph');

% Playback controls
uilabel(control_panel, 'Text', 'Playback:', ...
    'Position', [10 630 180 20], 'FontColor', 'white');

app.btn_play = uibutton(control_panel, 'Text', '▶ Play', ...
    'Position', [10 600 90 25], 'BackgroundColor', [0.3 0.5 0.3]);
app.btn_play.ButtonPushedFcn = @(src, evt) toggle_play(fig, app);

app.btn_step = uibutton(control_panel, 'Text', 'Step ▶', ...
    'Position', [105 600 90 25], 'BackgroundColor', [0.4 0.4 0.4]);
app.btn_step.ButtonPushedFcn = @(src, evt) step_frame(fig, app, 1);

app.btn_reset = uibutton(control_panel, 'Text', '⟲ Reset', ...
    'Position', [10 570 90 25], 'BackgroundColor', [0.4 0.4 0.4]);
app.btn_reset.ButtonPushedFcn = @(src, evt) reset_playback(fig, app);

% Frame slider
uilabel(control_panel, 'Text', 'Frame:', ...
    'Position', [10 530 180 20], 'FontColor', 'white');

app.frame_slider = uislider(control_panel, ...
    'Position', [10 500 180 3], ...
    'Limits', [1 100], ...
    'Value', 1);
app.frame_slider.ValueChangedFcn = @(src, evt) frame_changed(fig, app, round(src.Value));

app.frame_label = uilabel(control_panel, 'Text', 'Frame: 1 / 100', ...
    'Position', [10 465 180 25], 'FontColor', 'white', ...
    'HorizontalAlignment', 'center');

% Speed control
uilabel(control_panel, 'Text', 'Speed:', ...
    'Position', [10 420 50 20], 'FontColor', 'white');

app.speed_dropdown = uidropdown(control_panel, ...
    'Items', {'0.25x', '0.5x', '1x', '2x', '4x'}, ...
    'Value', '1x', ...
    'Position', [60 418 80 25]);
app.speed_dropdown.ValueChangedFcn = @(src, evt) set_speed(fig, app, src.Value);

% Status
uilabel(control_panel, 'Text', 'Loaded Simulations:', ...
    'Position', [10 370 180 20], 'FontColor', 'white');

app.status_text = uitextarea(control_panel, ...
    'Position', [10 250 180 115], ...
    'Editable', 'off', ...
    'BackgroundColor', [0.1 0.1 0.1], ...
    'FontColor', [0.7 0.7 0.7], ...
    'FontSize', 10);

% Load button
app.btn_load = uibutton(control_panel, 'Text', 'Load Data', ...
    'Position', [10 210 180 30], 'BackgroundColor', [0.2 0.4 0.6]);
app.btn_load.ButtonPushedFcn = @(src, evt) load_current_frequency(fig, app);

%% ==================== PLOT PANELS (Right side) ====================
% Create 2x2 grid for the 4 simulation types
panel_width = 570;
panel_height = 420;
x_offset = 220;
y_positions = [470, 40];
x_positions = [x_offset, x_offset + panel_width + 10];

app.axes = cell(4, 1);
app.panels = cell(4, 1);

for i = 1:4
    row = ceil(i / 2);
    col = mod(i - 1, 2) + 1;

    app.panels{i} = uipanel(fig, 'Title', upper(sim_types{i}), ...
        'Position', [x_positions(col), y_positions(row), panel_width, panel_height], ...
        'BackgroundColor', [0.1 0.1 0.1], ...
        'ForegroundColor', 'white', ...
        'FontWeight', 'bold');

    app.axes{i} = uiaxes(app.panels{i}, ...
        'Position', [10 10 panel_width-20 panel_height-40], ...
        'Color', [0 0 0], ...
        'XColor', 'white', 'YColor', 'white');
    app.axes{i}.Toolbar.Visible = 'off';
end

%% ==================== STORE APP DATA ====================
guidata(fig, app);

% Initial load
load_current_frequency(fig, app);

end

%% ==================== CALLBACK FUNCTIONS ====================

function freq_changed(fig, app, value)
    app = guidata(fig);
    app.current_freq_idx = round(value);
    app.freq_label.Text = sprintf('f = %.4f', app.frequencies(app.current_freq_idx));
    guidata(fig, app);
    load_current_frequency(fig, app);
end

function set_view_mode(fig, app, mode)
    app = guidata(fig);
    app.view_mode = mode;

    % Update button colors
    default_color = [0.4 0.4 0.4];
    active_color = [0.3 0.6 0.3];

    app.btn_particles.BackgroundColor = default_color;
    app.btn_wavefront.BackgroundColor = default_color;
    app.btn_kymograph.BackgroundColor = default_color;

    switch mode
        case 'particles'
            app.btn_particles.BackgroundColor = active_color;
        case 'wavefront'
            app.btn_wavefront.BackgroundColor = active_color;
        case 'kymograph'
            app.btn_kymograph.BackgroundColor = active_color;
    end

    guidata(fig, app);
    update_display(fig, app);
end

function toggle_play(fig, app)
    app = guidata(fig);
    app.is_playing = ~app.is_playing;

    if app.is_playing
        app.btn_play.Text = '⏸ Pause';
        app.btn_play.BackgroundColor = [0.6 0.3 0.3];
        % Start playback timer
        app.timer = timer('ExecutionMode', 'fixedRate', ...
            'Period', 0.1 / app.play_speed, ...
            'TimerFcn', @(~,~) advance_frame(fig));
        start(app.timer);
    else
        app.btn_play.Text = '▶ Play';
        app.btn_play.BackgroundColor = [0.3 0.5 0.3];
        % Stop timer
        if ~isempty(app.timer) && isvalid(app.timer)
            stop(app.timer);
            delete(app.timer);
        end
        app.timer = [];
    end

    guidata(fig, app);
end

function advance_frame(fig)
    if ~isvalid(fig); return; end
    app = guidata(fig);

    max_frames = app.frame_slider.Limits(2);
    new_frame = app.current_frame + 1;
    if new_frame > max_frames
        new_frame = 1;
    end

    app.current_frame = new_frame;
    app.frame_slider.Value = new_frame;
    app.frame_label.Text = sprintf('Frame: %d / %d', new_frame, max_frames);
    guidata(fig, app);

    update_display(fig, app);
end

function step_frame(fig, app, delta)
    app = guidata(fig);
    max_frames = app.frame_slider.Limits(2);
    new_frame = app.current_frame + delta;
    new_frame = max(1, min(new_frame, max_frames));

    app.current_frame = new_frame;
    app.frame_slider.Value = new_frame;
    app.frame_label.Text = sprintf('Frame: %d / %d', new_frame, max_frames);
    guidata(fig, app);

    update_display(fig, app);
end

function frame_changed(fig, app, value)
    app = guidata(fig);
    app.current_frame = value;
    app.frame_label.Text = sprintf('Frame: %d / %d', value, app.frame_slider.Limits(2));
    guidata(fig, app);
    update_display(fig, app);
end

function reset_playback(fig, app)
    app = guidata(fig);
    if app.is_playing
        toggle_play(fig, app);
        app = guidata(fig);
    end
    app.current_frame = 1;
    app.frame_slider.Value = 1;
    app.frame_label.Text = sprintf('Frame: 1 / %d', app.frame_slider.Limits(2));
    guidata(fig, app);
    update_display(fig, app);
end

function set_speed(fig, app, speed_str)
    app = guidata(fig);
    switch speed_str
        case '0.25x'; app.play_speed = 0.25;
        case '0.5x'; app.play_speed = 0.5;
        case '1x'; app.play_speed = 1;
        case '2x'; app.play_speed = 2;
        case '4x'; app.play_speed = 4;
    end
    guidata(fig, app);

    % Restart timer if playing
    if app.is_playing
        toggle_play(fig, app);
        toggle_play(fig, app);
    end
end

function load_current_frequency(fig, app)
    app = guidata(fig);
    freq = app.frequencies(app.current_freq_idx);

    status_lines = {};
    max_frames = 1;

    for i = 1:length(app.sim_types)
        sim_type = app.sim_types{i};
        sim_folder = app.sim_folders{i};
        sim_pattern = app.sim_patterns{i};

        % Build path
        if i == 4  % topdriven
            sim_name = sprintf('topdriven_f%.4f_a2.0', freq);
        else
            sim_name = sprintf(sim_pattern, freq);
        end

        sim_path = fullfile(app.base_path, sim_folder, 'simulations', sim_name);
        plist_file = fullfile(sim_path, 'plist.mat');

        if exist(plist_file, 'file')
            try
                loaded = load(plist_file);
                plist = loaded.plist;

                % Convert to xyz
                frames = unique(plist(:, 4));
                n_frames = length(frames);
                n_particles = sum(plist(:, 4) == frames(1));

                xyz = zeros(n_particles, 3, n_frames);
                for ff = 1:n_frames
                    frame_mask = plist(:, 4) == frames(ff);
                    xyz(:, :, ff) = plist(frame_mask, 1:3);
                end

                app.loaded_data.(sim_type) = xyz;

                % Load params
                params_file = fullfile(sim_path, 'sim_params.mat');
                if exist(params_file, 'file')
                    params = load(params_file);
                    app.loaded_data.([sim_type '_params']) = params.sim_params;
                end

                max_frames = max(max_frames, n_frames);
                status_lines{end+1} = sprintf('%s: %d frames', upper(sim_type), n_frames);

            catch ME
                app.loaded_data.(sim_type) = [];
                status_lines{end+1} = sprintf('%s: ERROR', upper(sim_type));
            end
        else
            app.loaded_data.(sim_type) = [];
            status_lines{end+1} = sprintf('%s: not found', upper(sim_type));
        end
    end

    % Update frame slider limits
    app.frame_slider.Limits = [1 max(max_frames, 2)];
    app.frame_slider.Value = 1;
    app.current_frame = 1;
    app.frame_label.Text = sprintf('Frame: 1 / %d', max_frames);

    % Update status
    app.status_text.Value = status_lines;

    guidata(fig, app);
    update_display(fig, app);
end

function update_display(fig, app)
    app = guidata(fig);

    for i = 1:length(app.sim_types)
        sim_type = app.sim_types{i};
        ax = app.axes{i};

        if ~isfield(app.loaded_data, sim_type) || isempty(app.loaded_data.(sim_type))
            cla(ax);
            text(ax, 0.5, 0.5, 'No data', 'Color', 'white', ...
                'HorizontalAlignment', 'center', 'FontSize', 14);
            continue;
        end

        xyz = app.loaded_data.(sim_type);
        n_frames = size(xyz, 3);
        frame = min(app.current_frame, n_frames);

        % Get params
        params_field = [sim_type '_params'];
        if isfield(app.loaded_data, params_field)
            params = app.loaded_data.(params_field);
            width = params.width;
            height = params.height;
        else
            width = 800; height = 400;
        end

        switch app.view_mode
            case 'particles'
                draw_particles(ax, xyz, frame, width, height);

            case 'wavefront'
                draw_wavefront(ax, xyz, frame, width, height);

            case 'kymograph'
                draw_kymograph(ax, xyz, width, height);
        end
    end
end

function draw_particles(ax, xyz, frame, width, height)
    cla(ax);
    hold(ax, 'on');

    x = xyz(:, 1, frame);
    y = xyz(:, 2, frame);
    z = xyz(:, 3, frame);

    % Color by z (spin)
    z_norm = (z - min(z)) / (max(z) - min(z) + eps);
    colors = [z_norm, zeros(size(z_norm)), 1 - z_norm];

    scatter(ax, x, y, 8, colors, 'filled');

    xlim(ax, [0 width]);
    ylim(ax, [0 height]);
    axis(ax, 'equal');
    set(ax, 'Color', 'k');
    hold(ax, 'off');
end

function draw_wavefront(ax, xyz, frame, width, height)
    cla(ax);
    hold(ax, 'on');

    x = xyz(:, 1, frame);
    x0 = mean(xyz(:, 1, 1:min(10, size(xyz,3))), 3);
    dx = x - x0;

    % Bin by x position
    n_bins = 50;
    bin_edges = linspace(0, width, n_bins + 1);
    bin_centers = (bin_edges(1:end-1) + bin_edges(2:end)) / 2;

    avg_dx = zeros(n_bins, 1);
    for b = 1:n_bins
        in_bin = x0 >= bin_edges(b) & x0 < bin_edges(b+1);
        if sum(in_bin) > 0
            avg_dx(b) = mean(dx(in_bin));
        end
    end

    plot(ax, bin_centers, avg_dx, 'c-', 'LineWidth', 2);
    yline(ax, 0, '--', 'Color', [0.5 0.5 0.5]);

    xlim(ax, [0 width]);
    ylim(ax, [-3 3]);
    xlabel(ax, 'X position');
    ylabel(ax, 'Displacement');
    set(ax, 'Color', 'k');
    hold(ax, 'off');
end

function draw_kymograph(ax, xyz, width, height)
    cla(ax);

    n_frames = size(xyz, 3);
    x = xyz(:, 1, :);
    x0 = mean(x(:, :, 1:min(10, n_frames)), 3);

    % Bin by x position
    n_bins = 100;
    bin_edges = linspace(0, width, n_bins + 1);

    kymograph = zeros(n_bins, n_frames);
    for f = 1:n_frames
        dx = x(:, :, f) - x0;
        for b = 1:n_bins
            in_bin = x0 >= bin_edges(b) & x0 < bin_edges(b+1);
            if sum(in_bin) > 0
                kymograph(b, f) = mean(dx(in_bin));
            end
        end
    end

    imagesc(ax, kymograph');
    colormap(ax, 'jet');
    clim(ax, [-2 2]);
    xlabel(ax, 'X bin');
    ylabel(ax, 'Frame');
    set(ax, 'YDir', 'normal');
end
