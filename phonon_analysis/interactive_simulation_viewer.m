function interactive_simulation_viewer()
%% INTERACTIVE_SIMULATION_VIEWER
% Multi-panel viewer for comparing simulations across domain types
%
% Features:
%   - Checkboxes to select which simulations to display (1 to 6)
%   - Frequency slider to select which frequency to view
%   - View modes: Wavefront profile, Kymograph, Particle positions
%   - Playback controls: Play, Pause, Step, Speed
%   - Load range dropdowns: select which % of data to load (reduces memory)
%   - Auto-scaling Y-axis and colormap
%   - OPTIMIZED: Caching, vectorized loading, pre-computed kymographs
%
% Author: Gerbode Lab
% Date: 2026

%% ==================== CONFIGURATION ====================
base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';

% All available simulation types
all_sim_types   = {'chevron', 'stripe', 'random', 'topdriven', 'frust_side', 'frust_top'};
all_sim_folders = {'drivensinesims', 'stripesinesims', 'randomsinesims', 'topdrivensims', 'frustsinesims', 'frusttopsims'};
all_name_fmts   = {'sinusoidal_f%.4f_a2.0', 'sinusoidal_f%.4f_a2.0_stripes', ...
                   'sinusoidal_f%.4f_a2.0_random', 'topdriven_f%.4f_a2.0', ...
                   'frust_f%.4f_a2.0', 'frusttop_f%.4f_a2.0'};

all_frequencies = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...
                   0.001,  0.0012, 0.0015, 0.0018, ...
                   0.002,  0.0025, 0.003,  0.004,  0.005, ...
                   0.007,  0.01,   0.02,   0.05,   0.10];

%% ==================== BUILD UI ====================
fig = uifigure('Name', 'Simulation Viewer', 'Position', [50 50 1600 950]);
fig.Color = [0.15 0.15 0.15];

% ---- control panel (wider to fit checkboxes) ----
cp = uipanel(fig, 'Title', 'Controls', ...
    'Position', [8 8 220 934], ...
    'BackgroundColor', [0.2 0.2 0.2], 'ForegroundColor', 'w');

% ---- simulation checkboxes ----
uilabel(cp, 'Text', 'Show Simulations:', 'Position', [8 885 200 18], 'FontColor', 'w', 'FontWeight', 'bold');
cb_sims = cell(6,1);
cb_labels = {'Chevron (unfrust)', 'Stripe', 'Random', 'Top-driven', 'Frust Side', 'Frust Top'};
for i = 1:6
    checked = (i <= 4);  % Default: first 4 checked
    cb_sims{i} = uicheckbox(cp, 'Text', cb_labels{i}, ...
        'Value', checked, 'Position', [8 885-i*22 200 20], ...
        'FontColor', 'w');
end

% frequency slider
uilabel(cp, 'Text', 'Frequency:', 'Position', [8 738 200 18], 'FontColor', 'w');
sl_freq = uislider(cp, 'Position', [8 708 200 3], ...
    'Limits', [1 length(all_frequencies)], 'Value', 1, ...
    'MajorTicks', [], 'MinorTicks', []);
