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
% FIX NOTE: Uses fig.UserData instead of guidata - required for timer
% callbacks to reliably access and update state in uifigure.
%
% Author: Gerbode Lab
% Date: 2026

%% ==================== CONFIGURATION ====================
base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';

sim_types   = {'zigzag', 'stripe', 'random', 'topdriven'};
sim_folders = {'drivensinesims', 'stripesinesims', 'randomsinesims', 'topdrivensims'};

all_frequencies = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...
                   0.001,  0.0012, 0.0015, 0.0018, ...
                   0.002,  0.0025, 0.003,  0.004,  0.005, ...
                   0.007,  0.01,   0.02,   0.05,   0.10];

%% ==================== BUILD UI ====================
fig = uifigure('Name', 'Simulation Viewer', 'Position', [50 50 1440 920]);
fig.Color = [0.15 0.15 0.15];

% ---- control panel ----
cp = uipanel(fig, 'Title', 'Controls', ...
    'Position', [8 8 205 904], ...
    'BackgroundColor', [0.2 0.2 0.2], 'ForegroundColor', 'w');

% frequency slider
uilabel(cp, 'Text', 'Frequency:', 'Position', [8 855 185 18], 'FontColor', 'w');
sl_freq = uislider(cp, 'Position', [8 820 185 3], ...
    'Limits', [1 length(all_frequencies)], 'Value', 1, ...
    'MajorTicks', [], 'MinorTicks', []);
lbl_freq = uilabel(cp, 'Text', sprintf('f = %.4f', all_frequencies(1)), ...
    'Position', [8 790 185 24], 'FontColor', 'cyan', 'FontSize', 13, ...
    'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% view mode
uilabel(cp, 'Text', 'View Mode:', 'Position', [8 750 185 18], 'FontColor', 'w');
btn_part = uibutton(cp, 'Text', 'Particles',  'Position', [8  722 62 24], 'BackgroundColor', [0.3 0.6 0.3]);
btn_wave = uibutton(cp, 'Text', 'Wavefront',  'Position', [74 722 62 24], 'BackgroundColor', [0.4 0.4 0.4]);
btn_kymo = uibutton(cp, 'Text', 'Kymograph',  'Position', [140 722 62 24], 'BackgroundColor', [0.4 0.4 0.4]);

% playback
uilabel(cp, 'Text', 'Playback:', 'Position', [8 685 185 18], 'FontColor', 'w');
btn_play  = uibutton(cp, 'Text', '▶ Play',  'Position', [8  658 95 24], 'BackgroundColor', [0.3 0.5 0.3]);
btn_step  = uibutton(cp, 'Text', 'Step ▶',  'Position', [107 658 95 24], 'BackgroundColor', [0.4 0.4 0.4]);
btn_reset = uibutton(cp, 'Text', '⟲ Reset', 'Position', [8  630 95 24], 'BackgroundColor', [0.4 0.4 0.4]);

uilabel(cp, 'Text', 'Frame:', 'Position', [8 595 185 18], 'FontColor', 'w');
sl_frame  = uislider(cp, 'Position', [8 565 185 3], 'Limits', [1 100], 'Value', 1, ...
    'MajorTicks', [], 'MinorTicks', []);
lbl_frame = uilabel(cp, 'Text', 'Frame: 1 / 100', 'Position', [8 535 185 24], ...
    'FontColor', 'w', 'HorizontalAlignment', 'center');

uilabel(cp, 'Text', 'Speed:', 'Position', [8 500 60 18], 'FontColor', 'w');
dd_speed = uidropdown(cp, 'Items', {'0.25x','0.5x','1x','2x','4x'}, 'Value', '1x', ...
    'Position', [70 498 80 24]);

uilabel(cp, 'Text', 'Loaded:', 'Position', [8 460 185 18], 'FontColor', 'w');
txt_status = uitextarea(cp, 'Position', [8 330 185 128], 'Editable', 'off', ...
    'BackgroundColor', [0.1 0.1 0.1], 'FontColor', [0.7 0.7 0.7], 'FontSize', 9);

btn_load = uibutton(cp, 'Text', 'Load Data', 'Position', [8 295 185 30], ...
    'BackgroundColor', [0.2 0.4 0.6]);

% ---- plot panels ----
pw = 575; ph = 430;
xs = [222, 222+pw+8]; ys = [476, 36];
axs = cell(4,1);
for i = 1:4
    r = ceil(i/2); c = mod(i-1,2)+1;
    pan = uipanel(fig, 'Title', upper(sim_types{i}), ...
        'Position', [xs(c) ys(r) pw ph], ...
        'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', 'w', 'FontWeight', 'bold');
    axs{i} = uiaxes(pan, 'Position', [8 8 pw-18 ph-38], ...
        'Color', 'k', 'XColor', 'w', 'YColor', 'w');
    axs{i}.Toolbar.Visible = 'off';
end

%% ==================== STATE (stored in fig.UserData) ====================
S.base_path      = base_path;
S.sim_types      = sim_types;
S.sim_folders    = sim_folders;
S.frequencies    = all_frequencies;
S.freq_idx       = 1;
S.frame          = 1;
S.max_frames     = 100;
S.view_mode      = 'particles';
S.is_playing     = false;
S.play_speed     = 1;
S.data           = struct();   % loaded xyz arrays keyed by sim_type
S.params         = struct();   % loaded sim_params
% UI handles stored so callbacks can access them
S.sl_freq   = sl_freq;
S.sl_frame  = sl_frame;
S.lbl_freq  = lbl_freq;
S.lbl_frame = lbl_frame;
S.btn_play  = btn_play;
S.btn_part  = btn_part;
S.btn_wave  = btn_wave;
S.btn_kymo  = btn_kymo;
S.txt_status = txt_status;
S.axs        = axs;
fig.UserData = S;

%% ==================== WIRE CALLBACKS ====================
sl_freq.ValueChangedFcn   = @(~,~) cb_freq(fig);
sl_frame.ValueChangedFcn  = @(~,~) cb_frame(fig);
btn_play.ButtonPushedFcn  = @(~,~) cb_play(fig);
btn_step.ButtonPushedFcn  = @(~,~) cb_step(fig);
btn_reset.ButtonPushedFcn = @(~,~) cb_reset(fig);
btn_load.ButtonPushedFcn  = @(~,~) cb_load(fig);
btn_part.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'particles');
btn_wave.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'wavefront');
btn_kymo.ButtonPushedFcn  = @(~,~) cb_mode(fig, 'kymograph');
dd_speed.ValueChangedFcn  = @(src,~) cb_speed(fig, src.Value);

