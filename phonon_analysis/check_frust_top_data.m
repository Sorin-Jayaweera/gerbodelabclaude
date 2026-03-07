%% check_frust_top_data.m
% Quick diagnostic to check frust_top simulation data
% Run this to verify the Y-driven simulation has valid Y displacements

base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\sims';
freq = 0.0005;

plist_path = fullfile(base_path, 'frusttopsims', 'simulations', ...
    sprintf('frusttop_f%.4f_a2.0', freq), 'plist.mat');

fprintf('Loading: %s\n', plist_path);

if ~exist(plist_path, 'file')
    error('File not found!');
end

loaded = load(plist_path);
plist = loaded.plist;

fprintf('plist size: %s\n', mat2str(size(plist)));
fprintf('plist class: %s\n', class(plist));

% For matrix format [x, y, z, frame]
if isnumeric(plist) && size(plist, 2) >= 4
    frame_col = plist(:, 4);
    all_frames = unique(frame_col);
    n_frames = length(all_frames);
    n_particles = sum(frame_col == all_frames(1));

    fprintf('Frames: %d, Particles: %d\n', n_frames, n_particles);

    % Get frame 1 and frame 500
    frame1_data = plist(frame_col == all_frames(1), :);
    frame500_idx = min(500, n_frames);
    frame500_data = plist(frame_col == all_frames(frame500_idx), :);

    % Check Y range
    y1 = frame1_data(:, 2);
    y500 = frame500_data(:, 2);

    fprintf('\nFrame 1 Y: min=%.2f, max=%.2f, range=%.2f\n', min(y1), max(y1), max(y1)-min(y1));
    fprintf('Frame %d Y: min=%.2f, max=%.2f, range=%.2f\n', frame500_idx, min(y500), max(y500), max(y500)-min(y500));

    % Check displacement of top particles (should be driven)
    top_mask = y1 > 375;  % Particles near top (drive region)
    fprintf('\nTop particles (Y > 375): %d particles\n', sum(top_mask));

    y1_top = y1(top_mask);
    y500_top = y500(top_mask);
    dy_top = y500_top - y1_top;

    fprintf('Top particles Y displacement (frame %d - frame 1):\n', frame500_idx);
    fprintf('  min=%.4f, max=%.4f, mean=%.4f, std=%.4f\n', ...
        min(dy_top), max(dy_top), mean(dy_top), std(dy_top));

    % Check if X is varying instead (wrong column?)
    x1 = frame1_data(:, 1);
    x500 = frame500_data(:, 1);
    dx_top = x500(top_mask) - x1(top_mask);

    fprintf('\nTop particles X displacement (for comparison):\n');
    fprintf('  min=%.4f, max=%.4f, mean=%.4f, std=%.4f\n', ...
        min(dx_top), max(dx_top), mean(dx_top), std(dx_top));

    % Sample multiple frames to see Y oscillation
    fprintf('\nSampling Y displacement over time for top particles:\n');
    sample_frames = round(linspace(1, min(1000, n_frames), 10));
    for sf = sample_frames
        frame_data = plist(frame_col == all_frames(sf), :);
        y_sf = frame_data(:, 2);
        y_sf_top = y_sf(top_mask);
        dy = mean(y_sf_top - y1_top);
        fprintf('  Frame %4d: mean Y disp = %+.4f\n', sf, dy);
    end
else
    fprintf('Unexpected plist format!\n');
end

fprintf('\nDone.\n');
