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

% ---- simulation + axis checkboxes ----
% Each sim has X and Y checkboxes - check any combination you want
uilabel(cp, 'Text', 'Show Views:', 'Position', [8 898 100 18], 'FontColor', 'w', 'FontWeight', 'bold');
uilabel(cp, 'Text', 'X', 'Position', [145 898 20 18], 'FontColor', 'w', 'FontWeight', 'bold');
uilabel(cp, 'Text', 'Y', 'Position', [175 898 20 18], 'FontColor', 'w', 'FontWeight', 'bold');

cb_labels = {'Chevron', 'Stripe', 'Random', 'Top-driven', 'Frust Side', 'Frust Top'};
cb_x = cell(6,1);  % X axis checkboxes
cb_y = cell(6,1);  % Y axis checkboxes
for i = 1:6
    y_pos = 898 - i*20;
    uilabel(cp, 'Text', cb_labels{i}, 'Position', [8 y_pos 130 18], 'FontColor', 'w');
    % Default: X checked for first 4 sims
    cb_x{i} = uicheckbox(cp, 'Text', '', 'Value', (i <= 4), ...
        'Position', [140 y_pos 25 18], 'FontColor', 'w');
    cb_y{i} = uicheckbox(cp, 'Text', '', 'Value', false, ...
        'Position', [170 y_pos 25 18], 'FontColor', 'w');
end

% frequency controls
uilabel(cp, 'Text', 'Frequency:', 'Position', [8 768 70 18], 'FontColor', 'w');
cb_manual_freq = uicheckbox(cp, 'Text', 'Manual', 'Value', false, ...
    'Position', [85 768 70 18], 'FontColor', 'w');

% Slider mode (default)
sl_freq = uislider(cp, 'Position', [8 738 200 3], ...
    'Limits', [1 length(all_frequencies)], 'Value', 1, ...
    'MajorTicks', [], 'MinorTicks', []);
