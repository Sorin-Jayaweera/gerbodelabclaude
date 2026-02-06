%% Animated Multi-Frequency Kymograph Comparison
% Shows ZOOMED sliding window of kymographs for multiple frequencies
% Much better for seeing wave dynamics than full plot with moving bar
%
% Controls:
%   Space: Play/Pause
%   Left/Right arrows: Step frame by frame
%   Up/Down arrows: Change playback speed
%   [ / ]: Decrease/increase window width
%   R: Reset to beginning
%   S: Save current frame as PNG

clear; close all;

%% Configuration
batch_folder = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\drivensinesims';
simulations_folder = fullfile(batch_folder, 'simulations');

if exist(simulations_folder, 'dir')
    sim_base_path = simulations_folder;
else
    sim_base_path = batch_folder;
end

% Select frequencies to compare (low to high)
target_freqs = [0.002, 0.005, 0.01, 0.02, 0.04, 0.08];
n_panels = length(target_freqs);
grid_rows = 2;
grid_cols = 3;

% Sliding window settings
window_width = 200;  % frames to show at once

%% Find and load simulations
fprintf('Loading simulations...\n');
sim_dirs = dir(fullfile(sim_base_path, 'sinusoidal_f*_a*.0'));
all_freqs = [];
all_paths = {};

for i = 1:length(sim_dirs)
    tokens = regexp(sim_dirs(i).name, 'sinusoidal_f([\d.]+)_a', 'tokens');
    if ~isempty(tokens)
        f = str2double(tokens{1}{1});
        plist_file = fullfile(sim_base_path, sim_dirs(i).name, 'plist.mat');
        if exist(plist_file, 'file')
            all_freqs(end+1) = f;
            all_paths{end+1} = fullfile(sim_base_path, sim_dirs(i).name);
        end
    end
end

% Find closest matches to target frequencies
selected_freqs = zeros(1, n_panels);
selected_paths = cell(1, n_panels);
for i = 1:n_panels
    [~, idx] = min(abs(all_freqs - target_freqs(i)));
    selected_freqs(i) = all_freqs(idx);
    selected_paths{i} = all_paths{idx};
    fprintf('  Panel %d: f=%.4f (requested %.4f)\n', i, selected_freqs(i), target_freqs(i));
end

%% Load all kymographs
box_size = [500, 300];
n_bins = 100;
kymographs = cell(n_panels, 1);
min_frames = inf;

for p = 1:n_panels
    fprintf('Loading %d/%d (f=%.4f)...\n', p, n_panels, selected_freqs(p));

    plist_file = fullfile(selected_paths{p}, 'plist.mat');
    loaded = load(plist_file);
    plist = loaded.plist;

    xyz = plist2xyz_auto(plist, 1);
    xyz = unwrap_periodic(xyz, box_size);

    [N_particles, ~, N_frames] = size(xyz);
    min_frames = min(min_frames, N_frames);

    x = squeeze(xyz(:, 1, :));
    x0 = mean(x(:, 1:min(10, N_frames)), 2);
    ux = x - x0;
    ux = ux - mean(ux, 1);

    % Create kymograph
    x_edges = linspace(0, box_size(1), n_bins+1);
    kymo = zeros(n_bins, N_frames);
    for t = 1:N_frames
        for b = 1:n_bins
            in_bin = x0 >= x_edges(b) & x0 < x_edges(b+1);
            if sum(in_bin) > 0
                kymo(b, t) = mean(ux(in_bin, t));
            end
        end
    end
    kymographs{p} = kymo;
end

fprintf('Done loading. Min frames: %d\n', min_frames);

%% Create figure
fig = figure('Name', 'Zoomed Kymograph Comparison', ...
    'Position', [50, 50, 1600, 900], ...
    'Color', 'k', ...
    'KeyPressFcn', @keyCallback);

% Store data
setappdata(fig, 'kymographs', kymographs);
setappdata(fig, 'selected_freqs', selected_freqs);
setappdata(fig, 'n_panels', n_panels);
setappdata(fig, 'n_bins', n_bins);
setappdata(fig, 'min_frames', min_frames);
setappdata(fig, 'current_frame', 1);
setappdata(fig, 'playing', false);
setappdata(fig, 'speed', 1);  % Start slow
setappdata(fig, 'window_width', window_width);
setappdata(fig, 'box_size', box_size);
setappdata(fig, 'grid_rows', grid_rows);
setappdata(fig, 'grid_cols', grid_cols);
setappdata(fig, 'batch_folder', batch_folder);

% Create subplots with image handles
axes_handles = cell(n_panels, 1);
image_handles = cell(n_panels, 1);

x_axis = linspace(0, box_size(1), n_bins);

