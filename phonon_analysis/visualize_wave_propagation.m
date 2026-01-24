function visualize_wave_propagation(xyz, x0, y0, frames_to_plot, output_name)
%% VISUALIZE_WAVE_PROPAGATION Create visualizations of wave propagation
%
% Creates animated visualizations showing how the impulse propagates
% through the crystal lattice.
%
% INPUTS:
%   xyz            - Position data [N_particles, 3, N_frames]
%   x0, y0         - Equilibrium positions [N_particles, 1]
%   frames_to_plot - Indices of frames to visualize (or 'all' for animation)
%   output_name    - Base name for output files
%
% Author: Gerbode Lab

if nargin < 4 || isempty(frames_to_plot)
    frames_to_plot = 1:10:size(xyz, 3);  % Every 10th frame by default
end

if nargin < 5
    output_name = 'wave_propagation';
end

[N_particles, ~, N_frames] = size(xyz);

% Extract x and y positions
x = squeeze(xyz(:, 1, :));
y = squeeze(xyz(:, 2, :));

% Compute displacements
ux = x - x0;
uy = y - y0;

% Compute displacement magnitudes
u_mag = sqrt(ux.^2 + uy.^2);

%% Static snapshots figure
if length(frames_to_plot) <= 12
    n_rows = ceil(length(frames_to_plot) / 4);
    n_cols = min(4, length(frames_to_plot));

    figure('Position', [50, 50, 300*n_cols, 250*n_rows]);

    for i = 1:length(frames_to_plot)
        frame = frames_to_plot(i);
        if frame > N_frames
            continue;
        end

        subplot(n_rows, n_cols, i);

        % Color by displacement magnitude
        scatter(x0, y0, 15, u_mag(:, frame), 'filled');
        colormap(hot);
        caxis([0, max(u_mag(:))]);
        axis equal;
        xlim([min(x0)-10, max(x0)+10]);
        ylim([min(y0)-10, max(y0)+10]);
        title(sprintf('Frame %d', frame));
        colorbar;
    end

    sgtitle('Wave Propagation - Displacement Magnitude');
    saveas(gcf, [output_name '_snapshots.png']);
end

%% Displacement kymograph (space-time plot)
% Average displacement as function of x-position and time

n_bins = 50;
x_bins = linspace(min(x0), max(x0), n_bins);
kymograph = zeros(n_bins-1, N_frames);

for t = 1:N_frames
    for b = 1:n_bins-1
        in_bin = x0 >= x_bins(b) & x0 < x_bins(b+1);
        if any(in_bin)
            kymograph(b, t) = mean(ux(in_bin, t));
        end
    end
end

figure('Position', [100, 100, 1000, 400]);

subplot(1, 2, 1);
imagesc(1:N_frames, (x_bins(1:end-1) + x_bins(2:end))/2, kymograph);
xlabel('Frame');
ylabel('X position');
title('Kymograph: X-displacement vs Position and Time');
colorbar;
axis xy;

% Also create for y-displacement
kymograph_y = zeros(n_bins-1, N_frames);
for t = 1:N_frames
    for b = 1:n_bins-1
        in_bin = x0 >= x_bins(b) & x0 < x_bins(b+1);
        if any(in_bin)
            kymograph_y(b, t) = mean(uy(in_bin, t));
        end
    end
end

subplot(1, 2, 2);
imagesc(1:N_frames, (x_bins(1:end-1) + x_bins(2:end))/2, kymograph_y);
xlabel('Frame');
ylabel('X position');
title('Kymograph: Y-displacement vs Position and Time');
colorbar;
axis xy;

saveas(gcf, [output_name '_kymograph.png']);
saveas(gcf, [output_name '_kymograph.fig']);

%% Wave speed estimation from kymograph
% Find the leading edge of the wave at each time

figure('Position', [100, 100, 1000, 400]);

% Threshold for wave detection
threshold = max(abs(kymograph(:))) * 0.1;

wave_front = zeros(N_frames, 1);
for t = 1:N_frames
    col = abs(kymograph(:, t));
    front_idx = find(col > threshold, 1, 'last');
    if ~isempty(front_idx)
        wave_front(t) = x_bins(front_idx);
    end
end

subplot(1, 2, 1);
plot(1:N_frames, wave_front, 'b-', 'LineWidth', 1.5);
xlabel('Frame');
ylabel('Wave Front X Position');
title('Wave Front Position vs Time');
grid on;

