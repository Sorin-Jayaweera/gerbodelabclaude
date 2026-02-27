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

cb_labels = {'Chevron (side)', 'Stripe (side)', 'Random (side)', 'Chevron (top)', 'Frust (side)', 'Frust (top)'};
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
cb_multi_freq = uicheckbox(cp, 'Text', 'Multi', 'Value', false, ...
    'Position', [85 768 60 18], 'FontColor', 'w');

% Slider mode (default - single frequency)
sl_freq = uislider(cp, 'Position', [8 738 200 3], ...
    'Limits', [1 length(all_frequencies)], 'Value', 1, ...
    'MajorTicks', [], 'MinorTicks', []);
lbl_freq = uilabel(cp, 'Text', sprintf('f = %.4f', all_frequencies(1)), ...
    'Position', [8 708 200 24], 'FontColor', 'cyan', 'FontSize', 13, ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% Multi-frequency mode (hidden by default) - button to open selector + label showing selections
btn_select_freqs = uibutton(cp, 'Text', 'Select Frequencies...', ...
    'Position', [8 728 204 24], 'Visible', 'off', ...
    'BackgroundColor', [0.3 0.3 0.5]);
lbl_selected_freqs = uilabel(cp, 'Text', 'None selected', ...
    'Position', [8 703 204 24], 'FontColor', 'cyan', 'FontSize', 10, ...
    'Visible', 'off', 'HorizontalAlignment', 'center');

% view mode (2 rows of buttons)
uilabel(cp, 'Text', 'View Mode:', 'Position', [8 678 200 18], 'FontColor', 'w');
btn_part = uibutton(cp, 'Text', 'Particles',  'Position', [8  651 100 24], 'BackgroundColor', [0.3 0.6 0.3]);
btn_wave = uibutton(cp, 'Text', 'Wavefront',  'Position', [112 651 100 24], 'BackgroundColor', [0.4 0.4 0.4]);
btn_kymo = uibutton(cp, 'Text', 'Kymograph',  'Position', [8  624 100 24], 'BackgroundColor', [0.4 0.4 0.4]);
btn_dela = uibutton(cp, 'Text', 'Delaunay',   'Position', [112 624 100 24], 'BackgroundColor', [0.4 0.4 0.4]);

% Sync graphs checkbox
cb_sync_graphs = uicheckbox(cp, 'Text', 'Sync pan/zoom across panels', 'Value', false, ...
    'Position', [8 597 200 20], 'FontColor', 'w');

% playback (Step and Reset only - Play is combined with Load button)
uilabel(cp, 'Text', 'Playback:', 'Position', [8 570 200 18], 'FontColor', 'w');
btn_step  = uibutton(cp, 'Text', 'Step ▶',  'Position', [8  543 100 24], 'BackgroundColor', [0.4 0.4 0.4]);
btn_reset = uibutton(cp, 'Text', '⟲ Reset', 'Position', [112 543 100 24], 'BackgroundColor', [0.4 0.4 0.4]);

uilabel(cp, 'Text', 'Frame:', 'Position', [8 485 200 18], 'FontColor', 'w');
sl_frame  = uislider(cp, 'Position', [8 455 200 3], 'Limits', [1 100], 'Value', 1, ...
    'MajorTicks', [], 'MinorTicks', []);
lbl_frame = uilabel(cp, 'Text', 'Frame: 1 / 100', 'Position', [8 425 200 24], ...
    'FontColor', 'w', 'HorizontalAlignment', 'center');

uilabel(cp, 'Text', 'Speed:', 'Position', [8 395 60 18], 'FontColor', 'w');
dd_speed = uidropdown(cp, 'Items', {'0.5x','1x','2x','4x','6x','10x'}, 'Value', '1x', ...
    'Position', [70 393 80 24]);

% ---- load range ----
uilabel(cp, 'Text', 'Load range (%):', 'Position', [8 360 200 18], 'FontColor', 'w');
dd_range_start = uidropdown(cp, ...
    'Items', {'0%','10%','20%','30%','40%','50%','60%','70%','80%','90%'}, ...
    'Value', '0%', 'Position', [8 335 90 24]);
uilabel(cp, 'Text', 'to', 'Position', [102 338 18 18], 'FontColor', 'w');
dd_range_end = uidropdown(cp, ...
    'Items', {'20%','30%','40%','50%','60%','70%','80%','90%','100%'}, ...
    'Value', '20%', 'Position', [122 335 90 24]);

% ---- main action button (Load -> Play/Pause) and cancel ----
btn_action = uibutton(cp, 'Text', 'Load', 'Position', [8 295 105 30], ...
    'BackgroundColor', [0.2 0.5 0.3], 'FontSize', 14, 'FontWeight', 'bold');
btn_clear_cache = uibutton(cp, 'Text', '↻', 'Position', [115 295 32 30], ...
    'BackgroundColor', [0.3 0.3 0.4], 'FontSize', 14, ...
    'Tooltip', 'Clear cache and force reload');
btn_cancel = uibutton(cp, 'Text', 'Stop', 'Position', [150 295 62 30], ...
    'BackgroundColor', [0.5 0.2 0.2], 'FontSize', 11, 'Enable', 'off');

% ---- progress bar ----
lbl_progress = uilabel(cp, 'Text', '', 'Position', [8 270 204 18], ...
    'FontColor', 'cyan', 'FontSize', 10, 'HorizontalAlignment', 'center');
% Progress bar background
pnl_prog_bg = uipanel(cp, 'Position', [8 260 204 8], 'BorderType', 'none', ...
    'BackgroundColor', [0.3 0.3 0.3]);
% Progress bar fill (width will be adjusted during loading)
pnl_prog_fill = uipanel(cp, 'Position', [8 260 0 8], 'BorderType', 'none', ...
    'BackgroundColor', [0.2 0.7 0.4]);

% ---- video export ----
btn_video = uibutton(cp, 'Text', '🎬 Export Video', 'Position', [8 230 204 26], ...
    'BackgroundColor', [0.4 0.3 0.5], 'FontSize', 11, 'FontWeight', 'bold');

% ---- status ----
uilabel(cp, 'Text', 'Status:', 'Position', [8 205 200 18], 'FontColor', 'w');
txt_status = uitextarea(cp, 'Position', [8 65 204 138], 'Editable', 'off', ...
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
S.cb_multi_freq      = cb_multi_freq;
S.btn_select_freqs   = btn_select_freqs;
S.lbl_selected_freqs = lbl_selected_freqs;
S.selected_freq_idxs = [];  % Indices of selected frequencies (for multi mode)
S.manual_freqs       = [];  % Frequencies to use (single or multi)
S.btn_action      = btn_action;  % Combined Load/Play button
S.btn_clear_cache = btn_clear_cache;  % Clear cache button
S.btn_cancel      = btn_cancel;
S.cancel_loading  = false;  % Flag to cancel loading
S.data_loaded     = false;  % Whether data is loaded (button shows Play vs Load)
S.lbl_progress    = lbl_progress;   % Progress text
S.pnl_prog_fill   = pnl_prog_fill;  % Progress bar fill
S.btn_part        = btn_part;
S.btn_wave        = btn_wave;
S.btn_kymo        = btn_kymo;
S.btn_dela        = btn_dela;
S.btn_video       = btn_video;
S.cb_sync_graphs  = cb_sync_graphs;
S.txt_status      = txt_status;
S.dd_range_start  = dd_range_start;
S.dd_range_end    = dd_range_end;
% Plot area bounds
S.plot_area       = [plot_area_x, plot_area_y, plot_area_w, plot_area_h];
S.panels          = {};
S.axs             = {};
S.view_configs    = {};  % Store (sim_type, use_y) for each panel
S.selected_types  = {};  % Track currently displayed types
fig.UserData = S;

%% ==================== WIRE CALLBACKS ====================
sl_freq.ValueChangedFcn   = @(~,~) cb_config_changed(fig);  % Mark needs reload
sl_frame.ValueChangedFcn  = @(~,~) cb_frame(fig);
btn_step.ButtonPushedFcn  = @(~,~) cb_step(fig);
btn_reset.ButtonPushedFcn = @(~,~) cb_reset(fig);
btn_action.ButtonPushedFcn = @(~,~) cb_action(fig);  % Combined Load/Play
btn_clear_cache.ButtonPushedFcn = @(~,~) cb_clear_cache(fig);  % Clear cache
btn_cancel.ButtonPushedFcn = @(~,~) cb_cancel(fig);
btn_video.ButtonPushedFcn = @(~,~) cb_open_video_dialog(fig);
btn_part.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'particles');
btn_wave.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'wavefront');
btn_kymo.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'kymograph');
btn_dela.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'delaunay');
cb_sync_graphs.ValueChangedFcn = @(~,~) cb_toggle_sync(fig);
dd_speed.ValueChangedFcn  = @(src,~) cb_speed(fig, src.Value);
cb_multi_freq.ValueChangedFcn = @(~,~) cb_toggle_multi_freq(fig);
btn_select_freqs.ButtonPushedFcn = @(~,~) cb_open_freq_selector(fig);
dd_range_start.ValueChangedFcn = @(~,~) cb_config_changed(fig);
dd_range_end.ValueChangedFcn = @(~,~) cb_config_changed(fig);