lbl_freq = uilabel(cp, 'Text', sprintf('f = %.4f', all_frequencies(1)), ...
    'Position', [8 678 200 24], 'FontColor', 'cyan', 'FontSize', 13, ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% view mode
uilabel(cp, 'Text', 'View Mode:', 'Position', [8 645 200 18], 'FontColor', 'w');
btn_part = uibutton(cp, 'Text', 'Particles',  'Position', [8  618 66 24], 'BackgroundColor', [0.3 0.6 0.3]);
btn_wave = uibutton(cp, 'Text', 'Wavefront',  'Position', [78 618 66 24], 'BackgroundColor', [0.4 0.4 0.4]);
btn_kymo = uibutton(cp, 'Text', 'Kymograph', 'Position', [148 618 66 24], 'BackgroundColor', [0.4 0.4 0.4]);

% playback
uilabel(cp, 'Text', 'Playback:', 'Position', [8 585 200 18], 'FontColor', 'w');
btn_play  = uibutton(cp, 'Text', '▶ Play',  'Position', [8  558 100 24], 'BackgroundColor', [0.3 0.5 0.3]);
btn_step  = uibutton(cp, 'Text', 'Step ▶',  'Position', [112 558 100 24], 'BackgroundColor', [0.4 0.4 0.4]);
btn_reset = uibutton(cp, 'Text', '⟲ Reset', 'Position', [8  530 100 24], 'BackgroundColor', [0.4 0.4 0.4]);

uilabel(cp, 'Text', 'Frame:', 'Position', [8 500 200 18], 'FontColor', 'w');
sl_frame  = uislider(cp, 'Position', [8 470 200 3], 'Limits', [1 100], 'Value', 1, ...
    'MajorTicks', [], 'MinorTicks', []);
lbl_frame = uilabel(cp, 'Text', 'Frame: 1 / 100', 'Position', [8 440 200 24], ...
    'FontColor', 'w', 'HorizontalAlignment', 'center');

uilabel(cp, 'Text', 'Speed:', 'Position', [8 410 60 18], 'FontColor', 'w');
dd_speed = uidropdown(cp, 'Items', {'0.25x','0.5x','1x','2x','4x'}, 'Value', '1x', ...
    'Position', [70 408 80 24]);

% ---- load range ----
uilabel(cp, 'Text', 'Load range (%):', 'Position', [8 375 200 18], 'FontColor', 'w');
dd_range_start = uidropdown(cp, ...
    'Items', {'0%','10%','20%','30%','40%','50%','60%','70%','80%','90%'}, ...
    'Value', '0%', 'Position', [8 350 90 24]);
uilabel(cp, 'Text', 'to', 'Position', [102 353 18 18], 'FontColor', 'w');
dd_range_end = uidropdown(cp, ...
    'Items', {'20%','30%','40%','50%','60%','70%','80%','90%','100%'}, ...
    'Value', '20%', 'Position', [122 350 90 24]);

% ---- load button ----
btn_load = uibutton(cp, 'Text', 'Load Selected', 'Position', [8 310 204 30], ...
    'BackgroundColor', [0.2 0.4 0.6]);

% ---- status ----
uilabel(cp, 'Text', 'Status:', 'Position', [8 280 200 18], 'FontColor', 'w');
txt_status = uitextarea(cp, 'Position', [8 120 204 158], 'Editable', 'off', ...
    'BackgroundColor', [0.1 0.1 0.1], 'FontColor', [0.7 0.7 0.7], 'FontSize', 9);

% ---- plot area (will be populated dynamically) ----
plot_area_x = 236;
plot_area_y = 8;
plot_area_w = 1356;
plot_area_h = 934;

%% ==================== STATE ====================
S.base_path       = base_path;
S.all_sim_types   = all_sim_types;
S.all_sim_folders = all_sim_folders;
S.all_name_fmts   = all_name_fmts;
S.frequencies     = all_frequencies;
S.freq_idx        = 1;
S.frame           = 1;
S.max_frames      = 100;
S.view_mode       = 'particles';
S.is_playing      = false;
S.play_speed      = 1;
S.data            = struct();   % xyz data per sim type
S.params          = struct();   % sim params per sim type
S.cache           = struct();   % Cache: key = "simtype_freqidx_startpct_endpct"
S.kymo_cache      = struct();   % Pre-computed kymographs
S.x0_cache        = struct();   % Pre-computed equilibrium positions
% UI handles
S.fig             = fig;
S.cb_sims         = cb_sims;
S.sl_freq         = sl_freq;
S.sl_frame        = sl_frame;
S.lbl_freq        = lbl_freq;
S.lbl_frame       = lbl_frame;
S.btn_play        = btn_play;
S.btn_part        = btn_part;
S.btn_wave        = btn_wave;
S.btn_kymo        = btn_kymo;
S.txt_status      = txt_status;
S.dd_range_start  = dd_range_start;
S.dd_range_end    = dd_range_end;
% Plot area bounds
S.plot_area       = [plot_area_x, plot_area_y, plot_area_w, plot_area_h];
S.panels          = {};
S.axs             = {};
S.selected_types  = {};  % Track currently displayed types
fig.UserData = S;

%% ==================== WIRE CALLBACKS ====================
sl_freq.ValueChangedFcn   = @(~,~) cb_freq(fig);
sl_frame.ValueChangedFcn  = @(~,~) cb_frame(fig);
btn_play.ButtonPushedFcn  = @(~,~) cb_play(fig);
btn_step.ButtonPushedFcn  = @(~,~) cb_step(fig);
btn_reset.ButtonPushedFcn = @(~,~) cb_reset(fig);
btn_load.ButtonPushedFcn  = @(~,~) cb_load(fig, true);  % force reload
btn_part.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'particles');
btn_wave.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'wavefront');
btn_kymo.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'kymograph');
dd_speed.ValueChangedFcn  = @(src,~) cb_speed(fig, src.Value);