fig.CloseRequestFcn = @(~,~) cb_close(fig);

% initial load
cb_load(fig);
end

%% ==================== CALLBACKS ====================

function cb_freq(fig)
    S = fig.UserData;
    S.freq_idx = round(S.sl_freq.Value);
    S.lbl_freq.Text = sprintf('f = %.4f', S.frequencies(S.freq_idx));
    fig.UserData = S;
    cb_load(fig);
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
        % --- STOP ---
        S.is_playing = false;
        S.btn_play.Text = '▶ Play';
        S.btn_play.BackgroundColor = [0.3 0.5 0.3];
        fig.UserData = S;
        % timer cleans itself up via TimerFcn check
    else
        % --- START ---
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
    % Runs in timer thread - use fig.UserData, never guidata
    if ~isvalid(fig)
        stop(tmr); delete(tmr); return;
    end
    S = fig.UserData;
    if ~S.is_playing
        stop(tmr); delete(tmr); return;
    end
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
    % stop if running so the old timer dies cleanly
    if was_playing
        S.is_playing = false;
        S.btn_play.Text = '▶ Play';
        S.btn_play.BackgroundColor = [0.3 0.5 0.3];
        fig.UserData = S;
        pause(0.15);   % let timer_tick notice is_playing=false
    end
    switch speed_str
        case '0.25x'; S.play_speed = 0.25;
        case '0.5x';  S.play_speed = 0.5;
        case '1x';    S.play_speed = 1;
        case '2x';    S.play_speed = 2;
        case '4x';    S.play_speed = 4;
    end
    fig.UserData = S;
    if was_playing
        cb_play(fig);   % restart with new speed
    end
end

function cb_close(fig)
    S = fig.UserData;
    S.is_playing = false;
    fig.UserData = S;
    pause(0.15);
    delete(fig);
end