% Checkboxes mark config as changed (needs reload)
for i = 1:6
    cb_x{i}.ValueChangedFcn = @(~,~) cb_config_changed(fig);
    cb_y{i}.ValueChangedFcn = @(~,~) cb_config_changed(fig);
end

fig.CloseRequestFcn = @(~,~) cb_close(fig);

% Don't auto-load on startup - wait for user to click Load
S.txt_status.Value = {'Select simulations and click Load'};
fig.UserData = S;
end

%% ==================== CALLBACKS ====================

function cb_config_changed(fig)
    % Called when any config changes - mark data as needing reload
    S = fig.UserData;

    % Update frequency label if slider mode (single frequency)
    if ~S.cb_multi_freq.Value
        S.freq_idx = round(S.sl_freq.Value);
        S.lbl_freq.Text = sprintf('f = %.4f', S.frequencies(S.freq_idx));
    end

    % Stop playback if playing
    if S.is_playing
        S.is_playing = false;
    end

    % Mark data as not loaded - button becomes "Load"
    S.data_loaded = false;
    S.btn_action.Text = 'Load';
    S.btn_action.BackgroundColor = [0.2 0.5 0.3];
    S.btn_cancel.Enable = 'off';

    fig.UserData = S;
end

function cb_toggle_multi_freq(fig)
    % Toggle between single frequency slider and multi-frequency selector
    S = fig.UserData;
    is_multi = S.cb_multi_freq.Value;

    if is_multi
        % Show multi-frequency selector, hide slider
        S.sl_freq.Visible = 'off';
        S.lbl_freq.Visible = 'off';
        S.btn_select_freqs.Visible = 'on';
        S.lbl_selected_freqs.Visible = 'on';
    else
        % Show slider, hide multi-selector
        S.sl_freq.Visible = 'on';
        S.lbl_freq.Visible = 'on';
        S.btn_select_freqs.Visible = 'off';
        S.lbl_selected_freqs.Visible = 'off';
    end

    % Mark as needing reload
    S.data_loaded = false;
    S.btn_action.Text = 'Load';
    S.btn_action.BackgroundColor = [0.2 0.5 0.3];

    fig.UserData = S;
