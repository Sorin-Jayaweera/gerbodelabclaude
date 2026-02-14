function compare_drive_directions(base_path, output_folder)
%% COMPARE_DRIVE_DIRECTIONS Compare X-driven vs Y-driven zigzag
%
% Tests directional anisotropy in zigzag domain wave propagation
%
% INPUTS:
%   base_path     - Base path containing all simulation folders
%   output_folder - Where to save comparison results
%
% Author: Gerbode Lab
% Date: 2026

fprintf('============================================\n');
fprintf('  COMPARING DRIVE DIRECTIONS (X vs Y)\n');
fprintf('============================================\n');

%% Load results
% X-driven zigzag
x_results_file = fullfile(base_path, 'drivensinesims', 'analysis', 'dispersion_results_zigzag.mat');
y_results_file = fullfile(base_path, 'topdrivensims', 'analysis', 'dispersion_results_topdriven.mat');

x_freq_file = fullfile(base_path, 'drivensinesims', 'analysis', 'freq_response_zigzag.mat');
y_freq_file = fullfile(base_path, 'topdrivensims', 'analysis', 'freq_response_topdriven.mat');

x_results = [];
y_results = [];
x_freq = [];
y_freq = [];

if exist(x_results_file, 'file')
    loaded = load(x_results_file);
    x_results = loaded.results;
    fprintf('  Loaded X-driven dispersion\n');
end

if exist(y_results_file, 'file')
    loaded = load(y_results_file);
    y_results = loaded.results;
    fprintf('  Loaded Y-driven dispersion\n');
end

if exist(x_freq_file, 'file')
    loaded = load(x_freq_file);
    x_freq = loaded.results;
    fprintf('  Loaded X-driven frequency response\n');
end

if exist(y_freq_file, 'file')
    loaded = load(y_freq_file);
    y_freq = loaded.results;
    fprintf('  Loaded Y-driven frequency response\n');
end

if isempty(x_results) && isempty(y_results)
    warning('No results found for either X or Y driving');
    return;
end

%% Create comparison figure
fig = figure('Position', [100 100 1400 1000], 'Visible', 'off');