% Checkbox callbacks - just rebuild panels, use cache if available
for i = 1:6
    cb_sims{i}.ValueChangedFcn = @(~,~) cb_checkbox(fig);
end

fig.CloseRequestFcn = @(~,~) cb_close(fig);

% Initial load
cb_load(fig, true);
end

%% ==================== CALLBACKS ====================

function cb_freq(fig)
    S = fig.UserData;
    S.freq_idx = round(S.sl_freq.Value);
    S.lbl_freq.Text = sprintf('f = %.4f', S.frequencies(S.freq_idx));
    fig.UserData = S;
    cb_load(fig, false);  % Use cache if available
end

function cb_frame(fig)
    S = fig.UserData;
    S.frame = round(S.sl_frame.Value);
    S.lbl_frame.Text = sprintf('Frame: %d / %d', S.frame, S.max_frames);
    fig.UserData = S;
    render(fig);
end

function cb_mode(fig, mode)
    S = fig.UserData;
    S.view_mode = mode;
    dim = [0.4 0.4 0.4]; act = [0.3 0.6 0.3];
    S.btn_part.BackgroundColor = dim;
    S.btn_wave.BackgroundColor = dim;
    S.btn_kymo.BackgroundColor = dim;
    switch mode
        case 'particles',  S.btn_part.BackgroundColor = act;
        case 'wavefront',  S.btn_wave.BackgroundColor = act;
        case 'kymograph',  S.btn_kymo.BackgroundColor = act;
    end
    fig.UserData = S;
    render(fig);
end

function cb_play(fig)
    S = fig.UserData;
    if S.is_playing
        S.is_playing = false;
        S.btn_play.Text = '▶ Play';
        S.btn_play.BackgroundColor = [0.3 0.5 0.3];
        fig.UserData = S;
    else
        S.is_playing = true;
        S.btn_play.Text = '⏸ Pause';
        S.btn_play.BackgroundColor = [0.6 0.3 0.3];
        fig.UserData = S;
        period = max(0.05, 0.1 / S.play_speed);
        t = timer('ExecutionMode', 'fixedRate', 'Period', period, ...
                  'TimerFcn', @(tmr,~) timer_tick(fig, tmr));
        start(t);
    end
end

function timer_tick(fig, tmr)
    if ~isvalid(fig); stop(tmr); delete(tmr); return; end
    S = fig.UserData;
    if ~S.is_playing; stop(tmr); delete(tmr); return; end
    next = S.frame + 1;
    if next > S.max_frames; next = 1; end
    S.frame = next;
    S.sl_frame.Value = next;
    S.lbl_frame.Text = sprintf('Frame: %d / %d', next, S.max_frames);
    fig.UserData = S;
    render(fig);
    drawnow limitrate;
end

function cb_step(fig)
    S = fig.UserData;
    S.frame = min(S.frame + 1, S.max_frames);
    S.sl_frame.Value = S.frame;
    S.lbl_frame.Text = sprintf('Frame: %d / %d', S.frame, S.max_frames);
    fig.UserData = S;
    render(fig);
end

function cb_reset(fig)
    S = fig.UserData;
    S.is_playing = false;
    S.btn_play.Text = '▶ Play';
    S.btn_play.BackgroundColor = [0.3 0.5 0.3];
    S.frame = 1;
    S.sl_frame.Value = 1;
    S.lbl_frame.Text = sprintf('Frame: 1 / %d', S.max_frames);
    fig.UserData = S;
    render(fig);
end