end

function cb_open_freq_selector(fig)
    % Open a custom dialog with checkboxes to select multiple frequencies
    S = fig.UserData;
    n_freqs = length(S.frequencies);

    % Create dialog figure
    dlg_h = 30 + n_freqs * 22 + 50;  % Height based on number of frequencies
    dlg = uifigure('Name', 'Select Frequencies', ...
        'Position', [300 200 250 min(dlg_h, 600)], ...
        'Color', [0.2 0.2 0.2], 'Resize', 'off');

    % Title label
    uilabel(dlg, 'Text', 'Click to toggle frequencies:', ...
        'Position', [10 dlg.Position(4)-30 230 20], ...
        'FontColor', 'w', 'FontWeight', 'bold');

    % Create scrollable panel if too many frequencies
    if dlg_h > 600
        scroll_panel = uipanel(dlg, 'Position', [5 50 240 dlg.Position(4)-90], ...
            'BackgroundColor', [0.15 0.15 0.15], 'BorderType', 'none', ...
            'Scrollable', 'on');
        parent = scroll_panel;
        cb_y_base = n_freqs * 22;
    else
        parent = dlg;
        cb_y_base = dlg.Position(4) - 55;
    end

    % Create checkboxes for each frequency
    freq_cbs = cell(n_freqs, 1);
    for i = 1:n_freqs
        is_selected = ismember(i, S.selected_freq_idxs);
        y_pos = cb_y_base - i * 22;
        freq_cbs{i} = uicheckbox(parent, ...
            'Text', sprintf('f = %.4f', S.frequencies(i)), ...
            'Value', is_selected, ...
            'Position', [15 y_pos 200 20], ...
            'FontColor', 'w');
    end

    % Store checkbox handles in dialog
    dlg.UserData = struct('freq_cbs', {freq_cbs}, 'main_fig', fig);

    % OK and Cancel buttons
    uibutton(dlg, 'Text', 'OK', 'Position', [30 10 80 30], ...
        'BackgroundColor', [0.3 0.5 0.3], ...
        'ButtonPushedFcn', @(~,~) freq_selector_ok(dlg));
    uibutton(dlg, 'Text', 'Cancel', 'Position', [130 10 80 30], ...
        'BackgroundColor', [0.5 0.3 0.3], ...
        'ButtonPushedFcn', @(~,~) close(dlg));

    % Select All / Clear All buttons
    uibutton(dlg, 'Text', 'All', 'Position', [170 dlg.Position(4)-30 35 22], ...
        'BackgroundColor', [0.3 0.3 0.4], 'FontSize', 10, ...
        'ButtonPushedFcn', @(~,~) freq_selector_all(dlg, true));
    uibutton(dlg, 'Text', 'None', 'Position', [207 dlg.Position(4)-30 38 22], ...
        'BackgroundColor', [0.3 0.3 0.4], 'FontSize', 10, ...
        'ButtonPushedFcn', @(~,~) freq_selector_all(dlg, false));
end

function freq_selector_all(dlg, select_all)
    % Select or deselect all frequencies
    d = dlg.UserData;
    for i = 1:length(d.freq_cbs)
        d.freq_cbs{i}.Value = select_all;
    end
end

function freq_selector_ok(dlg)
    % Apply frequency selection and close dialog
    d = dlg.UserData;
    fig = d.main_fig;
    S = fig.UserData;

    % Get selected indices
    sel_idxs = [];
    for i = 1:length(d.freq_cbs)
        if d.freq_cbs{i}.Value
            sel_idxs(end+1) = i;
        end
    end

    if ~isempty(sel_idxs)
        S.selected_freq_idxs = sel_idxs;

        % Update label to show selected frequencies
        freq_labels = arrayfun(@(f) sprintf('%.4f', f), S.frequencies, 'UniformOutput', false);
        if length(sel_idxs) <= 3
            sel_str = strjoin(freq_labels(sel_idxs), ', ');
        else
            sel_str = sprintf('%d frequencies selected', length(sel_idxs));
        end
        S.lbl_selected_freqs.Text = sel_str;

        % Mark as needing reload
        S.data_loaded = false;
        S.btn_action.Text = 'Load';
        S.btn_action.BackgroundColor = [0.2 0.5 0.3];

        fig.UserData = S;
    end

    close(dlg);
end

function cb_action(fig)
    % Combined Load/Play button callback
    S = fig.UserData;

    if ~S.data_loaded
        % Data not loaded - do load (use cache for already-loaded sims)
        cb_load(fig, false);
    else
        % Data loaded - toggle play/pause
        cb_play(fig);
    end
end

function cb_cancel(fig)
    % Stop loading or playback
    S = fig.UserData;

    if S.is_playing
        % Stop playback
        S.is_playing = false;
        S.btn_action.Text = '▶ Play';
        S.btn_action.BackgroundColor = [0.3 0.5 0.3];
        S.btn_cancel.Enable = 'off';
        fig.UserData = S;
    else
        % Cancel loading
        S.cancel_loading = true;
        fig.UserData = S;
        S.txt_status.Value = [S.txt_status.Value; {'Cancelling...'}];
    end