lbl_freq = uilabel(cp, 'Text', sprintf('f = %.4f', all_frequencies(1)), ...
    'Position', [8 708 200 24], 'FontColor', 'cyan', 'FontSize', 13, ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% Manual mode text field (hidden by default)
txt_manual_freq = uitextarea(cp, 'Value', {'0.001, 0.002, 0.005'}, ...
    'Position', [8 708 200 50], 'Visible', 'off', ...
    'FontSize', 10, 'BackgroundColor', [0.15 0.15 0.15], 'FontColor', 'cyan');
lbl_manual_help = uilabel(cp, 'Text', 'Comma-separated frequencies', ...
    'Position', [8 688 200 18], 'FontColor', [0.5 0.5 0.5], 'FontSize', 9, 'Visible', 'off');

% view mode
uilabel(cp, 'Text', 'View Mode:', 'Position', [8 678 200 18], 'FontColor', 'w');
btn_part = uibutton(cp, 'Text', 'Particles',  'Position', [8  651 66 24], 'BackgroundColor', [0.3 0.6 0.3]);
btn_wave = uibutton(cp, 'Text', 'Wavefront',  'Position', [78 651 66 24], 'BackgroundColor', [0.4 0.4 0.4]);
btn_kymo = uibutton(cp, 'Text', 'Kymograph', 'Position', [148 651 66 24], 'BackgroundColor', [0.4 0.4 0.4]);

% playback
uilabel(cp, 'Text', 'Playback:', 'Position', [8 618 200 18], 'FontColor', 'w');
btn_play  = uibutton(cp, 'Text', '▶ Play',  'Position', [8  591 100 24], 'BackgroundColor', [0.3 0.5 0.3]);
btn_step  = uibutton(cp, 'Text', 'Step ▶',  'Position', [112 591 100 24], 'BackgroundColor', [0.4 0.4 0.4]);
btn_reset = uibutton(cp, 'Text', '⟲ Reset', 'Position', [8  563 100 24], 'BackgroundColor', [0.4 0.4 0.4]);

uilabel(cp, 'Text', 'Frame:', 'Position', [8 533 200 18], 'FontColor', 'w');
sl_frame  = uislider(cp, 'Position', [8 503 200 3], 'Limits', [1 100], 'Value', 1, ...
    'MajorTicks', [], 'MinorTicks', []);
lbl_frame = uilabel(cp, 'Text', 'Frame: 1 / 100', 'Position', [8 473 200 24], ...
    'FontColor', 'w', 'HorizontalAlignment', 'center');

uilabel(cp, 'Text', 'Speed:', 'Position', [8 443 60 18], 'FontColor', 'w');
dd_speed = uidropdown(cp, 'Items', {'0.25x','0.5x','1x','2x','4x'}, 'Value', '1x', ...
    'Position', [70 441 80 24]);

% ---- load range ----
uilabel(cp, 'Text', 'Load range (%):', 'Position', [8 408 200 18], 'FontColor', 'w');
dd_range_start = uidropdown(cp, ...
    'Items', {'0%','10%','20%','30%','40%','50%','60%','70%','80%','90%'}, ...
    'Value', '0%', 'Position', [8 383 90 24]);
uilabel(cp, 'Text', 'to', 'Position', [102 386 18 18], 'FontColor', 'w');
dd_range_end = uidropdown(cp, ...
    'Items', {'20%','30%','40%','50%','60%','70%','80%','90%','100%'}, ...
    'Value', '20%', 'Position', [122 383 90 24]);

% ---- run button ----
btn_load = uibutton(cp, 'Text', 'Run', 'Position', [8 343 204 30], ...
    'BackgroundColor', [0.2 0.5 0.3], 'FontSize', 14, 'FontWeight', 'bold');

% ---- status ----
uilabel(cp, 'Text', 'Status:', 'Position', [8 313 200 18], 'FontColor', 'w');
txt_status = uitextarea(cp, 'Position', [8 95 204 216], 'Editable', 'off', ...
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
S.ymax_cache      = struct();   % Pre-computed max displacement for y-axis scaling
S.topdriven_cache = struct();   % Whether sim is top-driven (uses Y axis)
% UI handles
S.fig             = fig;
S.cb_x            = cb_x;      % X axis checkboxes for each sim
S.cb_y            = cb_y;      % Y axis checkboxes for each sim
S.sl_freq         = sl_freq;
S.sl_frame        = sl_frame;
S.lbl_freq        = lbl_freq;
S.lbl_frame       = lbl_frame;
S.cb_manual_freq  = cb_manual_freq;
S.txt_manual_freq = txt_manual_freq;
S.lbl_manual_help = lbl_manual_help;
S.manual_freqs    = [];  % Parsed manual frequencies
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
sl_freq.ValueChangedFcn   = @(~,~) cb_freq_label(fig);   % label only, no load
sl_frame.ValueChangedFcn  = @(~,~) cb_frame(fig);
btn_play.ButtonPushedFcn  = @(~,~) cb_play(fig);
btn_step.ButtonPushedFcn  = @(~,~) cb_step(fig);
btn_reset.ButtonPushedFcn = @(~,~) cb_reset(fig);
btn_load.ButtonPushedFcn  = @(~,~) cb_load(fig, true);
btn_part.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'particles');
btn_wave.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'wavefront');
btn_kymo.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'kymograph');
dd_speed.ValueChangedFcn  = @(src,~) cb_speed(fig, src.Value);
cb_manual_freq.ValueChangedFcn = @(~,~) cb_toggle_manual(fig);

% Checkboxes do NOT auto-load - user clicks Run when ready
% (no ValueChangedFcn set)

fig.CloseRequestFcn = @(~,~) cb_close(fig);

% Don't auto-load on startup - wait for user to click Load
S.txt_status.Value = {'Select simulations and click Load'};
fig.UserData = S;
end

%% ==================== CALLBACKS ====================

function cb_freq_label(fig)
    % Just update the frequency label - loading happens on button press
    S = fig.UserData;
    S.freq_idx = round(S.sl_freq.Value);
    S.lbl_freq.Text = sprintf('f = %.4f', S.frequencies(S.freq_idx));
    fig.UserData = S;
end

function cb_toggle_manual(fig)
    % Toggle between slider and manual frequency entry
    S = fig.UserData;
    is_manual = S.cb_manual_freq.Value;

    if is_manual
        % Show text field, hide slider
        S.sl_freq.Visible = 'off';
        S.lbl_freq.Visible = 'off';
        S.txt_manual_freq.Visible = 'on';
        S.lbl_manual_help.Visible = 'on';
    else
        % Show slider, hide text field
        S.sl_freq.Visible = 'on';
        S.lbl_freq.Visible = 'on';
        S.txt_manual_freq.Visible = 'off';
        S.lbl_manual_help.Visible = 'off';
    end
    fig.UserData = S;
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