function cb_speed(fig, speed_str)
    S = fig.UserData;
    was_playing = S.is_playing;
    if was_playing
        S.is_playing = false;
        S.btn_play.Text = '▶ Play';
        S.btn_play.BackgroundColor = [0.3 0.5 0.3];
        fig.UserData = S;
        pause(0.15);
    end
    switch speed_str
        case '0.25x'; S.play_speed = 0.25;
        case '0.5x';  S.play_speed = 0.5;
        case '1x';    S.play_speed = 1;
        case '2x';    S.play_speed = 2;
        case '4x';    S.play_speed = 4;
    end
    fig.UserData = S;
    if was_playing; cb_play(fig); end
end

function cb_close(fig)
    S = fig.UserData;
    S.is_playing = false;
    fig.UserData = S;
    pause(0.15);
    delete(fig);
end

function cb_checkbox(fig)
    % Checkbox changed - rebuild panels but use cache for data
    cb_load(fig, false);
end

function cb_load(fig, force_reload)
    S = fig.UserData;
    freq = S.frequencies(S.freq_idx);

    % Get load range
    start_pct = str2double(strtrim(strrep(S.dd_range_start.Value, '%', '')));
    end_pct   = str2double(strtrim(strrep(S.dd_range_end.Value,   '%', '')));

    % Find which sims are selected
    selected = [];
    for i = 1:6
        if S.cb_sims{i}.Value
            selected(end+1) = i;
        end
    end

    if isempty(selected)
        S.txt_status.Value = {'No simulations selected'};
        fig.UserData = S;
        return;
    end

    % Delete old panels
    for i = 1:length(S.panels)
        if isvalid(S.panels{i}); delete(S.panels{i}); end
    end
    S.panels = {};
    S.axs = {};
    S.selected_types = {};

    % Create new panels for selected sims
    n_sel = length(selected);
    [rows, cols] = get_grid_size(n_sel);
    pa = S.plot_area;  % [x, y, w, h]
    pw = floor((pa(3) - (cols-1)*8) / cols);
    ph = floor((pa(4) - (rows-1)*8) / rows);

    lines_out = {};
    max_frames = 1;
    S.data = struct();
    S.params = struct();

    for idx = 1:n_sel
        i = selected(idx);
        st = S.all_sim_types{i};
        S.selected_types{end+1} = st;

        % Calculate grid position
        row = ceil(idx / cols);
        col = mod(idx-1, cols) + 1;
        px = pa(1) + (col-1) * (pw + 8);
        py = pa(2) + pa(4) - row * ph - (row-1)*8;

        % Create panel
        pan = uipanel(S.fig, 'Title', upper(st), ...
            'Position', [px py pw ph], ...
            'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', 'w', 'FontWeight', 'bold');
        ax = uiaxes(pan, 'Position', [8 8 pw-18 ph-38], ...
            'Color', 'k', 'XColor', 'w', 'YColor', 'w');
        ax.Toolbar.Visible = 'off';

        S.panels{end+1} = pan;
        S.axs{end+1} = ax;

        % Build cache key
        cache_key = sprintf('%s_f%d_r%d_%d', st, S.freq_idx, start_pct, end_pct);
        cache_key = matlab.lang.makeValidName(cache_key);

        % Check cache first (unless force reload)
        if ~force_reload && isfield(S.cache, cache_key)
            % Use cached data
            cached = S.cache.(cache_key);
            S.data.(st) = cached.xyz;
            S.params.(st) = cached.params;
            S.x0_cache.(st) = cached.x0;
            S.kymo_cache.(st) = cached.kymo;
            max_frames = max(max_frames, size(cached.xyz, 3));
            lines_out{end+1} = sprintf('%s: %d fr (cached)', upper(st), size(cached.xyz, 3));
            continue;
        end

        % Load data from disk
        sim_name = sprintf(S.all_name_fmts{i}, freq);
        plist_path = fullfile(S.base_path, S.all_sim_folders{i}, 'simulations', sim_name, 'plist.mat');
        par_path   = fullfile(S.base_path, S.all_sim_folders{i}, 'simulations', sim_name, 'sim_params.mat');

        if ~exist(plist_path, 'file')
            S.data.(st) = [];
            S.params.(st) = [];
            lines_out{end+1} = sprintf('%s: not found', upper(st));
            continue;
        end

        try
            % Use matfile for faster partial access
            S.txt_status.Value = [lines_out; {sprintf('Loading %s...', upper(st))}];
            drawnow;

            [xyz, n_total, sim_p] = load_simulation_fast(plist_path, par_path, freq, start_pct, end_pct);

            if isempty(xyz)
                S.data.(st) = [];
                S.params.(st) = [];
                lines_out{end+1} = sprintf('%s: load failed', upper(st));
                continue;
            end

            S.data.(st) = xyz;
            S.params.(st) = sim_p;
            n_frames = size(xyz, 3);

            % Pre-compute equilibrium positions (first 10 frames or available)
            n_eq = min(10, n_frames);
            x0 = mean(xyz(:,1,1:n_eq), 3);
            S.x0_cache.(st) = x0;

            % Pre-compute kymograph
            kymo = compute_kymograph_fast(xyz, x0, sim_p.width);
            S.kymo_cache.(st) = kymo;

            % Store in cache
            S.cache.(cache_key) = struct('xyz', xyz, 'params', sim_p, 'x0', x0, 'kymo', kymo);

            max_frames = max(max_frames, n_frames);
            lines_out{end+1} = sprintf('%s: %d/%d fr', upper(st), n_frames, n_total);
        catch ME
            S.data.(st) = [];
            lines_out{end+1} = sprintf('%s: ERR - %s', upper(st), ME.message);
        end
    end

    S.max_frames = max(max_frames, 2);
    S.sl_frame.Limits = [1 S.max_frames];
    S.sl_frame.Value = 1;
    S.frame = 1;
    S.lbl_frame.Text = sprintf('Frame: 1 / %d', S.max_frames);
    S.txt_status.Value = lines_out;
    fig.UserData = S;
    render(fig);