end

function cb_clear_cache(fig)
    % Clear cache and force reload on next Load
    S = fig.UserData;
    S.cache = struct();
    S.data_loaded = false;
    S.btn_action.Text = 'Load';
    S.btn_action.BackgroundColor = [0.2 0.5 0.3];
    S.txt_status.Value = {'Cache cleared - click Load to reload'};
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
    S.btn_dela.BackgroundColor = dim;
    switch mode
        case 'particles',  S.btn_part.BackgroundColor = act;
        case 'wavefront',  S.btn_wave.BackgroundColor = act;
        case 'kymograph',  S.btn_kymo.BackgroundColor = act;
        case 'delaunay',   S.btn_dela.BackgroundColor = act;
    end
    fig.UserData = S;
    render(fig);
end

function cb_toggle_sync(fig)
    % Toggle synced pan/zoom across all panels
    S = fig.UserData;
    sync_enabled = S.cb_sync_graphs.Value;

    if isempty(S.axs)
        return;
    end

    % Get all valid axes handles
    valid_axs = [];
    for i = 1:length(S.axs)
        if isvalid(S.axs{i})
            valid_axs = [valid_axs, S.axs{i}];
        end
    end

    if isempty(valid_axs)
        return;
    end

    if sync_enabled
        % Link all axes for synchronized pan/zoom
        linkaxes(valid_axs, 'xy');
        S.txt_status.Value = [S.txt_status.Value; {'Sync enabled - pan/zoom synced across panels'}];
    else
        % Unlink axes
        linkaxes(valid_axs, 'off');
        S.txt_status.Value = [S.txt_status.Value; {'Sync disabled - panels independent'}];
    end

    fig.UserData = S;
end