function cb_load(fig, force_reload)
    S = fig.UserData;

    % Determine which frequencies to use
    is_manual = S.cb_manual_freq.Value;
    if is_manual
        % Parse manual frequencies
        txt = strjoin(S.txt_manual_freq.Value, ' ');
        parts = strsplit(txt, {',', ' ', ';'});
        parts = parts(~cellfun(@isempty, parts));

        freqs_to_use = [];
        for k = 1:length(parts)
            val = str2double(strtrim(parts{k}));
            if isnan(val)
                S.txt_status.Value = {sprintf('ERROR: Invalid frequency "%s"', parts{k})};
                fig.UserData = S;
                return;
            end
            % Check if frequency is in the valid list (find closest match)
            [min_diff, idx] = min(abs(S.frequencies - val));
            if min_diff > 1e-6
                S.txt_status.Value = {sprintf('ERROR: Frequency %.4f not found', val), ...
                    'Valid: 0.0004 to 0.10'};
                fig.UserData = S;
                return;
            end
            freqs_to_use(end+1) = S.frequencies(idx);
        end

        if isempty(freqs_to_use)
            S.txt_status.Value = {'ERROR: No valid frequencies entered'};
            fig.UserData = S;
            return;
        end
        S.manual_freqs = unique(freqs_to_use);  % Remove duplicates
    else
        % Single frequency from slider
        S.manual_freqs = S.frequencies(S.freq_idx);
    end

    % Get load range
    start_pct = str2double(strtrim(strrep(S.dd_range_start.Value, '%', '')));
    end_pct   = str2double(strtrim(strrep(S.dd_range_end.Value,   '%', '')));

    % Find which (sim, axis) pairs are selected
    % selected_views: array of structs with .sim_idx, .use_y, .label
    selected_views = {};
    for i = 1:6
        st = S.all_sim_types{i};
        st_upper = upper(st);
        if S.cb_x{i}.Value
            selected_views{end+1} = struct('sim_idx', i, 'use_y', false, 'label', [st_upper ' (X)']);
        end
        if S.cb_y{i}.Value
            selected_views{end+1} = struct('sim_idx', i, 'use_y', true, 'label', [st_upper ' (Y)']);
        end
    end

    if isempty(selected_views)
        S.txt_status.Value = {'No views selected - check X or Y boxes'};
        fig.UserData = S;
        return;
    end

    % Delete old panels
    for i = 1:length(S.panels)
        if isvalid(S.panels{i}); delete(S.panels{i}); end
    end
    S.panels = {};
    S.axs = {};
    S.view_configs = {};  % Store (sim_type, use_y) for each panel

    % Create new panels for selected views
    n_sel = length(selected_views);
    [rows, cols] = get_grid_size(n_sel);
    pa = S.plot_area;  % [x, y, w, h]
    pw = floor((pa(3) - (cols-1)*8) / cols);
    ph = floor((pa(4) - (rows-1)*8) / rows);

    lines_out = {};
    max_frames = 1;
    S.data = struct();       % S.data.(sim_type) = xyz for first/single frequency
    S.params = struct();
    S.multi_freq_data = struct();  % S.multi_freq_data.(sim_type){freq_idx} = xyz

    % First pass: load all needed simulations for ALL frequencies
    sims_needed = unique(cellfun(@(v) v.sim_idx, selected_views));
    freqs_to_load = S.manual_freqs;

    for k = 1:length(sims_needed)
        i = sims_needed(k);
        st = S.all_sim_types{i};
        S.multi_freq_data.(st) = {};

        for fi = 1:length(freqs_to_load)
            freq = freqs_to_load(fi);

            % Build cache key
            cache_key = sprintf('%s_f%.4f_r%d_%d', st, freq, start_pct, end_pct);
            cache_key = matlab.lang.makeValidName(cache_key);

            % Check cache first
            if ~force_reload && isfield(S.cache, cache_key)
                cached = S.cache.(cache_key);
                S.multi_freq_data.(st){fi} = cached.xyz;
                if fi == 1
                    S.data.(st) = cached.xyz;
                    S.params.(st) = cached.params;
                end
                max_frames = max(max_frames, size(cached.xyz, 3));
                if fi == 1
                    lines_out = [lines_out; {sprintf('%s f=%.4f: %d fr (cached)', upper(st), freq, size(cached.xyz, 3))}];
                end
                continue;
            end

            % Load data from disk
            sim_name = sprintf(S.all_name_fmts{i}, freq);
            plist_path = fullfile(S.base_path, S.all_sim_folders{i}, 'simulations', sim_name, 'plist.mat');
            par_path   = fullfile(S.base_path, S.all_sim_folders{i}, 'simulations', sim_name, 'sim_params.mat');

            if ~exist(plist_path, 'file')
                S.multi_freq_data.(st){fi} = [];
                if fi == 1
                    S.data.(st) = [];
                    S.params.(st) = [];
                    lines_out = [lines_out; {sprintf('%s f=%.4f: not found', upper(st), freq)}];
                end
                continue;
            end

            try
                [xyz, n_total, sim_p] = load_simulation_fast(plist_path, par_path, freq, start_pct, end_pct);

                if isempty(xyz)
                    S.multi_freq_data.(st){fi} = [];
                    if fi == 1
                        S.data.(st) = [];
                        S.params.(st) = [];
                        lines_out = [lines_out; {sprintf('%s f=%.4f: load failed', upper(st), freq)}];
                    end
                    continue;
                end

                S.multi_freq_data.(st){fi} = xyz;
                if fi == 1
                    S.data.(st) = xyz;
                    S.params.(st) = sim_p;
                end
                n_frames = size(xyz, 3);

                % Store in cache
                S.cache.(cache_key) = struct('xyz', xyz, 'params', sim_p);

                max_frames = max(max_frames, n_frames);
                if fi == 1 || length(freqs_to_load) <= 3
                    lines_out = [lines_out; {sprintf('%s f=%.4f: %d/%d fr', upper(st), freq, n_frames, n_total)}];
                end
            catch ME
                S.multi_freq_data.(st){fi} = [];
                if fi == 1
                    S.data.(st) = [];
                end
                lines_out = [lines_out; {sprintf('%s f=%.4f: ERR - %s', upper(st), freq, ME.message)}];
            end
        end  % end frequency loop
    end  % end sim loop

    % Second pass: create panels for each (sim, axis) view
    for idx = 1:n_sel
        v = selected_views{idx};
        i = v.sim_idx;
        st = S.all_sim_types{i};

        % Store view config
        S.view_configs{end+1} = struct('sim_type', st, 'use_y', v.use_y);

        % Calculate grid position
        row = ceil(idx / cols);
        col = mod(idx-1, cols) + 1;
        px = pa(1) + (col-1) * (pw + 8);
        py = pa(2) + pa(4) - row * ph - (row-1)*8;

        % Create panel with axis label in title
        pan = uipanel(S.fig, 'Title', v.label, ...
            'Position', [px py pw ph], ...
            'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', 'w', 'FontWeight', 'bold');
        ax = uiaxes(pan, 'Position', [8 8 pw-18 ph-38], ...
            'Color', 'k', 'XColor', 'w', 'YColor', 'w');
        ax.Toolbar.Visible = 'off';

        S.panels{end+1} = pan;
        S.axs{end+1} = ax;
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

    fprintf('  Starting load...\n');

    try
        % Load params first (small file)
        fprintf('  Checking params file: %s\n', par_path);
        if exist(par_path, 'file')
            fprintf('  Params file exists, loading...\n');
            pd = load(par_path);
            fprintf('  Params loaded, fields: %s\n', strjoin(fieldnames(pd), ', '));
            if isfield(pd, 'sim_params')
                sim_params = pd.sim_params;
                fprintf('  sim_params fields: %s\n', strjoin(fieldnames(sim_params), ', '));
                if isfield(sim_params, 'width') && isfield(sim_params, 'height')
                    fprintf('  Params: width=%d, height=%d\n', sim_params.width, sim_params.height);
                else
                    fprintf('  WARNING: sim_params missing width/height\n');
                end
            else
                fprintf('  WARNING: No sim_params field in params file\n');
            end
        else
            fprintf('  No params file, using defaults\n');
        end

        % Load plist
        fprintf('  Loading plist from: %s\n', plist_path);
        ld = load(plist_path, 'plist');
        plist = ld.plist;
        fprintf('  plist size: %d x %d\n', size(plist, 1), size(plist, 2));
        clear ld;  % Free memory immediately

        % Get frame IDs
        frame_col = plist(:, 4);
        all_frame_ids = unique(frame_col);
        n_total = length(all_frame_ids);
        fprintf('  Total frames: %d, frame ID range: %.1f to %.1f\n', n_total, min(all_frame_ids), max(all_frame_ids));

        % Calculate frame range
        first_idx = max(1, round(start_pct/100 * n_total) + 1);
        last_idx  = min(n_total, round(end_pct/100 * n_total));
        if last_idx < first_idx + 1
            last_idx = min(first_idx + 1, n_total);
        end

        frame_ids = all_frame_ids(first_idx:last_idx);
        n_frames = length(frame_ids);
        fprintf('  Loading frames %d to %d (%d frames)\n', first_idx, last_idx, n_frames);

        % Count particles in each frame to check consistency
        particles_per_frame = zeros(n_frames, 1);
        for ff = 1:n_frames
            particles_per_frame(ff) = sum(frame_col == frame_ids(ff));
        end
        fprintf('  Particles per frame: min=%d, max=%d, first=%d\n', ...
            min(particles_per_frame), max(particles_per_frame), particles_per_frame(1));

        % Use first frame's particle count
        n_particles = particles_per_frame(1);
        xyz = zeros(n_particles, 3, n_frames);

        % Extract frames - handle variable particle counts safely
        for ff = 1:n_frames
            mask = (frame_col == frame_ids(ff));
            frame_data = plist(mask, 1:3);
            n_in_frame = size(frame_data, 1);
            n_use = min(n_in_frame, n_particles);
            if n_use > 0
                xyz(1:n_use, :, ff) = frame_data(1:n_use, :);
            end
            if n_in_frame ~= n_particles && ff <= 5
                fprintf('  Frame %d: expected %d particles, got %d\n', ff, n_particles, n_in_frame);
            end
        end

        clear plist frame_col;
        fprintf('  Successfully loaded xyz: %d x %d x %d\n', size(xyz,1), size(xyz,2), size(xyz,3));

    catch ME
        fprintf('  ERROR: %s\n', ME.message);
        fprintf('  Error ID: %s\n', ME.identifier);
        for k = 1:length(ME.stack)
            fprintf('  Stack[%d]: %s line %d\n', k, ME.stack(k).name, ME.stack(k).line);
        end
        warning('Load error: %s', ME.message);
        xyz = [];
    end