function cb_load(fig)
    S = fig.UserData;
    freq = S.frequencies(S.freq_idx);
    lines_out = {};
    max_frames = 1;

    name_fmt = {'sinusoidal_f%.4f_a2.0', ...
                'sinusoidal_f%.4f_a2.0_stripes', ...
                'sinusoidal_f%.4f_a2.0_random', ...
                'topdriven_f%.4f_a2.0'};

    for i = 1:length(S.sim_types)
        st = S.sim_types{i};
        sim_name = sprintf(name_fmt{i}, freq);
        plist_path = fullfile(S.base_path, S.sim_folders{i}, 'simulations', sim_name, 'plist.mat');
        par_path   = fullfile(S.base_path, S.sim_folders{i}, 'simulations', sim_name, 'sim_params.mat');

        if ~exist(plist_path, 'file')
            S.data.(st)   = [];
            S.params.(st) = [];
            lines_out{end+1} = sprintf('%s: not found', upper(st));
            continue;
        end

        try
            ld = load(plist_path);
            plist = ld.plist;
            frame_ids   = unique(plist(:,4));
            n_frames    = length(frame_ids);
            n_particles = sum(plist(:,4) == frame_ids(1));

            xyz = zeros(n_particles, 3, n_frames);
            for ff = 1:n_frames
                m = plist(:,4) == frame_ids(ff);
                xyz(:,:,ff) = plist(m, 1:3);
            end
            S.data.(st) = xyz;

            if exist(par_path, 'file')
                pd = load(par_path);
                S.params.(st) = pd.sim_params;
            else
                S.params.(st) = struct('width',800,'height',400, ...
                    'drive_frequency',freq,'drive_amplitude',2.0, ...
                    'data_saving_frequency',2);
            end

            max_frames = max(max_frames, n_frames);
            lines_out{end+1} = sprintf('%s: %d fr', upper(st), n_frames);
        catch ME
            S.data.(st) = [];
            lines_out{end+1} = sprintf('%s: ERR', upper(st));
        end
    end

    S.max_frames        = max(max_frames, 2);
    S.sl_frame.Limits   = [1 S.max_frames];
    S.sl_frame.Value    = 1;
    S.frame             = 1;
    S.lbl_frame.Text    = sprintf('Frame: 1 / %d', S.max_frames);
    S.txt_status.Value  = lines_out;
    fig.UserData = S;
    render(fig);
end

%% ==================== RENDERING ====================

function render(fig)
    S = fig.UserData;
    for i = 1:length(S.sim_types)
        st  = S.sim_types{i};
        ax  = S.axs{i};

        if ~isfield(S.data, st) || isempty(S.data.(st))
            cla(ax);
            text(ax, 0.5, 0.5, 'No data', 'Color', 'w', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, 'Units', 'normalized');
            continue;
        end

        xyz   = S.data.(st);
        n_fr  = size(xyz,3);
        fr    = min(S.frame, n_fr);
        p     = S.params.(st);
        W     = p.width; H = p.height;

        switch S.view_mode
            case 'particles',  draw_particles(ax, xyz, fr, W, H);
            case 'wavefront',  draw_wavefront(ax, xyz, fr, W, H);
            case 'kymograph',  draw_kymograph(ax, xyz, W, H);
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

function draw_wavefront(ax, xyz, fr, W, H)
    cla(ax); hold(ax,'on');
    x  = xyz(:,1,fr);
    x0 = mean(xyz(:,1,1:min(10,size(xyz,3))),3);
    dx = x - x0;

    n_bins = 60;
    edges  = linspace(0, W, n_bins+1);
    ctrs   = (edges(1:end-1)+edges(2:end))/2;
    avg_dx = zeros(n_bins,1);
    for b = 1:n_bins
        in = x0 >= edges(b) & x0 < edges(b+1);
        if any(in); avg_dx(b) = mean(dx(in)); end
    end

    plot(ax, ctrs, avg_dx, 'c-', 'LineWidth', 2);
    yline(ax, 0, '--', 'Color', [0.5 0.5 0.5]);
    xlim(ax,[0 W]); ylim(ax,[-3 3]);
    xlabel(ax,'X position (px)'); ylabel(ax,'Displacement (px)');
    set(ax,'Color','k'); hold(ax,'off');
end

function draw_kymograph(ax, xyz, W, H)
    cla(ax);
    n_fr   = size(xyz,3);
    x0     = mean(xyz(:,1,1:min(10,n_fr)),3);
    n_bins = 80;
    edges  = linspace(0, W, n_bins+1);
    kymo   = zeros(n_bins, n_fr);
    for ff = 1:n_fr
        dx = xyz(:,1,ff) - x0;
        for b = 1:n_bins
            in = x0 >= edges(b) & x0 < edges(b+1);
            if any(in); kymo(b,ff) = mean(dx(in)); end
        end
    end
    imagesc(ax, 1:n_fr, (edges(1:end-1)+edges(2:end))/2, kymo);
    colormap(ax,'jet'); clim(ax,[-2 2]);
    xlabel(ax,'Frame'); ylabel(ax,'X position (px)');
    set(ax,'YDir','normal');
end
