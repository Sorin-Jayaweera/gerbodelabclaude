%% Animated Wave Profile Comparison
% Shows the actual displacement wave u(x,t) evolving in time
% Multiple frequencies side-by-side to compare wave shapes
%
% This shows:
%   - Wave amplitude and shape at each instant
%   - Propagation speed (watch the peaks move)
%   - Attenuation (amplitude decreases with distance)
%   - Reflections (waves bouncing back from boundaries)
%
% Controls:
%   Space: Play/Pause
%   Left/Right: Step frames
%   Up/Down: Change speed

clear; close all;

%% Configuration
batch_folder = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\drivensinesims';
simulations_folder = fullfile(batch_folder, 'simulations');

if exist(simulations_folder, 'dir')
    sim_base_path = simulations_folder;
else
    sim_base_path = batch_folder;
end

% Frequencies to compare
target_freqs = [0.002, 0.005, 0.01, 0.02, 0.04, 0.08];
n_panels = length(target_freqs);
grid_rows = 2;
grid_cols = 3;

%% Load simulations
fprintf('Loading simulations for wave profile animation...\n');
sim_dirs = dir(fullfile(sim_base_path, 'sinusoidal_f*_a*.0'));
all_freqs = [];
all_paths = {};

for i = 1:length(sim_dirs)
    tokens = regexp(sim_dirs(i).name, 'sinusoidal_f([\d.]+)_a', 'tokens');
    if ~isempty(tokens)
        f = str2double(tokens{1}{1});
        if exist(fullfile(sim_base_path, sim_dirs(i).name, 'plist.mat'), 'file')
            all_freqs(end+1) = f;
            all_paths{end+1} = fullfile(sim_base_path, sim_dirs(i).name);
        end
    end
end

% Find closest matches
selected_freqs = zeros(1, n_panels);
selected_paths = cell(1, n_panels);
for i = 1:n_panels
    [~, idx] = min(abs(all_freqs - target_freqs(i)));
    selected_freqs(i) = all_freqs(idx);
    selected_paths{i} = all_paths{idx};
end

%% Load displacement data
box_size = [500, 300];
n_bins = 100;
displacement_data = cell(n_panels, 1);
min_frames = inf;

for p = 1:n_panels
    fprintf('Loading %d/%d (f=%.4f)...\n', p, n_panels, selected_freqs(p));

    loaded = load(fullfile(selected_paths{p}, 'plist.mat'));
    xyz = plist2xyz_auto(loaded.plist, 1);
    xyz = unwrap_periodic(xyz, box_size);

    [~, ~, N_frames] = size(xyz);
    min_frames = min(min_frames, N_frames);

    x = squeeze(xyz(:, 1, :));
    x0 = mean(x(:, 1:min(10, N_frames)), 2);
    ux = x - x0;
    ux = ux - mean(ux, 1);

    % Bin to create smooth profile
    x_edges = linspace(0, box_size(1), n_bins+1);
    x_centers = (x_edges(1:end-1) + x_edges(2:end)) / 2;
    binned = zeros(n_bins, N_frames);

    for t = 1:N_frames
        for b = 1:n_bins
            in_bin = x0 >= x_edges(b) & x0 < x_edges(b+1);
            if sum(in_bin) > 0
                binned(b, t) = mean(ux(in_bin, t));
            end
        end
    end

    displacement_data{p} = struct('x', x_centers, 'u', binned, 'freq', selected_freqs(p));
end

%% Create figure
fig = figure('Name', 'Wave Profile Animation', ...
    'Position', [50, 50, 1600, 900], ...
    'Color', [0.1 0.1 0.15], ...
    'KeyPressFcn', @keyCallback);

setappdata(fig, 'displacement_data', displacement_data);
setappdata(fig, 'n_panels', n_panels);
setappdata(fig, 'min_frames', min_frames);
setappdata(fig, 'current_frame', 1);
setappdata(fig, 'playing', false);
setappdata(fig, 'speed', 3);
setappdata(fig, 'grid_rows', grid_rows);
setappdata(fig, 'grid_cols', grid_cols);
setappdata(fig, 'batch_folder', batch_folder);

% Create subplots with line plots
axes_handles = cell(n_panels, 1);
line_handles = cell(n_panels, 1);
drive_markers = cell(n_panels, 1);

y_limit = 2.5;  % Displacement range