end

function kymo = compute_kymograph_fast(xyz, pos0, axis_len, is_topdriven)
%% Pre-compute kymograph using vectorized operations
    n_fr = size(xyz, 3);
    n_bins = 80;
    edges = linspace(0, axis_len, n_bins+1);

    % Pre-compute bin assignments (only once)
    bin_idx = discretize(pos0, edges);
    valid = ~isnan(bin_idx);

    % Top-driven: use Y, Side-driven: use X
    if is_topdriven
        pos_all = squeeze(xyz(:, 2, :));  % [n_particles x n_frames]
    else
        pos_all = squeeze(xyz(:, 1, :));  % [n_particles x n_frames]
    end
    dpos_all = pos_all - pos0;  % Displacement from equilibrium

    % Compute kymograph
    kymo = zeros(n_bins, n_fr);
    for b = 1:n_bins
        mask = (bin_idx == b) & valid;
        if any(mask)
            kymo(b, :) = mean(dpos_all(mask, :), 1);
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

    % Check if view_configs exists
    if ~isfield(S, 'view_configs') || isempty(S.view_configs)
        return;
    end

    for idx = 1:length(S.axs)
        ax = S.axs{idx};
        if idx > length(S.view_configs); continue; end

        % Get view configuration (sim type and axis)
        vc = S.view_configs{idx};
        st = vc.sim_type;
        use_y = vc.use_y;

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

        if use_y
            axis_len = H;
        else
            axis_len = W;
        end

        switch S.view_mode
            case 'particles'
                draw_particles(ax, xyz, fr, W, H);
            case 'wavefront'
                % Pass multi-frequency data for overlay
                if isfield(S, 'multi_freq_data') && isfield(S.multi_freq_data, st)
                    multi_data = S.multi_freq_data.(st);
                else
                    multi_data = {xyz};
                end
                draw_wavefront_multifreq(ax, multi_data, S.manual_freqs, fr, axis_len, use_y);
            case 'kymograph'
                draw_kymograph_dynamic(ax, xyz, axis_len, use_y);
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