for p = 1:n_panels
    axes_handles{p} = subplot(grid_rows, grid_cols, p);

    % Initial zoomed window
    kymo = kymographs{p};
    t_start = 1;
    t_end = min(window_width, size(kymo, 2));

    image_handles{p} = imagesc(t_start:t_end, x_axis, kymo(:, t_start:t_end));
    colormap(axes_handles{p}, redblue(256));
    caxis([-2, 2]);
    set(axes_handles{p}, 'YDir', 'normal');

    % Labels
    period = round(1/selected_freqs(p));
    title(sprintf('f = %.4f (T=%d)', selected_freqs(p), period), ...
        'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Frame', 'Color', 'w');
    if mod(p-1, grid_cols) == 0
        ylabel('X position (px)', 'Color', 'w');
    end

    set(axes_handles{p}, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
end

setappdata(fig, 'axes_handles', axes_handles);
setappdata(fig, 'image_handles', image_handles);

% Info text
uicontrol('Style', 'text', ...
    'Position', [10, 10, 700, 25], ...
    'String', 'Space=Play/Pause | ←→=Step | ↑↓=Speed | [ ]=WindowSize | R=Reset | S=Save', ...
    'FontSize', 10, ...
    'BackgroundColor', 'k', ...
    'ForegroundColor', 'w', ...
    'HorizontalAlignment', 'left');

frame_text = uicontrol('Style', 'text', ...
    'Position', [1300, 10, 280, 25], ...
    'String', 'Frame: 1 | Speed: 1 | Window: 200', ...
    'FontSize', 11, ...
    'BackgroundColor', 'k', ...
    'ForegroundColor', 'g', ...
    'HorizontalAlignment', 'right');
setappdata(fig, 'frame_text', frame_text);

% Timer for animation
t = timer('ExecutionMode', 'fixedRate', ...
    'Period', 0.05, ...
    'TimerFcn', @(~,~) animateStep(fig));
setappdata(fig, 'timer', t);

% Cleanup when figure closes
set(fig, 'CloseRequestFcn', @(~,~) cleanupFig(fig));

fprintf('\n=== CONTROLS ===\n');
fprintf('  Space: Play/Pause\n');
fprintf('  ←/→: Step frames\n');
fprintf('  ↑/↓: Faster/slower\n');
fprintf('  [ / ]: Smaller/larger window\n');
fprintf('  R: Reset\n');
fprintf('  S: Save screenshot\n');

%% Animation functions
function animateStep(fig)
    if ~isvalid(fig)
        return;
    end

    playing = getappdata(fig, 'playing');
    if ~playing
        return;
    end

    current = getappdata(fig, 'current_frame');
    speed = getappdata(fig, 'speed');
    min_frames = getappdata(fig, 'min_frames');
    window_width = getappdata(fig, 'window_width');

    new_frame = current + speed;
    if new_frame > min_frames - window_width
        new_frame = 1;  % Loop
    end

    setappdata(fig, 'current_frame', new_frame);
    updateDisplay(fig);
end

function updateDisplay(fig)
    current = getappdata(fig, 'current_frame');
    kymographs = getappdata(fig, 'kymographs');
    image_handles = getappdata(fig, 'image_handles');
    axes_handles = getappdata(fig, 'axes_handles');
    frame_text = getappdata(fig, 'frame_text');
    n_panels = getappdata(fig, 'n_panels');
    window_width = getappdata(fig, 'window_width');
    speed = getappdata(fig, 'speed');
    min_frames = getappdata(fig, 'min_frames');

    t_start = current;
    t_end = min(current + window_width - 1, min_frames);

    % Update each panel
    for p = 1:n_panels
        kymo = kymographs{p};
        set(image_handles{p}, 'CData', kymo(:, t_start:t_end), ...
            'XData', t_start:t_end);
        xlim(axes_handles{p}, [t_start, t_end]);
    end

    % Update info
    set(frame_text, 'String', sprintf('Frame: %d-%d | Speed: %d | Window: %d', ...
        t_start, t_end, speed, window_width));

    drawnow limitrate;
end

function keyCallback(fig, event)
    current = getappdata(fig, 'current_frame');
    min_frames = getappdata(fig, 'min_frames');
    speed = getappdata(fig, 'speed');
    playing = getappdata(fig, 'playing');
    window_width = getappdata(fig, 'window_width');
    t = getappdata(fig, 'timer');

    switch event.Key
        case 'space'
            playing = ~playing;
            setappdata(fig, 'playing', playing);
            if playing
                start(t);
            else
                stop(t);
            end

        case 'rightarrow'
            new_frame = min(current + max(1, speed), min_frames - window_width);
            setappdata(fig, 'current_frame', new_frame);
            updateDisplay(fig);

        case 'leftarrow'
            new_frame = max(current - max(1, speed), 1);
            setappdata(fig, 'current_frame', new_frame);
            updateDisplay(fig);

        case 'uparrow'
            speed = min(speed + 1, 50);
            setappdata(fig, 'speed', speed);
            updateDisplay(fig);

        case 'downarrow'
            speed = max(speed - 1, 1);
            setappdata(fig, 'speed', speed);
            updateDisplay(fig);

        case 'bracketleft'  % [
            window_width = max(window_width - 50, 50);
            setappdata(fig, 'window_width', window_width);
            updateDisplay(fig);

        case 'bracketright'  % ]
            window_width = min(window_width + 50, 500);
            setappdata(fig, 'window_width', window_width);
            updateDisplay(fig);

        case 'r'
            setappdata(fig, 'current_frame', 1);
            updateDisplay(fig);

        case 's'
            batch_folder = getappdata(fig, 'batch_folder');
            analysis_folder = fullfile(batch_folder, 'analysis');
            filename = fullfile(analysis_folder, sprintf('kymograph_frame_%05d.png', current));
            saveas(fig, filename);
            fprintf('Saved: %s\n', filename);
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

function cmap = redblue(n)
    if nargin < 1, n = 256; end
    half = floor(n/2);
    r = [linspace(0, 1, half), ones(1, n-half)];
    g = [linspace(0, 1, half), linspace(1, 0, n-half)];
    b = [ones(1, half), linspace(1, 0, n-half)];
    cmap = [r', g', b'];
end