end

function [xyz, n_total, sim_params] = load_simulation_fast(plist_path, par_path, freq, start_pct, end_pct)
%% Fast simulation loading - handles variable particle counts per frame
    xyz = [];
    n_total = 0;
    sim_params = struct('width', 800, 'height', 400, 'drive_frequency', freq, 'drive_amplitude', 2.0);

    try
        % Load params first (small file)
        if exist(par_path, 'file')
            pd = load(par_path);
            sim_params = pd.sim_params;
        end

        % Load plist
        ld = load(plist_path, 'plist');
        plist = ld.plist;
        clear ld;  % Free memory immediately

        % Get frame IDs
        frame_col = plist(:, 4);
        all_frame_ids = unique(frame_col);
        n_total = length(all_frame_ids);

        % Calculate frame range
        first_idx = max(1, round(start_pct/100 * n_total) + 1);
        last_idx  = min(n_total, round(end_pct/100 * n_total));
        if last_idx < first_idx + 1
            last_idx = min(first_idx + 1, n_total);
        end

        frame_ids = all_frame_ids(first_idx:last_idx);
        n_frames = length(frame_ids);

        % Count particles in first frame to allocate
        n_particles = sum(frame_col == frame_ids(1));
        xyz = zeros(n_particles, 3, n_frames);

        % Extract frames - handle variable particle counts safely
        for ff = 1:n_frames
            mask = (frame_col == frame_ids(ff));
            frame_data = plist(mask, 1:3);
            n_in_frame = size(frame_data, 1);
            % Use minimum to avoid index errors if particle count varies
            n_use = min(n_in_frame, n_particles);
            xyz(1:n_use, :, ff) = frame_data(1:n_use, :);
        end

        clear plist frame_col;

    catch ME
        warning('Load error: %s', ME.message);
        xyz = [];
    end
end

function kymo = compute_kymograph_fast(xyz, x0, W)
%% Pre-compute kymograph using vectorized operations
    n_fr = size(xyz, 3);
    n_bins = 80;
    edges = linspace(0, W, n_bins+1);

    % Pre-compute bin assignments (only once)
    bin_idx = discretize(x0, edges);
    valid = ~isnan(bin_idx);

    % Extract all x-displacements at once
    x_all = squeeze(xyz(:, 1, :));  % [n_particles x n_frames]
    dx_all = x_all - x0;  % Displacement from equilibrium

    % Compute kymograph using accumarray for speed
    kymo = zeros(n_bins, n_fr);
    for b = 1:n_bins
        mask = (bin_idx == b) & valid;
        if any(mask)
            kymo(b, :) = mean(dx_all(mask, :), 1);
        end
    end
