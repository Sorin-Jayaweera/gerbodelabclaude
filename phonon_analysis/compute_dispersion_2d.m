function [dispersion, kx, ky, f, path_dispersion, k_path] = compute_dispersion_2d(xyz, x0, y0, dt, lattice_constant)
%% COMPUTE_DISPERSION_2D Compute full 2D dispersion relation S(kx, ky, omega)
%
% Computes the dynamical structure factor S(k, omega) which reveals
% the phonon dispersion relation for a 2D crystal.
%
% INPUTS:
%   xyz             - Position data [N_particles, 3, N_frames]
%   x0, y0          - Equilibrium positions
%   dt              - Time step between frames
%   lattice_constant - Nearest-neighbor distance
%
% OUTPUTS:
%   dispersion      - S(kx, ky, omega) [n_kx, n_ky, n_omega]
%   kx, ky          - Wavevector arrays
%   f               - Frequency array
%   path_dispersion - Dispersion along high-symmetry path
%   k_path          - Path coordinate
%
% Author: Gerbode Lab

[N_particles, ~, N_frames] = size(xyz);

if nargin < 4
    dt = 1;
end
if nargin < 5
    lattice_constant = 10.6;
end

fprintf('Computing 2D dispersion relation...\n');

%% Extract displacements
x = squeeze(xyz(:, 1, :));
y = squeeze(xyz(:, 2, :));

ux = x - x0;
uy = y - y0;
ux = ux - mean(ux, 1);
uy = uy - mean(uy, 1);

%% Frequency array
fs = 1/dt;
f_full = (0:N_frames-1) * fs / N_frames;
n_omega = floor(N_frames/2) + 1;
f = f_full(1:n_omega);

%% Reciprocal lattice for triangular lattice
% Real-space lattice vectors
a1 = lattice_constant * [1, 0];
a2 = lattice_constant * [0.5, sqrt(3)/2];

% Reciprocal lattice vectors: b_i . a_j = 2*pi*delta_ij
A = [a1; a2]';
B = 2*pi * inv(A)';
b1 = B(1, :);
b2 = B(2, :);

fprintf('  Reciprocal lattice vectors:\n');
fprintf('    b1 = [%.3f, %.3f]\n', b1(1), b1(2));
fprintf('    b2 = [%.3f, %.3f]\n', b2(1), b2(2));

%% Set up k-space grid
% First Brillouin zone for triangular lattice is a hexagon
% We'll compute over a rectangular region that contains it

k_max = max(norm(b1), norm(b2));
n_k = 30;  % Grid points along each direction

kx = linspace(-k_max, k_max, n_k);
ky = linspace(-k_max, k_max, n_k);
[KX, KY] = meshgrid(kx, ky);

%% Compute temporal FFT of displacements
fprintf('  Computing temporal FFT...\n');
window = hann_window(N_frames)';
Ux = fft(ux .* window, [], 2);  % [N_particles, N_frames]
Uy = fft(uy .* window, [], 2);

%% Compute S(k, omega)
fprintf('  Computing S(k, omega) for %d k-points...\n', n_k^2);
dispersion = zeros(n_k, n_k, n_omega);

for ix = 1:n_k
    for iy = 1:n_k
        kx_val = kx(ix);
        ky_val = ky(iy);

        % Phase factor: exp(-i * k . r) for each particle
        phase = exp(-1i * (kx_val * x0 + ky_val * y0));

        for iw = 1:n_omega
            % S(k, omega) = |sum_j u_j(omega) * exp(-i*k*r_j)|^2
            Sk_x = sum(Ux(:, iw) .* phase);
            Sk_y = sum(Uy(:, iw) .* phase);
            dispersion(iy, ix, iw) = abs(Sk_x)^2 + abs(Sk_y)^2;
        end
    end

    if mod(ix, 10) == 0
        fprintf('    %d/%d k-points done\n', ix*n_k, n_k^2);
    end
end

%% High-symmetry path through Brillouin zone
% For triangular lattice: Gamma -> M -> K -> Gamma
% Gamma = (0, 0)
% M = b1/2 (midpoint of BZ edge)
% K = (b1 + b2)/3 (corner of BZ)

Gamma = [0, 0];
M = b1 / 2;
K = (b1 + b2) / 3;

% Define path
path_points = [Gamma; M; K; Gamma];
path_names = {'\Gamma', 'M', 'K', '\Gamma'};
n_path_per_segment = 30;

k_path_x = [];
k_path_y = [];
path_ticks = [0];

for seg = 1:size(path_points, 1) - 1
    start_pt = path_points(seg, :);
    end_pt = path_points(seg + 1, :);

    t = linspace(0, 1, n_path_per_segment);
    k_path_x = [k_path_x, start_pt(1) + t * (end_pt(1) - start_pt(1))];
    k_path_y = [k_path_y, start_pt(2) + t * (end_pt(2) - start_pt(2))];

    path_ticks = [path_ticks, path_ticks(end) + norm(end_pt - start_pt)];
end

n_path = length(k_path_x);
k_path = zeros(n_path, 1);
k_path(1) = 0;
for i = 2:n_path
    k_path(i) = k_path(i-1) + sqrt((k_path_x(i) - k_path_x(i-1))^2 + ...
        (k_path_y(i) - k_path_y(i-1))^2);
end

%% Compute S along high-symmetry path
fprintf('  Computing dispersion along high-symmetry path...\n');
path_dispersion = zeros(n_path, n_omega);

for ip = 1:n_path
    kx_val = k_path_x(ip);
    ky_val = k_path_y(ip);

    phase = exp(-1i * (kx_val * x0 + ky_val * y0));

    for iw = 1:n_omega
        Sk_x = sum(Ux(:, iw) .* phase);
        Sk_y = sum(Uy(:, iw) .* phase);
        path_dispersion(ip, iw) = abs(Sk_x)^2 + abs(Sk_y)^2;
    end
end

%% Visualization
figure('Position', [50, 50, 1400, 500]);

% 2D slice at selected frequencies
subplot(1, 3, 1);
[~, max_freq_idx] = max(sum(sum(dispersion, 1), 2));
imagesc(kx, ky, log10(dispersion(:, :, max_freq_idx) + 1));
axis equal tight;
xlabel('k_x'); ylabel('k_y');
title(sprintf('S(k) at f = %.4f', f(max_freq_idx)));
colorbar;

% Average over all frequencies (shows Brillouin zone structure)
subplot(1, 3, 2);
S_avg = mean(dispersion, 3);
imagesc(kx, ky, log10(S_avg + 1));
axis equal tight;
xlabel('k_x'); ylabel('k_y');
title('S(k) averaged over all frequencies');
colorbar;
hold on;
% Draw BZ boundary
plot([0, b1(1), b1(1)+b2(1), b2(1), 0], ...
     [0, b1(2), b1(2)+b2(2), b2(2), 0], 'w-', 'LineWidth', 2);

% High-symmetry path dispersion
subplot(1, 3, 3);
imagesc(k_path, f, log10(path_dispersion' + 1));
xlabel('k (along path)');
ylabel('Frequency');
title('Dispersion along \Gamma - M - K - \Gamma');
colorbar;
axis xy;

% Add path labels
hold on;
for i = 1:length(path_ticks)
    xline(path_ticks(i), 'w--');
end
xticks(path_ticks);
xticklabels(path_names);

saveas(gcf, 'dispersion_2d.png');
saveas(gcf, 'dispersion_2d.fig');

fprintf('Dispersion calculation complete.\n');

end
