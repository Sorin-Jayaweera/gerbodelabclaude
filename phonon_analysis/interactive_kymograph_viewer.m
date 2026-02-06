%% Interactive Kymograph Viewer
% Browse all kymographs with zoom/pan capability
% Use slider or arrow keys to switch between frequencies
%
% Controls:
%   - Slider: change frequency
%   - Left/Right arrows: previous/next frequency
%   - Mouse drag: pan
%   - Scroll wheel: zoom
%   - Double-click: reset zoom

clear; close all;

%% Load data
batch_folder = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\drivensinesims';
simulations_folder = fullfile(batch_folder, 'simulations');

if exist(simulations_folder, 'dir')
    sim_base_path = simulations_folder;
else
    sim_base_path = batch_folder;
end

% Find all simulations
sim_dirs = dir(fullfile(sim_base_path, 'sinusoidal_f*_a*.0'));
frequencies = [];
sim_paths = {};

for i = 1:length(sim_dirs)
    tokens = regexp(sim_dirs(i).name, 'sinusoidal_f([\d.]+)_a', 'tokens');
    if ~isempty(tokens)
        f = str2double(tokens{1}{1});
        plist_file = fullfile(sim_base_path, sim_dirs(i).name, 'plist.mat');
        if exist(plist_file, 'file')
            frequencies(end+1) = f;
            sim_paths{end+1} = fullfile(sim_base_path, sim_dirs(i).name);
        end
    end
end

[frequencies, sort_idx] = sort(frequencies);
sim_paths = sim_paths(sort_idx);
n_freqs = length(frequencies);

fprintf('Found %d simulations\n', n_freqs);

%% Pre-compute all kymographs
fprintf('Loading and computing kymographs...\n');
kymographs = cell(n_freqs, 1);
box_size = [500, 300];
n_bins = 100;

for i = 1:n_freqs
    fprintf('  Loading %d/%d (f=%.4f)...\n', i, n_freqs, frequencies(i));

    plist_file = fullfile(sim_paths{i}, 'plist.mat');
    loaded = load(plist_file);
    plist = loaded.plist;

    xyz = plist2xyz_auto(plist, 1);
    xyz = unwrap_periodic(xyz, box_size);

    [N_particles, ~, N_frames] = size(xyz);
    x = squeeze(xyz(:, 1, :));
    x0 = mean(x(:, 1:min(10, N_frames)), 2);
    ux = x - x0;
    ux = ux - mean(ux, 1);

    % Create kymograph
    x_edges = linspace(0, box_size(1), n_bins+1);
    kymograph = zeros(n_bins, N_frames);
    for t = 1:N_frames
        for b = 1:n_bins
            in_bin = x0 >= x_edges(b) & x0 < x_edges(b+1);
            if sum(in_bin) > 0
                kymograph(b, t) = mean(ux(in_bin, t));
            end
        end
    end

    kymographs{i} = kymograph;
end

fprintf('Done loading.\n\n');
fprintf('=== CONTROLS ===\n');
fprintf('  Slider: change frequency\n');
fprintf('  Left/Right arrows: prev/next\n');
fprintf('  Click+drag: pan\n');
fprintf('  Scroll: zoom\n');
fprintf('  Double-click: reset view\n');

%% Create figure with controls
fig = figure('Name', 'Interactive Kymograph Viewer', ...
    'Position', [100, 100, 1400, 700], ...
    'KeyPressFcn', @keyPress, ...
    'WindowScrollWheelFcn', @scrollZoom);

% Store data in figure
setappdata(fig, 'kymographs', kymographs);
setappdata(fig, 'frequencies', frequencies);
setappdata(fig, 'current_idx', 1);
setappdata(fig, 'box_size', box_size);
setappdata(fig, 'n_bins', n_bins);

% Create axes
ax1 = subplot(1, 2, 1);
setappdata(fig, 'ax1', ax1);

ax2 = subplot(1, 2, 2);
setappdata(fig, 'ax2', ax2);

% Slider
slider = uicontrol('Style', 'slider', ...
    'Min', 1, 'Max', n_freqs, 'Value', 1, ...
    'SliderStep', [1/(n_freqs-1), 3/(n_freqs-1)], ...
    'Position', [150, 20, 500, 25], ...
    'Callback', @sliderCallback);