for p = 1:n_panels
    axes_handles{p} = subplot(grid_rows, grid_cols, p);
    data = displacement_data{p};

    % Plot initial frame
    line_handles{p} = plot(data.x, data.u(:, 1), 'w-', 'LineWidth', 2);
    hold on;

    % Mark drive region
    fill([0 25 25 0], [-y_limit -y_limit y_limit y_limit], [0.3 0.5 0.3], ...
        'FaceAlpha', 0.3, 'EdgeColor', 'none');

    % Zero line
    plot([0 500], [0 0], 'w--', 'LineWidth', 0.5);

    % Drive indicator (sinusoid at left)
    drive_markers{p} = plot(10, 0, 'go', 'MarkerSize', 15, 'MarkerFaceColor', 'g');

    hold off;

    xlim([0 500]);
    ylim([-y_limit y_limit]);

    period = round(1/data.freq);
    title(sprintf('f = %.4f | Period = %d frames', data.freq, period), ...
        'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('X position (pixels)', 'Color', 'w');
    ylabel('Displacement (px)', 'Color', 'w');

    set(axes_handles{p}, 'Color', [0.05 0.05 0.1], 'XColor', 'w', 'YColor', 'w', ...
        'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.5);
    grid on;
end

setappdata(fig, 'axes_handles', axes_handles);
setappdata(fig, 'line_handles', line_handles);
setappdata(fig, 'drive_markers', drive_markers);
setappdata(fig, 'y_limit', y_limit);

% Frame counter
frame_text = uicontrol('Style', 'text', ...
    'Position', [700, 10, 200, 30], ...
    'String', 'Frame: 1 / 2000', ...
    'FontSize', 14, ...
    'BackgroundColor', [0.1 0.1 0.15], ...
    'ForegroundColor', 'g', ...
    'FontWeight', 'bold');
setappdata(fig, 'frame_text', frame_text);

% Instructions
uicontrol('Style', 'text', ...
    'Position', [10, 10, 500, 25], ...
    'String', 'Space=Play | Arrows=Step | Up/Down=Speed | Green region=Drive', ...
    'FontSize', 10, ...
    'BackgroundColor', [0.1 0.1 0.15], ...
    'ForegroundColor', [0.7 0.7 0.7]);

% Timer
t = timer('ExecutionMode', 'fixedRate', 'Period', 0.03, ...
    'TimerFcn', @(~,~) animateStep(fig));
setappdata(fig, 'timer', t);

set(fig, 'CloseRequestFcn', @(~,~) cleanupFig(fig));

fprintf('\n=== Wave Profile Animation Ready ===\n');
fprintf('Press SPACE to start animation\n');
fprintf('\nWatch for:\n');
fprintf('  - LOW freq (top-left): Waves travel far, clear peaks\n');
fprintf('  - MID freq: Moderate decay, visible propagation\n');
fprintf('  - HIGH freq (bottom-right): Rapid decay, interference patterns\n');

%% Functions
function animateStep(fig)
    if ~isvalid(fig) || ~getappdata(fig, 'playing')
        return;
    end

    current = getappdata(fig, 'current_frame');
    speed = getappdata(fig, 'speed');
    min_frames = getappdata(fig, 'min_frames');

    new_frame = current + speed;
    if new_frame > min_frames
        new_frame = 1;
    end

    setappdata(fig, 'current_frame', new_frame);
    updateDisplay(fig);
end

function updateDisplay(fig)
    current = getappdata(fig, 'current_frame');
    displacement_data = getappdata(fig, 'displacement_data');
    line_handles = getappdata(fig, 'line_handles');
    drive_markers = getappdata(fig, 'drive_markers');
    frame_text = getappdata(fig, 'frame_text');
    n_panels = getappdata(fig, 'n_panels');
    min_frames = getappdata(fig, 'min_frames');
    y_limit = getappdata(fig, 'y_limit');

    for p = 1:n_panels
        data = displacement_data{p};

        % Update wave profile
        set(line_handles{p}, 'YData', data.u(:, current));

        % Update drive marker (shows current drive phase)
        drive_phase = 2 * sin(2 * pi * data.freq * current);
        set(drive_markers{p}, 'YData', drive_phase);
    end

    set(frame_text, 'String', sprintf('Frame: %d / %d', current, min_frames));
    drawnow limitrate;
end

function keyCallback(fig, event)
    current = getappdata(fig, 'current_frame');
    min_frames = getappdata(fig, 'min_frames');
    speed = getappdata(fig, 'speed');
    t = getappdata(fig, 'timer');

    switch event.Key
        case 'space'
            playing = ~getappdata(fig, 'playing');
            setappdata(fig, 'playing', playing);
            if playing
                start(t);
            else
                stop(t);
            end

        case 'rightarrow'
            setappdata(fig, 'current_frame', min(current + max(1,speed), min_frames));
            updateDisplay(fig);

        case 'leftarrow'
            setappdata(fig, 'current_frame', max(current - max(1,speed), 1));
            updateDisplay(fig);

        case 'uparrow'
            setappdata(fig, 'speed', min(speed + 2, 30));
            fprintf('Speed: %d\n', getappdata(fig, 'speed'));

        case 'downarrow'
            setappdata(fig, 'speed', max(speed - 2, 1));
            fprintf('Speed: %d\n', getappdata(fig, 'speed'));

        case 'r'
            setappdata(fig, 'current_frame', 1);
            updateDisplay(fig);
    end
end

function cleanupFig(fig)
    t = getappdata(fig, 'timer');
    if ~isempty(t) && isvalid(t)
        stop(t);
        delete(t);
    end
    delete(fig);
end