function draw_wavefront_multifreq(ax, multi_data, freqs, fr, axis_len, use_y)
    % Plot wavefronts for multiple frequencies overlaid
    cla(ax); hold(ax,'on');

    % Color palette for different frequencies
    colors = [0 1 1;      % cyan
              1 0.5 0;    % orange
              0 1 0;      % green
              1 0 1;      % magenta
              1 1 0;      % yellow
              0.5 0.5 1;  % light blue
              1 0.5 0.5;  % light red
              0.5 1 0.5]; % light green

    n_bins = 60;
    edges = linspace(0, axis_len, n_bins+1);
    ctrs = (edges(1:end-1)+edges(2:end))/2;

    global_ymax = 0.5;
    legend_entries = {};

    for fi = 1:length(multi_data)
        xyz = multi_data{fi};
        if isempty(xyz); continue; end

        n_frames = size(xyz, 3);
        n_eq = min(10, n_frames);
        frame = min(fr, n_frames);

        if use_y
            pos = xyz(:,2,frame);
            pos0 = mean(xyz(:,2,1:n_eq), 3);
            all_dpos = squeeze(xyz(:,2,:)) - pos0;
        else
            pos = xyz(:,1,frame);
            pos0 = mean(xyz(:,1,1:n_eq), 3);
            all_dpos = squeeze(xyz(:,1,:)) - pos0;
        end
        dpos = pos - pos0;

        % Update global max
        global_ymax = max(global_ymax, max(abs(all_dpos(:))) * 1.1);

        % Bin and average
        bin_idx = discretize(pos0, edges);
        avg_dpos = zeros(n_bins,1);
        for b = 1:n_bins
            mask = (bin_idx == b);
            if any(mask)
                avg_dpos(b) = mean(dpos(mask));
            end
        end

        % Plot with color
        c_idx = mod(fi-1, size(colors,1)) + 1;
        plot(ax, ctrs, avg_dpos, '-', 'LineWidth', 2, 'Color', colors(c_idx,:));
        legend_entries{end+1} = sprintf('f=%.4f', freqs(fi));
    end

    yline(ax, 0, '--', 'Color', [0.5 0.5 0.5]);
    xlim(ax,[0 axis_len]);
    ylim(ax, [-global_ymax, global_ymax]);

    if use_y
        xlabel(ax, 'Y position (px)');
    else
        xlabel(ax, 'X position (px)');
    end
    ylabel(ax,'Displacement (px)');

    % Add legend if multiple frequencies
    if length(legend_entries) > 1
        legend(ax, legend_entries, 'Location', 'best', 'TextColor', 'w', 'Color', [0.2 0.2 0.2]);
    end

    set(ax,'Color','k');
    hold(ax,'off');