end

function [rows, cols] = get_grid_size(n)
    % Determine grid layout for n panels
    if n == 1
        rows = 1; cols = 1;
    elseif n == 2
        rows = 1; cols = 2;
    elseif n <= 4
        rows = 2; cols = 2;
    elseif n <= 6
        rows = 2; cols = 3;
    else
        rows = 3; cols = 3;
    end
end

%% ==================== RENDERING ====================

function render(fig)
    S = fig.UserData;

    for idx = 1:length(S.axs)
        ax = S.axs{idx};
        if idx > length(S.selected_types); continue; end
        st = S.selected_types{idx};

        if ~isfield(S.data, st) || isempty(S.data.(st))
            cla(ax);
            text(ax, 0.5, 0.5, 'No data', 'Color', 'w', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
            continue;
        end

        xyz = S.data.(st);
        n_fr = size(xyz,3);
        fr = min(S.frame, n_fr);
        p = S.params.(st);
        W = p.width; H = p.height;

        switch S.view_mode
            case 'particles'
                draw_particles(ax, xyz, fr, W, H);
            case 'wavefront'
                x0 = S.x0_cache.(st);
                draw_wavefront_fast(ax, xyz, fr, W, x0);
            case 'kymograph'
                kymo = S.kymo_cache.(st);
                draw_kymograph_fast(ax, kymo, W);
        end
    end
end

function draw_particles(ax, xyz, fr, W, H)
    cla(ax); hold(ax,'on');
    x = xyz(:,1,fr); y = xyz(:,2,fr); z = xyz(:,3,fr);
    zn = (z - min(z)) / (max(z)-min(z)+eps);
    scatter(ax, x, y, 6, [zn, zeros(size(zn)), 1-zn], 'filled');
    xlim(ax,[0 W]); ylim(ax,[0 H]); axis(ax,'equal');
    set(ax,'Color','k'); hold(ax,'off');
end

function draw_wavefront_fast(ax, xyz, fr, W, x0)
    cla(ax); hold(ax,'on');
    x  = xyz(:,1,fr);
    dx = x - x0;

    n_bins = 60;
    edges  = linspace(0, W, n_bins+1);
    ctrs   = (edges(1:end-1)+edges(2:end))/2;

    % Use discretize for faster binning
    bin_idx = discretize(x0, edges);
    avg_dx = zeros(n_bins,1);
    for b = 1:n_bins
        mask = (bin_idx == b);
        if any(mask)
            avg_dx(b) = mean(dx(mask));
        end
    end

    plot(ax, ctrs, avg_dx, 'c-', 'LineWidth', 2);
    yline(ax, 0, '--', 'Color', [0.5 0.5 0.5]);
    xlim(ax,[0 W]);
    ymax = max(0.5, max(abs(avg_dx)) * 1.5);
    ylim(ax, [-ymax, ymax]);
    xlabel(ax,'X position (px)'); ylabel(ax,'Displacement (px)');
    set(ax,'Color','k');
    % Set plot box aspect ratio so y variations are visible (3:1 width:height)
    pbaspect(ax, [3 1 1]);
    hold(ax,'off');
end

function draw_kymograph_fast(ax, kymo, W)
    % Use pre-computed kymograph
    cla(ax);
    n_bins = size(kymo, 1);
    n_fr = size(kymo, 2);
    edges = linspace(0, W, n_bins+1);
    ctrs = (edges(1:end-1)+edges(2:end))/2;

    imagesc(ax, 1:n_fr, ctrs, kymo);
    colormap(ax,'jet');
    cmax = max(0.5, max(abs(kymo(:))) * 1.2);
    clim(ax, [-cmax, cmax]);
    xlabel(ax,'Frame'); ylabel(ax,'X position (px)');
    set(ax,'YDir','normal');
    % Set aspect ratio so kymograph isn't too stretched (2:1 width:height)
    pbaspect(ax, [2 1 1]);
end
