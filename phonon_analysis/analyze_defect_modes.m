function results = analyze_defect_modes(xyz, x0, y0, neighbors, defect_indices, lattice_constant)
%% ANALYZE_DEFECT_MODES Analyze how defects affect phonon modes
%
% This function analyzes the localized modes around defects (5-7 pairs,
% vacancies, spin defects) and how they differ from bulk modes.
%
% INPUTS:
%   xyz             - Position data [N_particles, 3, N_frames]
%   x0, y0          - Equilibrium positions
%   neighbors       - Neighbor data (cell array or matrix)
%   defect_indices  - Indices of particles that are defects (or empty to auto-detect)
%   lattice_constant - Expected nearest-neighbor distance
%
% OUTPUTS:
%   results         - Structure containing defect mode analysis
%
% Author: Gerbode Lab

[N_particles, N_dims, N_frames] = size(xyz);

if nargin < 6 || isempty(lattice_constant)
    lattice_constant = estimate_lattice_constant(x0, y0);
end

%% Auto-detect defects if not provided
if nargin < 5 || isempty(defect_indices)
    fprintf('Auto-detecting defects based on coordination number...\n');
    defect_indices = detect_coordination_defects(x0, y0, neighbors, lattice_constant);
end

fprintf('Found %d defect particles\n', length(defect_indices));

%% Classify particles
bulk_indices = setdiff(1:N_particles, defect_indices);

% Also find particles near defects (within 2 lattice constants)
near_defect_indices = [];
for d = defect_indices'
    dists = sqrt((x0 - x0(d)).^2 + (y0 - y0(d)).^2);
    near = find(dists < 2*lattice_constant & dists > 0);
    near_defect_indices = union(near_defect_indices, near);
end
near_defect_indices = setdiff(near_defect_indices, defect_indices);

far_bulk_indices = setdiff(bulk_indices, near_defect_indices);

fprintf('Particle classification:\n');
fprintf('  Defects: %d\n', length(defect_indices));
fprintf('  Near defects: %d\n', length(near_defect_indices));
fprintf('  Bulk (far from defects): %d\n', length(far_bulk_indices));

%% Compute displacements
x = squeeze(xyz(:, 1, :));
y = squeeze(xyz(:, 2, :));

ux = x - x0;
uy = y - y0;

% Remove drift
ux = ux - mean(ux, 1);
uy = uy - mean(uy, 1);

%% Compute power spectra for each group
dt = 1;  % Normalize time
fs = 1/dt;
f = (0:N_frames-1) * fs / N_frames;
n_pos = floor(N_frames/2) + 1;
f_pos = f(1:n_pos);

window = hanning(N_frames)';

% Function to compute average power spectrum for a group
compute_group_spectrum = @(indices) compute_avg_spectrum(ux(indices,:), uy(indices,:), window, n_pos);

[P_defect, P_defect_x, P_defect_y] = compute_group_spectrum(defect_indices);
[P_near, P_near_x, P_near_y] = compute_group_spectrum(near_defect_indices);
[P_bulk, P_bulk_x, P_bulk_y] = compute_group_spectrum(far_bulk_indices);

%% Compute localization around defects
% For each frequency, compute what fraction of power is near defects

n_defect_region = length(defect_indices) + length(near_defect_indices);
n_bulk_region = length(far_bulk_indices);

localization = zeros(1, n_pos);
for iw = 1:n_pos
    P_defect_total = sum(abs(fft(ux(defect_indices,:) .* window, [], 2)).^2, 1) + ...
                     sum(abs(fft(uy(defect_indices,:) .* window, [], 2)).^2, 1);
    P_near_total = sum(abs(fft(ux(near_defect_indices,:) .* window, [], 2)).^2, 1) + ...
                   sum(abs(fft(uy(near_defect_indices,:) .* window, [], 2)).^2, 1);
    P_bulk_total = sum(abs(fft(ux(far_bulk_indices,:) .* window, [], 2)).^2, 1) + ...
                   sum(abs(fft(uy(far_bulk_indices,:) .* window, [], 2)).^2, 1);

    % Normalize by number of particles
    P_defect_norm = P_defect_total(iw) / max(1, length(defect_indices));
    P_near_norm = P_near_total(iw) / max(1, length(near_defect_indices));
    P_bulk_norm = P_bulk_total(iw) / max(1, length(far_bulk_indices));

    total_norm = P_defect_norm + P_near_norm + P_bulk_norm;
    if total_norm > 0
        localization(iw) = (P_defect_norm + P_near_norm) / total_norm;
    end
end

%% Visualization
figure('Position', [100, 100, 1400, 800]);