% Plot 1: Dispersion relation
subplot(2, 3, 1);
hold on;
legend_entries = {};
if ~isempty(x_results)
    valid = ~isnan(x_results.k);
    plot(x_results.k(valid), x_results.omega(valid), 'bo-', ...
        'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
    legend_entries{end+1} = 'X-drive (horizontal)';
end
if ~isempty(y_results)
    valid = ~isnan(y_results.k);
    plot(y_results.k(valid), y_results.omega(valid), 'rs-', ...
        'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    legend_entries{end+1} = 'Y-drive (vertical)';
end
hold off;
xlabel('Wavevector k (1/px)');
ylabel('Angular frequency ω (rad/frame)');
title('Dispersion Relation ω(k)');
legend(legend_entries, 'Location', 'best');
grid on;

% Plot 2: Wavelength
subplot(2, 3, 2);
hold on;
if ~isempty(x_results)
    valid = ~isnan(x_results.wavelengths);
    semilogy(x_results.frequencies(valid), x_results.wavelengths(valid), 'bo-', ...
        'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
end
if ~isempty(y_results)
    valid = ~isnan(y_results.wavelengths);
    semilogy(y_results.frequencies(valid), y_results.wavelengths(valid), 'rs-', ...
        'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
end
hold off;
xlabel('Drive frequency f');
ylabel('Wavelength λ (px)');
title('Wavelength vs Frequency');
legend(legend_entries, 'Location', 'best');
grid on;

% Plot 3: Phase velocity
subplot(2, 3, 3);
hold on;
if ~isempty(x_results)
    valid = ~isnan(x_results.phase_velocity);
    semilogx(x_results.frequencies(valid), x_results.phase_velocity(valid), 'bo-', ...
        'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
end
if ~isempty(y_results)
    valid = ~isnan(y_results.phase_velocity);
    semilogx(y_results.frequencies(valid), y_results.phase_velocity(valid), 'rs-', ...
        'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
end
hold off;
xlabel('Drive frequency f');
ylabel('Phase velocity v_p (px/frame)');
title('Phase Velocity');
legend(legend_entries, 'Location', 'best');
grid on;

% Plot 4: Amplitude
subplot(2, 3, 4);
hold on;
if ~isempty(x_results)
    valid = ~isnan(x_results.amplitudes);
    loglog(x_results.frequencies(valid), x_results.amplitudes(valid), 'bo-', ...
        'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
end
if ~isempty(y_results)
    valid = ~isnan(y_results.amplitudes);
    loglog(y_results.frequencies(valid), y_results.amplitudes(valid), 'rs-', ...
        'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
end
hold off;
xlabel('Drive frequency f');
ylabel('Response amplitude (px)');
title('Amplitude Response');
legend(legend_entries, 'Location', 'best');
grid on;

% Plot 5: Anisotropy ratio
subplot(2, 3, 5);
if ~isempty(x_results) && ~isempty(y_results)
    [common_f, ix, iy] = intersect(x_results.frequencies, y_results.frequencies);

    if ~isempty(common_f)
        % Wavelength ratio
        ratio_lambda = x_results.wavelengths(ix) ./ y_results.wavelengths(iy);
        % Velocity ratio
        ratio_v = x_results.phase_velocity(ix) ./ y_results.phase_velocity(iy);

        hold on;
        semilogx(common_f, ratio_lambda, 'go-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'MarkerFaceColor', 'g', 'DisplayName', 'λ_x / λ_y');
        semilogx(common_f, ratio_v, 'm^-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'MarkerFaceColor', 'm', 'DisplayName', 'v_x / v_y');
        yline(1, '--k', 'DisplayName', 'Isotropic');
        hold off;

        xlabel('Frequency f');
        ylabel('Ratio (X / Y)');
        title('Anisotropy Ratio');
        legend('Location', 'best');
        grid on;
    else
        text(0.5, 0.5, 'No common frequencies', 'HorizontalAlignment', 'center');
        axis off;
    end
else
    text(0.5, 0.5, 'Need both X and Y data', 'HorizontalAlignment', 'center');
    axis off;
end

% Plot 6: Geometry diagram
subplot(2, 3, 6);
hold on;
% Draw zigzag pattern schematic
y_zig = 0:0.5:5;
x_zig = mod(0:length(y_zig)-1, 2) * 0.3;
plot(x_zig + 1, y_zig, 'k-', 'LineWidth', 2);
plot(x_zig + 2, y_zig, 'k-', 'LineWidth', 2);
plot(x_zig + 3, y_zig, 'k-', 'LineWidth', 2);

% X-drive arrow
quiver(0, 2.5, 0.7, 0, 'b', 'LineWidth', 3, 'MaxHeadSize', 0.8);
text(0.35, 2.9, 'X-drive', 'Color', 'b', 'FontWeight', 'bold');

% Y-drive arrow
quiver(2, 6, 0, -0.7, 'r', 'LineWidth', 3, 'MaxHeadSize', 0.8);
text(2.2, 5.7, 'Y-drive', 'Color', 'r', 'FontWeight', 'bold');

axis equal;
xlim([-0.5 4.5]);
ylim([-0.5 6.5]);
title('Drive Directions on Zigzag');
set(gca, 'XTick', [], 'YTick', []);
box on;
hold off;

sgtitle('Zigzag Directional Anisotropy: X-drive vs Y-drive', 'FontSize', 16);

%% Save
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

saveas(fig, fullfile(output_folder, 'drive_direction_comparison.png'));
saveas(fig, fullfile(output_folder, 'drive_direction_comparison.fig'));
close(fig);

% Save data
comparison_data = struct();
comparison_data.x_results = x_results;
comparison_data.y_results = y_results;
save(fullfile(output_folder, 'drive_direction_data.mat'), 'comparison_data');

fprintf('Comparison saved to: %s\n', output_folder);
fprintf('============================================\n\n');

end