end

function draw_wavefront_dynamic(ax, xyz, fr, axis_len, use_y_axis)
    % Compute wavefront on-the-fly with user-selected axis
    cla(ax); hold(ax,'on');

    n_frames = size(xyz, 3);
    n_eq = min(10, n_frames);

    if use_y_axis
        pos = xyz(:,2,fr);  % Y position
        pos0 = mean(xyz(:,2,1:n_eq), 3);  % Equilibrium Y
        axis_label = 'Y position (px)';
    else
        pos = xyz(:,1,fr);  % X position
        pos0 = mean(xyz(:,1,1:n_eq), 3);  % Equilibrium X
        axis_label = 'X position (px)';
    end
    dpos = pos - pos0;

    n_bins = 60;
    edges  = linspace(0, axis_len, n_bins+1);
    ctrs   = (edges(1:end-1)+edges(2:end))/2;

    bin_idx = discretize(pos0, edges);
    avg_dpos = zeros(n_bins,1);
    for b = 1:n_bins
        mask = (bin_idx == b);
        if any(mask)
            avg_dpos(b) = mean(dpos(mask));
        end
    end

    % Compute y-max for this axis
    if use_y_axis
        all_dpos = squeeze(xyz(:,2,:)) - pos0;
    else
        all_dpos = squeeze(xyz(:,1,:)) - pos0;
    end
    global_ymax = max(0.5, max(abs(all_dpos(:))) * 1.1);

    plot(ax, ctrs, avg_dpos, 'c-', 'LineWidth', 2);
    yline(ax, 0, '--', 'Color', [0.5 0.5 0.5]);
    xlim(ax,[0 axis_len]);
    ylim(ax, [-global_ymax, global_ymax]);
    xlabel(ax, axis_label); ylabel(ax,'Displacement (px)');
    set(ax,'Color','k');
    hold(ax,'off');