setappdata(fig, 'slider', slider);

% Label
label = uicontrol('Style', 'text', ...
    'Position', [660, 20, 300, 25], ...
    'FontSize', 12, ...
    'HorizontalAlignment', 'left');
setappdata(fig, 'label', label);

% Buttons
uicontrol('Style', 'pushbutton', 'String', '< Prev', ...
    'Position', [50, 20, 80, 25], ...
    'Callback', @(~,~) changeFreq(fig, -1));

uicontrol('Style', 'pushbutton', 'String', 'Next >', ...
    'Position', [1050, 20, 80, 25], ...
    'Callback', @(~,~) changeFreq(fig, 1));

% Enable pan and zoom
pan(fig, 'on');
zoom(fig, 'on');

% Initial plot
updatePlot(fig);

%% Callback functions
function sliderCallback(src, ~)
    fig = ancestor(src, 'figure');
    idx = round(get(src, 'Value'));
    setappdata(fig, 'current_idx', idx);
    updatePlot(fig);
end

function keyPress(fig, event)
    switch event.Key
        case 'leftarrow'
            changeFreq(fig, -1);
        case 'rightarrow'
            changeFreq(fig, 1);
    end
end

function scrollZoom(fig, event)
    % Mouse scroll zooms
    ax = gca;
    if event.VerticalScrollCount > 0
        zoom(ax, 0.8);  % Zoom out
    else
        zoom(ax, 1.25);  % Zoom in
    end
end

function changeFreq(fig, delta)
    idx = getappdata(fig, 'current_idx');
    frequencies = getappdata(fig, 'frequencies');
    n_freqs = length(frequencies);

    new_idx = max(1, min(n_freqs, idx + delta));
    setappdata(fig, 'current_idx', new_idx);

    slider = getappdata(fig, 'slider');
    set(slider, 'Value', new_idx);

    updatePlot(fig);
end

function updatePlot(fig)
    idx = getappdata(fig, 'current_idx');
    kymographs = getappdata(fig, 'kymographs');
    frequencies = getappdata(fig, 'frequencies');
    box_size = getappdata(fig, 'box_size');
    n_bins = getappdata(fig, 'n_bins');
    label = getappdata(fig, 'label');
    ax1 = getappdata(fig, 'ax1');
    ax2 = getappdata(fig, 'ax2');

    kymo = kymographs{idx};
    f = frequencies(idx);
    n_freqs = length(frequencies);

    % Update label
    period = round(1/f);
    set(label, 'String', sprintf('f = %.4f (period = %d frames) | %d/%d', f, period, idx, n_freqs));

    % Plot 1: Full kymograph
    axes(ax1);
    x_axis = linspace(0, box_size(1), n_bins);
    t_axis = 1:size(kymo, 2);
    imagesc(t_axis, x_axis, kymo);
    colormap(ax1, redblue(256));
    caxis([-1.5, 1.5]);
    colorbar;
    xlabel('Frame');
    ylabel('X position (pixels)');
    title(sprintf('Kymograph: f = %.4f', f));
    set(ax1, 'YDir', 'normal');

    % Plot 2: Zoomed view of first few cycles
    axes(ax2);
    n_cycles = 5;
    max_frame = min(n_cycles * period, size(kymo, 2));
    imagesc(1:max_frame, x_axis, kymo(:, 1:max_frame));
    colormap(ax2, redblue(256));
    caxis([-1.5, 1.5]);
    colorbar;
    xlabel('Frame');
    ylabel('X position (pixels)');
    title(sprintf('First %d cycles (f = %.4f)', n_cycles, f));
    set(ax2, 'YDir', 'normal');

    % Add drive period markers
    hold on;
    for c = 1:n_cycles
        xline(c * period, 'w--', 'LineWidth', 1);
    end
    hold off;

    drawnow;
end

function cmap = redblue(n)
    % Red-white-blue colormap
    if nargin < 1, n = 256; end
    half = floor(n/2);
    r = [linspace(0, 1, half), ones(1, n-half)];
    g = [linspace(0, 1, half), linspace(1, 0, n-half)];
    b = [ones(1, half), linspace(1, 0, n-half)];
    cmap = [r', g', b'];
end