% Estimate wave speed from slope
valid_frames = wave_front > min(x0) + 10;
if sum(valid_frames) > 10
    t_valid = find(valid_frames);
    p = polyfit(t_valid, wave_front(valid_frames), 1);
    wave_speed = p(1);

    hold on;
    plot(t_valid, polyval(p, t_valid), 'r--', 'LineWidth', 2);
    legend('Wave front', sprintf('Fit: speed = %.3f px/frame', wave_speed));
end

subplot(1, 2, 2);
% Displacement vs distance at fixed times
times_to_plot = round(linspace(10, N_frames, 5));
colors = parula(length(times_to_plot));
hold on;
for i = 1:length(times_to_plot)
    t = times_to_plot(i);
    plot((x_bins(1:end-1) + x_bins(2:end))/2, kymograph(:, t), ...
        'Color', colors(i,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('Frame %d', t));
end
xlabel('X Position');
ylabel('X Displacement');
title('Wave Profile at Different Times');
legend('Location', 'best');
grid on;

saveas(gcf, [output_name '_wave_analysis.png']);

%% 2D-FFT of kymograph for dispersion relation
figure('Position', [100, 100, 800, 600]);

% Pad and apply window
[n_x, n_t] = size(kymograph);
window_x = hann_window(n_x);
window_t = hann_window(n_t)';
kymograph_windowed = kymograph .* (window_x * window_t);

% 2D FFT
K = fft2(kymograph_windowed, 2^nextpow2(2*n_x), 2^nextpow2(2*n_t));
K = fftshift(K);
K_power = abs(K).^2;

% Create frequency/wavenumber axes
[n_kx, n_kt] = size(K);
dx = (max(x0) - min(x0)) / n_bins;
kx = linspace(-pi/dx, pi/dx, n_kx);
omega = linspace(-pi, pi, n_kt);  % Normalized frequency

imagesc(omega, kx, log10(K_power + 1));
xlabel('\omega (normalized)');
ylabel('k_x (1/pixels)');
title('2D FFT of Kymograph (Dispersion Relation)');
colorbar;
axis xy;

saveas(gcf, [output_name '_dispersion_2dfft.png']);
saveas(gcf, [output_name '_dispersion_2dfft.fig']);

%% Create animation (if requested)
if ischar(frames_to_plot) && strcmp(frames_to_plot, 'all')
    frames_to_plot = 1:N_frames;
end

if length(frames_to_plot) > 20
    fprintf('Creating animation (%d frames)...\n', length(frames_to_plot));

    fig = figure('Position', [100, 100, 800, 600]);

    % Set up video writer
    v = VideoWriter([output_name '_animation.avi']);
    v.FrameRate = 20;
    open(v);

    for i = 1:length(frames_to_plot)
        frame = frames_to_plot(i);
        if frame > N_frames
            continue;
        end

        clf;

        % Main displacement plot
        subplot(2, 2, [1, 3]);
        scatter(x0, y0, 15, u_mag(:, frame), 'filled');
        colormap(hot);
        caxis([0, max(u_mag(:))*0.5]);
        axis equal;
        xlim([min(x0)-10, max(x0)+10]);
        ylim([min(y0)-10, max(y0)+10]);
        title(sprintf('Frame %d: Displacement Magnitude', frame));
        colorbar;

        % Displacement profile
        subplot(2, 2, 2);
        plot((x_bins(1:end-1) + x_bins(2:end))/2, kymograph(:, frame), 'b-', 'LineWidth', 1.5);
        xlabel('X Position');
        ylabel('X Displacement');
        title('Displacement Profile');
        ylim([min(kymograph(:)), max(kymograph(:))]);
        grid on;

        % Time series at a few positions
        subplot(2, 2, 4);
        hold on;
        positions = [0.2, 0.5, 0.8];  % Fractions of x-range
        for p = 1:length(positions)
            x_target = min(x0) + positions(p) * (max(x0) - min(x0));
            [~, bin_idx] = min(abs(x_bins - x_target));
            if bin_idx > 0 && bin_idx <= size(kymograph, 1)
                plot(1:frame, kymograph(bin_idx, 1:frame), 'LineWidth', 1.5);
            end
        end
        xlabel('Frame');
        ylabel('Displacement');
        title('Time Series at Different Positions');
        xlim([1, N_frames]);
        grid on;

        drawnow;
        frame_data = getframe(fig);
        writeVideo(v, frame_data);

        if mod(i, 50) == 0
            fprintf('  Frame %d/%d\n', i, length(frames_to_plot));
        end
    end

    close(v);
    fprintf('Animation saved to %s_animation.avi\n', output_name);
end

fprintf('Wave propagation visualization complete.\n');

end