end

function draw_wavefront_fast(ax, xyz, fr, axis_len, pos0, global_ymax, is_topdriven)
    cla(ax); hold(ax,'on');

    % Top-driven: use Y position and Y displacement
    % Side-driven: use X position and X displacement
    if is_topdriven
        pos = xyz(:,2,fr);  % Y position
        axis_label = 'Y position (px)';
    else
        pos = xyz(:,1,fr);  % X position
        axis_label = 'X position (px)';
    end
    dpos = pos - pos0;

    n_bins = 60;
    edges  = linspace(0, axis_len, n_bins+1);
    ctrs   = (edges(1:end-1)+edges(2:end))/2;

    % Use discretize for faster binning
    bin_idx = discretize(pos0, edges);
    avg_dpos = zeros(n_bins,1);
    for b = 1:n_bins
        mask = (bin_idx == b);
        if any(mask)
            avg_dpos(b) = mean(dpos(mask));
        end
    end

    plot(ax, ctrs, avg_dpos, 'c-', 'LineWidth', 2);
    yline(ax, 0, '--', 'Color', [0.5 0.5 0.5]);
    xlim(ax,[0 axis_len]);
    ylim(ax, [-global_ymax, global_ymax]);
    xlabel(ax, axis_label); ylabel(ax,'Displacement (px)');
    set(ax,'Color','k');
    hold(ax,'off');
end

function draw_kymograph_dynamic(ax, xyz, axis_len, use_y)
    % Compute kymograph on-the-fly with selected axis
    cla(ax);
    n_fr = size(xyz, 3);
    n_bins = 80;
    edges = linspace(0, axis_len, n_bins+1);
    ctrs = (edges(1:end-1)+edges(2:end))/2;

    % Compute equilibrium positions
    n_eq = min(10, n_fr);
    if use_y
        pos0 = mean(xyz(:,2,1:n_eq), 3);
        pos_all = squeeze(xyz(:, 2, :));
        ylabel_str = 'Y position (px)';
    else
        pos0 = mean(xyz(:,1,1:n_eq), 3);
        pos_all = squeeze(xyz(:, 1, :));
        ylabel_str = 'X position (px)';
    end
    dpos_all = pos_all - pos0;

    % Bin particles
    bin_idx = discretize(pos0, edges);
    valid = ~isnan(bin_idx);

    kymo = zeros(n_bins, n_fr);
    for b = 1:n_bins
        mask = (bin_idx == b) & valid;
        if any(mask)
            kymo(b, :) = mean(dpos_all(mask, :), 1);
        end
    end

    imagesc(ax, 1:n_fr, ctrs, kymo);
    colormap(ax,'jet');
    cmax = max(0.5, max(abs(kymo(:))) * 1.2);
    clim(ax, [-cmax, cmax]);
    xlabel(ax,'Frame'); ylabel(ax, ylabel_str);
    set(ax,'YDir','normal');
end

function draw_kymograph_fast(ax, kymo, axis_len, is_topdriven)
    % Use pre-computed kymograph (kept for compatibility)
    cla(ax);
    n_bins = size(kymo, 1);
    n_fr = size(kymo, 2);
    edges = linspace(0, axis_len, n_bins+1);
    ctrs = (edges(1:end-1)+edges(2:end))/2;

    imagesc(ax, 1:n_fr, ctrs, kymo);
    colormap(ax,'jet');
    cmax = max(0.5, max(abs(kymo(:))) * 1.2);
    clim(ax, [-cmax, cmax]);
    if is_topdriven
        ylabel_str = 'Y position (px)';
    else
        ylabel_str = 'X position (px)';
    end
    xlabel(ax,'Frame'); ylabel(ax, ylabel_str);
    set(ax,'YDir','normal');
end