function cb_play(fig)
    S = fig.UserData;
    if S.is_playing
        % Pause
        S.is_playing = false;
        S.btn_action.Text = '▶ Play';
        S.btn_action.BackgroundColor = [0.3 0.5 0.3];
        S.btn_cancel.Enable = 'off';
        fig.UserData = S;
    else
        % Play
        S.is_playing = true;
        S.btn_action.Text = '⏸ Pause';
        S.btn_action.BackgroundColor = [0.6 0.3 0.3];
        S.btn_cancel.Enable = 'on';
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
    if S.data_loaded
        S.btn_action.Text = '▶ Play';
        S.btn_action.BackgroundColor = [0.3 0.5 0.3];
    end
    S.btn_cancel.Enable = 'off';
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
        S.btn_action.Text = '▶ Play';
        S.btn_action.BackgroundColor = [0.3 0.5 0.3];
        fig.UserData = S;
        pause(0.15);
    end
    switch speed_str
        case '0.5x';  S.play_speed = 0.5;
        case '1x';    S.play_speed = 1;
        case '2x';    S.play_speed = 2;
        case '4x';    S.play_speed = 4;
        case '6x';    S.play_speed = 6;
        case '10x';   S.play_speed = 10;
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

    % Reset cancel flag at start of loading
    S.cancel_loading = false;

    % Update button to show loading state
    S.btn_action.Text = 'Loading...';
    S.btn_action.BackgroundColor = [0.5 0.5 0.3];
    S.btn_cancel.Enable = 'on';
    fig.UserData = S;
    drawnow;

    % Determine which frequencies to use
    is_multi = S.cb_multi_freq.Value;
    if is_multi
        % Use selected frequencies from dialog
        if isempty(S.selected_freq_idxs)
            S.txt_status.Value = {'ERROR: No frequencies selected', 'Click "Select Frequencies..." to choose'};
            S.btn_action.Text = 'Load';
            S.btn_action.BackgroundColor = [0.2 0.5 0.3];
            S.btn_cancel.Enable = 'off';
            fig.UserData = S;
            return;
        end
        S.manual_freqs = S.frequencies(S.selected_freq_idxs);
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

    % Save state before loading loops (so cancel checks get updated state)
    fig.UserData = S;

    % First pass: load all needed simulations for ALL frequencies
    sims_needed = unique(cellfun(@(v) v.sim_idx, selected_views));
    freqs_to_load = S.manual_freqs;

    % Clean cache: only keep entries for currently selected simulations
    if ~isempty(fieldnames(S.cache))
        cache_keys = fieldnames(S.cache);
        needed_prefixes = {};
        for k = 1:length(sims_needed)
            needed_prefixes{end+1} = S.all_sim_types{sims_needed(k)};
        end
        for k = 1:length(cache_keys)
            key = cache_keys{k};
            keep = false;
            for p = 1:length(needed_prefixes)
                if startsWith(key, needed_prefixes{p})
                    keep = true;
                    break;
                end
            end
            if ~keep
                S.cache = rmfield(S.cache, key);
            end
        end
    end

    % Progress tracking
    total_loads = length(sims_needed) * length(freqs_to_load);
    current_load = 0;

    for k = 1:length(sims_needed)
        % Check for cancel request (only read cancel flag, don't overwrite S)
        drawnow;  % Allow UI to process cancel button
        tmp = fig.UserData;
        if tmp.cancel_loading
            S.cancel_loading = true;
            lines_out = [lines_out; {'Loading cancelled by user'}];
            break;
        end

        i = sims_needed(k);
        st = S.all_sim_types{i};
        S.multi_freq_data.(st) = {};

        % Update progress label with current simulation
        S.lbl_progress.Text = sprintf('Loading %s...', upper(st));

        for fi = 1:length(freqs_to_load)
            % Check for cancel request (only read cancel flag, don't overwrite S)
            drawnow;  % Allow UI to process cancel button
            tmp = fig.UserData;
            if tmp.cancel_loading
                S.cancel_loading = true;
                break;  % Will be caught by outer loop check
            end

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
                    % Include drive direction info if available
                    drive_info = '';
                    if isfield(cached.params, 'drive_direction')
                        drive_info = sprintf(' [drive:%s]', cached.params.drive_direction);
                    end
                    lines_out = [lines_out; {sprintf('%s f=%.4f: %d fr (cached)%s', upper(st), freq, size(cached.xyz, 3), drive_info)}];
                end

                % Update progress bar
                current_load = current_load + 1;
                prog_pct = current_load / total_loads;
                S.pnl_prog_fill.Position = [8 260 round(204 * prog_pct) 8];
                S.lbl_progress.Text = sprintf('%s (cached) %d%%', upper(st), round(prog_pct*100));
                drawnow;

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
                current_load = current_load + 1;
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
                    % Include drive direction info if available
                    drive_info = '';
                    if isfield(sim_p, 'drive_direction')
                        drive_info = sprintf(' [drive:%s]', sim_p.drive_direction);
                    end
                    lines_out = [lines_out; {sprintf('%s f=%.4f: %d/%d fr%s', upper(st), freq, n_frames, n_total, drive_info)}];
                end

                % Update progress bar
                current_load = current_load + 1;
                prog_pct = current_load / total_loads;
                S.pnl_prog_fill.Position = [8 260 round(204 * prog_pct) 8];
                S.lbl_progress.Text = sprintf('%s f=%.4f %d%%', upper(st), freq, round(prog_pct*100));
                drawnow;

            catch ME
                S.multi_freq_data.(st){fi} = [];
                if fi == 1
                    S.data.(st) = [];
                end
                lines_out = [lines_out; {sprintf('%s f=%.4f: ERR - %s', upper(st), freq, ME.message)}];
                current_load = current_load + 1;
            end
        end  % end frequency loop

        % Check if cancelled during frequency loop
        if S.cancel_loading
            lines_out = [lines_out; {'Loading cancelled by user'}];
            break;
        end
    end  % end sim loop

    % Update status if cancelled
    if S.cancel_loading
        S.txt_status.Value = lines_out;
        S.btn_action.Text = 'Load';
        S.btn_action.BackgroundColor = [0.2 0.5 0.3];
        S.btn_cancel.Enable = 'off';
        S.data_loaded = false;
        % Clear progress bar
        S.lbl_progress.Text = 'Cancelled';
        S.pnl_prog_fill.Position = [8 260 0 8];
        fig.UserData = S;
        return;
    end

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
        ax.Toolbar.Visible = 'on';  % Enable zoom/pan toolbar
        axtoolbar(ax, {'pan', 'zoomin', 'zoomout', 'restoreview'});

        S.panels{end+1} = pan;
        S.axs{end+1} = ax;
    end

    S.max_frames = max(max_frames, 2);
    S.sl_frame.Limits = [1 S.max_frames];
    S.sl_frame.Value = 1;
    S.frame = 1;
    S.lbl_frame.Text = sprintf('Frame: 1 / %d', S.max_frames);
    S.txt_status.Value = lines_out;

    % Clear progress bar and mark complete
    S.lbl_progress.Text = 'Ready';
    S.pnl_prog_fill.Position = [8 260 204 8];  % Full bar = complete

    % Mark data as loaded - button becomes "Play"
    S.data_loaded = true;
    S.btn_action.Text = '▶ Play';
    S.btn_action.BackgroundColor = [0.3 0.5 0.3];
    S.btn_cancel.Enable = 'off';

    fig.UserData = S;
    render(fig);

    % Apply sync setting if enabled
    if S.cb_sync_graphs.Value
        cb_toggle_sync(fig);
    end
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
            case 'delaunay'
                draw_delaunay(ax, xyz, fr, W, H);
        end
    end
end

function draw_particles(ax, xyz, fr, W, H)
    cla(ax); hold(ax,'on');
    x = xyz(:,1,fr); y = xyz(:,2,fr); z = xyz(:,3,fr);
    zn = (z - min(z)) / (max(z)-min(z)+eps);
    % Cyan-to-red colormap for dark background visibility
    % cyan (0,1,1) -> white (1,1,1) -> red (1,0,0)
    colors = zeros(length(zn), 3);
    colors(:,1) = zn;                    % R: 0 -> 1
    colors(:,2) = 1 - abs(2*zn - 1);     % G: 0 -> 1 -> 0 (peaks at middle)
    colors(:,3) = 1 - zn;                % B: 1 -> 0
    scatter(ax, x, y, 15, colors, 'filled');  % Size 15 (was 6)
    xlim(ax,[0 W]); ylim(ax,[0 H]);
    % Use 'equal' aspect for correct particle spacing, but allow data rect to fill axes
    daspect(ax, [1 1 1]);  % Equal data aspect ratio
    set(ax,'Color','k'); hold(ax,'off');
end

function draw_delaunay(ax, xyz, fr, W, H)
    % Draw Delaunay triangulation colored by triangle area
    % Useful for visualizing local density/strain
    cla(ax); hold(ax,'on');

    x = xyz(:,1,fr);
    y = xyz(:,2,fr);

    % Compute Delaunay triangulation
    try
        DT = delaunayTriangulation(x, y);
        tri = DT.ConnectivityList;
    catch
        % Fallback if delaunayTriangulation fails
        text(ax, 0.5, 0.5, 'Triangulation failed', 'Color', 'w', ...
            'HorizontalAlignment', 'center', 'Units', 'normalized');
        set(ax,'Color','k'); hold(ax,'off');
        return;
    end

    % Compute area of each triangle
    n_tri = size(tri, 1);
    areas = zeros(n_tri, 1);
    for t = 1:n_tri
        i1 = tri(t,1); i2 = tri(t,2); i3 = tri(t,3);
        % Shoelace formula for triangle area
        areas(t) = 0.5 * abs((x(i2)-x(i1))*(y(i3)-y(i1)) - (x(i3)-x(i1))*(y(i2)-y(i1)));
    end

    % Normalize areas for coloring (use percentiles to handle outliers)
    area_min = prctile(areas, 2);
    area_max = prctile(areas, 98);
    area_norm = (areas - area_min) / (area_max - area_min + eps);
    area_norm = max(0, min(1, area_norm));  % Clamp to [0,1]

    % Create colormap (blue = small/compressed, red = large/expanded)
    cmap = jet(256);
    color_idx = round(area_norm * 255) + 1;
    tri_colors = cmap(color_idx, :);

    % Draw filled triangles
    patch(ax, 'Faces', tri, 'Vertices', [x, y], ...
        'FaceVertexCData', tri_colors, 'FaceColor', 'flat', ...
        'EdgeColor', [0.3 0.3 0.3], 'EdgeAlpha', 0.3, 'LineWidth', 0.5);

    % Add colorbar
    colormap(ax, jet);
    cb = colorbar(ax, 'Color', 'w');
    cb.Label.String = 'Triangle Area (px²)';
    cb.Label.Color = 'w';
    % Set colorbar ticks to show actual area values
    clim(ax, [area_min, area_max]);

    xlim(ax,[0 W]); ylim(ax,[0 H]);
    daspect(ax, [1 1 1]);
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

        % Update global max using 99th percentile (avoids outliers dominating scale)
        pct99 = prctile(abs(all_dpos(:)), 99);
        global_ymax = max(global_ymax, pct99 * 1.2);

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

    % Compute y-max for this axis using 99th percentile
    if use_y_axis
        all_dpos = squeeze(xyz(:,2,:)) - pos0;
    else
        all_dpos = squeeze(xyz(:,1,:)) - pos0;
    end
    pct99 = prctile(abs(all_dpos(:)), 99);
    global_ymax = max(0.5, pct99 * 1.2);

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
    % Use 99th percentile for color scale (avoids outliers washing out detail)
    pct99 = prctile(abs(kymo(:)), 99);
    cmax = max(0.5, pct99 * 1.2);
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
    % Use 99th percentile for color scale
    pct99 = prctile(abs(kymo(:)), 99);
    cmax = max(0.5, pct99 * 1.2);
    clim(ax, [-cmax, cmax]);
    if is_topdriven
        ylabel_str = 'Y position (px)';
    else
        ylabel_str = 'X position (px)';
    end
    xlabel(ax,'Frame'); ylabel(ax, ylabel_str);
    set(ax,'YDir','normal');
end

%% ==================== VIDEO EXPORT ====================

function cb_open_video_dialog(fig)
    % Open dialog to configure video export
    S = fig.UserData;

    if ~S.data_loaded
        S.txt_status.Value = {'Load data first before exporting video'};
        fig.UserData = S;
        return;
    end

    % Create dialog figure
    dlg = uifigure('Name', 'Export Video', 'Position', [300 200 400 450], ...
        'Color', [0.2 0.2 0.2], 'Resize', 'off');

    % Title
    uilabel(dlg, 'Text', 'Video Export Options', ...
        'Position', [10 410 380 30], 'FontColor', 'w', 'FontSize', 16, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center');

    % Export mode
    uilabel(dlg, 'Text', 'Export Mode:', 'Position', [20 370 100 20], ...
        'FontColor', 'w', 'FontWeight', 'bold');
    bg_mode = uibuttongroup(dlg, 'Position', [20 310 360 60], ...
        'BackgroundColor', [0.25 0.25 0.25], 'BorderType', 'none');
    rb_combined = uiradiobutton(bg_mode, 'Text', 'All panels combined (current layout)', ...
        'Position', [10 30 340 22], 'FontColor', 'w', 'Value', true);
    rb_individual = uiradiobutton(bg_mode, 'Text', 'Individual panels (one file per panel)', ...
        'Position', [10 5 340 22], 'FontColor', 'w');

    % Panel selection (for individual mode)
    uilabel(dlg, 'Text', 'Panels to export (for individual mode):', ...
        'Position', [20 275 300 20], 'FontColor', 'w', 'FontWeight', 'bold');
    pnl_sel = uipanel(dlg, 'Position', [20 155 360 115], ...
        'BackgroundColor', [0.15 0.15 0.15], 'BorderType', 'none');

    % Create checkboxes for each currently loaded view
    panel_cbs = {};
    n_views = length(S.view_configs);
    for i = 1:min(n_views, 8)  % Max 8 panels
        vc = S.view_configs{i};
        label = sprintf('%s (%s)', upper(vc.sim_type), ternary(vc.use_y, 'Y', 'X'));
        row = ceil(i/2);
        col = mod(i-1, 2);
        panel_cbs{i} = uicheckbox(pnl_sel, 'Text', label, 'Value', true, ...
            'Position', [10 + col*175, 90 - (row-1)*22, 170, 20], 'FontColor', 'w');
    end

    % View mode
    uilabel(dlg, 'Text', 'View Mode:', 'Position', [20 120 100 20], ...
        'FontColor', 'w', 'FontWeight', 'bold');
    dd_view = uidropdown(dlg, 'Items', {'Current view', 'Particles', 'Wavefront', 'Kymograph', 'Delaunay'}, ...
        'Value', 'Current view', 'Position', [130 118 150 24]);

    % Output folder
    uilabel(dlg, 'Text', 'Output Folder:', 'Position', [20 85 100 20], ...
        'FontColor', 'w', 'FontWeight', 'bold');
    ef_folder = uieditfield(dlg, 'Value', pwd, 'Position', [20 58 300 24]);
    btn_browse = uibutton(dlg, 'Text', '...', 'Position', [325 58 55 24], ...
        'BackgroundColor', [0.3 0.3 0.4]);

    % File prefix
    uilabel(dlg, 'Text', 'File Prefix:', 'Position', [20 30 80 20], 'FontColor', 'w');
    ef_prefix = uieditfield(dlg, 'Value', 'simulation', 'Position', [100 28 180 24]);

    % Export and Cancel buttons
    btn_export = uibutton(dlg, 'Text', 'Export', 'Position', [200 8 90 28], ...
        'BackgroundColor', [0.3 0.5 0.3], 'FontWeight', 'bold');
    btn_cancel_dlg = uibutton(dlg, 'Text', 'Cancel', 'Position', [300 8 80 28], ...
        'BackgroundColor', [0.5 0.3 0.3]);

    % Store handles in dialog UserData
    dlg.UserData = struct('main_fig', fig, 'rb_combined', rb_combined, ...
        'rb_individual', rb_individual, 'panel_cbs', {panel_cbs}, ...
        'dd_view', dd_view, 'ef_folder', ef_folder, 'ef_prefix', ef_prefix);

    % Wire callbacks
    btn_browse.ButtonPushedFcn = @(~,~) video_browse_folder(dlg);
    btn_export.ButtonPushedFcn = @(~,~) video_start_export(dlg);
    btn_cancel_dlg.ButtonPushedFcn = @(~,~) close(dlg);
end

function result = ternary(cond, true_val, false_val)
    if cond
        result = true_val;
    else
        result = false_val;
    end
end

function video_browse_folder(dlg)
    folder = uigetdir(dlg.UserData.ef_folder.Value, 'Select Output Folder');
    if folder ~= 0
        dlg.UserData.ef_folder.Value = folder;
    end
end

function video_start_export(dlg)
    d = dlg.UserData;
    fig = d.main_fig;
    S = fig.UserData;

    % Get settings
    is_combined = d.rb_combined.Value;
    view_mode = d.dd_view.Value;
    output_folder = d.ef_folder.Value;
    file_prefix = d.ef_prefix.Value;

    % Determine view mode
    if strcmp(view_mode, 'Current view')
        export_view = S.view_mode;
    else
        export_view = lower(view_mode);
    end

    % Validate output folder
    if ~exist(output_folder, 'dir')
        try
            mkdir(output_folder);
        catch
            uialert(dlg, 'Cannot create output folder', 'Error');
            return;
        end
    end

    close(dlg);

    % Update status
    S.txt_status.Value = {'Starting video export...'};
    fig.UserData = S;
    drawnow;

    if is_combined
        % Export all panels combined
        export_combined_video(fig, export_view, output_folder, file_prefix);
    else
        % Export individual panels
        selected_panels = [];
        for i = 1:length(d.panel_cbs)
            if d.panel_cbs{i}.Value
                selected_panels(end+1) = i;
            end
        end
        if isempty(selected_panels)
            S.txt_status.Value = {'No panels selected for export'};
            fig.UserData = S;
            return;
        end
        export_individual_videos(fig, export_view, output_folder, file_prefix, selected_panels);
    end
end

function export_combined_video(fig, view_mode, output_folder, file_prefix)
    % Export all panels as single video with current layout
    S = fig.UserData;
    n_frames = S.max_frames;

    % Create output filename
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename = fullfile(output_folder, sprintf('%s_combined_%s_%s.mp4', file_prefix, view_mode, timestamp));

    % Create VideoWriter
    try
        vw = VideoWriter(filename, 'MPEG-4');
        vw.FrameRate = 30;
        vw.Quality = 95;
        open(vw);
    catch ME
        S.txt_status.Value = {sprintf('Failed to create video: %s', ME.message)};
        fig.UserData = S;
        return;
    end

    % Store original view mode and frame
    orig_view = S.view_mode;
    orig_frame = S.frame;

    % Set export view mode
    S.view_mode = view_mode;
    fig.UserData = S;

    % Create a figure for high-res rendering
    export_fig = figure('Position', [100 100 1920 1080], 'Color', 'k', 'Visible', 'off');

    try
        % Get grid size
        n_panels = length(S.axs);
        [rows, cols] = get_grid_size(n_panels);

        % Export each frame
        for fr = 1:n_frames
            S.frame = fr;
            fig.UserData = S;

            % Clear export figure
            clf(export_fig);

            % Render each panel to export figure
            for idx = 1:n_panels
                if idx > length(S.view_configs); continue; end
                vc = S.view_configs{idx};
                st = vc.sim_type;
                use_y = vc.use_y;

                if ~isfield(S.data, st) || isempty(S.data.(st)); continue; end

                xyz = S.data.(st);
                n_fr = size(xyz, 3);
                frame = min(fr, n_fr);
                p = S.params.(st);
                W = p.width; H = p.height;
                axis_len = ternary(use_y, H, W);

                % Create subplot
                ax = subplot(rows, cols, idx, 'Parent', export_fig);
                set(ax, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
                title(ax, sprintf('%s (%s)', upper(st), ternary(use_y, 'Y', 'X')), 'Color', 'w');

                % Draw based on view mode
                switch view_mode
                    case 'particles'
                        draw_particles(ax, xyz, frame, W, H);
                    case 'wavefront'
                        if isfield(S, 'multi_freq_data') && isfield(S.multi_freq_data, st)
                            multi_data = S.multi_freq_data.(st);
                        else
                            multi_data = {xyz};
                        end
                        draw_wavefront_multifreq(ax, multi_data, S.manual_freqs, frame, axis_len, use_y);
                    case 'kymograph'
                        draw_kymograph_dynamic(ax, xyz, axis_len, use_y);
                    case 'delaunay'
                        draw_delaunay(ax, xyz, frame, W, H);
                end
            end

            % Capture frame
            frame_img = getframe(export_fig);
            writeVideo(vw, frame_img.cdata);

            % Update progress
            if mod(fr, 50) == 0 || fr == n_frames
                S.txt_status.Value = {sprintf('Exporting combined: %d/%d frames', fr, n_frames)};
                drawnow;
            end
        end

        close(vw);
        close(export_fig);

        % Restore original state
        S.view_mode = orig_view;
        S.frame = orig_frame;
        S.txt_status.Value = {sprintf('Video saved: %s', filename)};
        fig.UserData = S;
        render(fig);

    catch ME
        close(vw);
        close(export_fig);
        S.view_mode = orig_view;
        S.frame = orig_frame;
        S.txt_status.Value = {sprintf('Export failed: %s', ME.message)};
        fig.UserData = S;
        render(fig);
    end
end

function export_individual_videos(fig, view_mode, output_folder, file_prefix, selected_panels)
    % Export selected panels as individual videos
    S = fig.UserData;
    n_frames = S.max_frames;

    % Store original state
    orig_view = S.view_mode;
    orig_frame = S.frame;
    S.view_mode = view_mode;
    fig.UserData = S;

    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    total_exported = 0;

    for panel_idx = selected_panels
        if panel_idx > length(S.view_configs); continue; end
        vc = S.view_configs{panel_idx};
        st = vc.sim_type;
        use_y = vc.use_y;

        if ~isfield(S.data, st) || isempty(S.data.(st)); continue; end

        xyz = S.data.(st);
        p = S.params.(st);
        W = p.width; H = p.height;
        axis_len = ternary(use_y, H, W);

        % Create filename
        axis_label = ternary(use_y, 'Y', 'X');
        filename = fullfile(output_folder, sprintf('%s_%s_%s_%s_%s.mp4', ...
            file_prefix, upper(st), axis_label, view_mode, timestamp));

        % Create VideoWriter
        try
            vw = VideoWriter(filename, 'MPEG-4');
            vw.FrameRate = 30;
            vw.Quality = 95;
            open(vw);
        catch ME
            S.txt_status.Value = {sprintf('Failed to create video for %s: %s', st, ME.message)};
            continue;
        end

        % Create figure for rendering (1080p)
        export_fig = figure('Position', [100 100 1920 1080], 'Color', 'k', 'Visible', 'off');
        ax = axes(export_fig, 'Color', 'k', 'XColor', 'w', 'YColor', 'w');

        try
            n_fr = size(xyz, 3);

            for fr = 1:n_frames
                frame = min(fr, n_fr);
                cla(ax);

                % Draw based on view mode
                switch view_mode
                    case 'particles'
                        draw_particles(ax, xyz, frame, W, H);
                    case 'wavefront'
                        if isfield(S, 'multi_freq_data') && isfield(S.multi_freq_data, st)
                            multi_data = S.multi_freq_data.(st);
                        else
                            multi_data = {xyz};
                        end
                        draw_wavefront_multifreq(ax, multi_data, S.manual_freqs, frame, axis_len, use_y);
                    case 'kymograph'
                        draw_kymograph_dynamic(ax, xyz, axis_len, use_y);
                    case 'delaunay'
                        draw_delaunay(ax, xyz, frame, W, H);
                end

                title(ax, sprintf('%s (%s) - Frame %d', upper(st), axis_label, frame), 'Color', 'w', 'FontSize', 14);

                % Capture and write frame
                frame_img = getframe(export_fig);
                writeVideo(vw, frame_img.cdata);

                % Update progress periodically
                if mod(fr, 100) == 0
                    S.txt_status.Value = {sprintf('Exporting %s_%s: %d/%d', upper(st), axis_label, fr, n_frames)};
                    drawnow;
                end
            end

            close(vw);
            close(export_fig);
            total_exported = total_exported + 1;

        catch ME
            close(vw);
            close(export_fig);
            S.txt_status.Value = {sprintf('Export failed for %s: %s', st, ME.message)};
        end
    end

    % Restore original state
    S.view_mode = orig_view;
    S.frame = orig_frame;
    S.txt_status.Value = {sprintf('Exported %d videos to: %s', total_exported, output_folder)};
    fig.UserData = S;
    render(fig);
end