% Plot 1: Power spectra comparison
subplot(2, 3, 1);
semilogy(f_pos, P_defect, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Defects');
hold on;
semilogy(f_pos, P_near, 'm-', 'LineWidth', 1.5, 'DisplayName', 'Near defects');
semilogy(f_pos, P_bulk, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Bulk');
xlabel('Frequency');
ylabel('Power (per particle)');
title('Power Spectra by Region');
legend('Location', 'northeast');
grid on;
xlim([0, max(f_pos)/2]);

% Plot 2: Localization
subplot(2, 3, 2);
plot(f_pos, localization, 'k-', 'LineWidth', 1.5);
xlabel('Frequency');
ylabel('Localization near defects');
title('Mode Localization');
ylim([0, 1]);
grid on;
xlim([0, max(f_pos)/2]);

% Plot 3: Ratio of defect to bulk power
subplot(2, 3, 3);
ratio = P_defect ./ (P_bulk + 1e-10);
semilogy(f_pos, ratio, 'k-', 'LineWidth', 1.5);
hold on;
yline(1, 'r--', 'LineWidth', 1);
xlabel('Frequency');
ylabel('Defect / Bulk power ratio');
title('Defect Enhancement');
grid on;
xlim([0, max(f_pos)/2]);

% Plot 4: Spatial distribution of particles
subplot(2, 3, 4);
scatter(x0(far_bulk_indices), y0(far_bulk_indices), 10, 'b', 'filled', 'MarkerFaceAlpha', 0.3);
hold on;
scatter(x0(near_defect_indices), y0(near_defect_indices), 20, 'm', 'filled');
scatter(x0(defect_indices), y0(defect_indices), 40, 'r', 'filled');
axis equal;
legend('Bulk', 'Near defects', 'Defects', 'Location', 'best');
title('Particle Classification');
xlabel('x'); ylabel('y');

% Plot 5: Component-resolved comparison
subplot(2, 3, 5);
semilogy(f_pos, P_defect_x, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Defect X');
hold on;
semilogy(f_pos, P_defect_y, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Defect Y');
semilogy(f_pos, P_bulk_x, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Bulk X');
semilogy(f_pos, P_bulk_y, 'b--', 'LineWidth', 1.5, 'DisplayName', 'Bulk Y');
xlabel('Frequency');
ylabel('Power (per particle)');
title('X vs Y Components');
legend('Location', 'northeast');
grid on;
xlim([0, max(f_pos)/2]);

% Plot 6: Find localized mode frequencies
subplot(2, 3, 6);
% Frequencies where modes are most localized at defects
[~, loc_sorted] = sort(localization, 'descend');
top_localized = loc_sorted(1:min(5, length(loc_sorted)));

semilogy(f_pos, P_defect, 'r-', 'LineWidth', 1);
hold on;
for i = 1:length(top_localized)
    idx = top_localized(i);
    plot(f_pos(idx), P_defect(idx), 'ko', 'MarkerSize', 10, 'LineWidth', 2);
end
xlabel('Frequency');
ylabel('Defect Power');
title('Most Localized Modes (marked)');
grid on;
xlim([0, max(f_pos)/2]);

saveas(gcf, 'defect_mode_analysis.png');
saveas(gcf, 'defect_mode_analysis.fig');

%% Package results
results = struct();
results.defect_indices = defect_indices;
results.near_defect_indices = near_defect_indices;
results.bulk_indices = far_bulk_indices;
results.f = f_pos;
results.P_defect = P_defect;
results.P_near = P_near;
results.P_bulk = P_bulk;
results.localization = localization;
results.top_localized_freqs = f_pos(top_localized);

fprintf('\nDefect mode analysis complete.\n');
fprintf('Most localized mode frequencies: ');
fprintf('%.4f  ', results.top_localized_freqs);
fprintf('\n');

end

%% Helper functions

function defect_indices = detect_coordination_defects(x0, y0, neighbors, lattice_constant)
    % Detect particles with non-6 coordination
    N = length(x0);

    if isempty(neighbors)
        % Compute neighbors from positions
        cutoff = lattice_constant * 1.3;
        coordination = zeros(N, 1);
        for i = 1:N
            dists = sqrt((x0 - x0(i)).^2 + (y0 - y0(i)).^2);
            coordination(i) = sum(dists > 0 & dists < cutoff);
        end
    elseif iscell(neighbors)
        coordination = cellfun(@length, neighbors);
    else
        coordination = sum(neighbors > 0, 2);
    end

    % Perfect coordination for triangular lattice is 6
    defect_indices = find(coordination ~= 6);
end

function [P_avg, P_x, P_y] = compute_avg_spectrum(ux, uy, window, n_pos)
    % Compute average power spectrum for a group of particles
    n_particles = size(ux, 1);

    if n_particles == 0
        P_avg = zeros(1, n_pos);
        P_x = zeros(1, n_pos);
        P_y = zeros(1, n_pos);
        return;
    end

    Ux = fft(ux .* window, [], 2);
    Uy = fft(uy .* window, [], 2);

    Px = abs(Ux).^2;
    Py = abs(Uy).^2;

    P_x = mean(Px(:, 1:n_pos), 1);
    P_y = mean(Py(:, 1:n_pos), 1);
    P_avg = P_x + P_y;
end

function a = estimate_lattice_constant(x0, y0)
    N = length(x0);
    min_dists = zeros(N, 1);
    for i = 1:N
        dx = x0 - x0(i);
        dy = y0 - y0(i);
        r = sqrt(dx.^2 + dy.^2);
        r(i) = inf;
        min_dists(i) = min(r);
    end
    a = mean(min_dists);
end
