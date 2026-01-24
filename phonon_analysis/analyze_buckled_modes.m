function results = analyze_buckled_modes(xyz, dt, lattice_constant)
%% ANALYZE_BUCKLED_MODES Specialized analysis for buckled monolayer phonons
%
% The buckled monolayer has out-of-plane (z) displacements that create
% additional vibrational modes. This function analyzes:
%   - Coupling between in-plane and out-of-plane modes
%   - Spin-like (alternating z) and uniform z modes
%   - Optical vs acoustic mode character
%
% INPUTS:
%   xyz             - Position data [N_particles, 3, N_frames]
%   dt              - Time step between frames
%   lattice_constant - Nearest-neighbor distance
%
% OUTPUTS:
%   results         - Structure with buckled mode analysis
%
% Author: Gerbode Lab

if nargin < 2
    dt = 1;
end
if nargin < 3
    lattice_constant = 10.6;  % Default for simulation
end

[N_particles, N_dims, N_frames] = size(xyz);

fprintf('Analyzing buckled monolayer modes...\n');
fprintf('  %d particles, %d frames\n', N_particles, N_frames);

%% Extract positions and equilibrium
x = squeeze(xyz(:, 1, :));
y = squeeze(xyz(:, 2, :));
z = squeeze(xyz(:, 3, :));

n_equil = min(10, N_frames);
x0 = mean(x(:, 1:n_equil), 2);
y0 = mean(y(:, 1:n_equil), 2);
z0 = mean(z(:, 1:n_equil), 2);

% Displacements
ux = x - x0; ux = ux - mean(ux, 1);
uy = y - y0; uy = uy - mean(uy, 1);
uz = z - z0; uz = uz - mean(uz, 1);

%% Identify "up" and "down" particles in buckled layer
% In buckled monolayer, particles alternate between up and down z-positions

z_mean = mean(z0);
z_std = std(z0);

if z_std < 0.01  % Flat monolayer
    fprintf('  Warning: Small z variation - this may be a flat monolayer\n');
    up_particles = 1:floor(N_particles/2);
    down_particles = (floor(N_particles/2)+1):N_particles;
else
    up_particles = find(z0 > z_mean);
    down_particles = find(z0 <= z_mean);
end

fprintf('  Up particles: %d, Down particles: %d\n', length(up_particles), length(down_particles));

%% Compute acoustic and optical mode projections
% Acoustic: all particles move together in z
% Optical: up and down particles move in opposite z directions

% Acoustic mode: average z displacement
z_acoustic = mean(uz, 1);

% Optical mode: difference between up and down
z_up = mean(uz(up_particles, :), 1);
z_down = mean(uz(down_particles, :), 1);
z_optical = (z_up - z_down) / 2;

% In-plane acoustic (center of mass motion)
x_acoustic = mean(ux, 1);
y_acoustic = mean(uy, 1);

%% Fourier analysis
window = hanning(N_frames)';
fs = 1/dt;
f = (0:N_frames-1) * fs / N_frames;
n_pos = floor(N_frames/2) + 1;
f_pos = f(1:n_pos);

% Total power spectra
Ux = fft(ux .* window, [], 2);
Uy = fft(uy .* window, [], 2);
Uz = fft(uz .* window, [], 2);

P_x = sum(abs(Ux).^2, 1) / N_frames;
P_y = sum(abs(Uy).^2, 1) / N_frames;
P_z = sum(abs(Uz).^2, 1) / N_frames;

% Acoustic/optical mode spectra
P_z_acoustic = abs(fft(z_acoustic .* window)).^2 / N_frames;
P_z_optical = abs(fft(z_optical .* window)).^2 / N_frames;
P_x_acoustic = abs(fft(x_acoustic .* window)).^2 / N_frames;
P_y_acoustic = abs(fft(y_acoustic .* window)).^2 / N_frames;

%% Mode coupling analysis
% Compute cross-correlation between in-plane and out-of-plane at each frequency

% For each frequency, compute correlation between x/y and z amplitudes
coupling_xz = zeros(1, n_pos);
coupling_yz = zeros(1, n_pos);

for iw = 1:n_pos
    amp_x = abs(Ux(:, iw));
    amp_y = abs(Uy(:, iw));
    amp_z = abs(Uz(:, iw));

    % Correlation coefficient
    if std(amp_x) > 0 && std(amp_z) > 0
        coupling_xz(iw) = abs(corr(amp_x, amp_z));
    end
    if std(amp_y) > 0 && std(amp_z) > 0
        coupling_yz(iw) = abs(corr(amp_y, amp_z));
    end
end

%% Spatial analysis of z-modes
% For buckled layers, look at spin-wave-like patterns

% Compute neighbors if not available
cutoff = lattice_constant * 1.3;
neighbors = cell(N_particles, 1);
for i = 1:N_particles
    dists = sqrt((x0 - x0(i)).^2 + (y0 - y0(i)).^2);
    neighbors{i} = find(dists > 0 & dists < cutoff);
end

% For each frequency, check if z-displacement alternates between neighbors
alternation = zeros(1, n_pos);
for iw = 1:n_pos
    z_mode = Uz(:, iw);
    phase_diff_sum = 0;
    count = 0;

    for i = 1:N_particles
        for j = neighbors{i}'
            if j > i
                % Phase difference between neighbors
                phase_i = angle(z_mode(i));
                phase_j = angle(z_mode(j));
                phase_diff = abs(mod(phase_i - phase_j + pi, 2*pi) - pi);
                phase_diff_sum = phase_diff_sum + phase_diff;
                count = count + 1;
            end
        end
    end

    if count > 0
        % Normalize: 0 = in-phase (acoustic), pi = anti-phase (optical)
        alternation(iw) = phase_diff_sum / count / pi;
    end
end

%% Visualization
figure('Position', [50, 50, 1400, 900], 'Name', 'Buckled Monolayer Modes');

% Component spectra
subplot(2, 3, 1);
semilogy(f_pos, P_x(1:n_pos), 'r-', 'LineWidth', 1.5, 'DisplayName', 'X');
hold on;
semilogy(f_pos, P_y(1:n_pos), 'b-', 'LineWidth', 1.5, 'DisplayName', 'Y');
semilogy(f_pos, P_z(1:n_pos), 'g-', 'LineWidth', 1.5, 'DisplayName', 'Z');
xlabel('Frequency');
ylabel('Power');
title('Component Power Spectra');
legend('Location', 'northeast');
grid on;
xlim([0, f_pos(end)/2]);

% Acoustic vs Optical
subplot(2, 3, 2);
semilogy(f_pos, P_z_acoustic(1:n_pos), 'b-', 'LineWidth', 1.5, 'DisplayName', 'Z Acoustic');
hold on;
semilogy(f_pos, P_z_optical(1:n_pos), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Z Optical');
xlabel('Frequency');
ylabel('Power');
title('Acoustic vs Optical Z-Modes');
legend('Location', 'northeast');
grid on;
xlim([0, f_pos(end)/2]);

% Mode coupling
subplot(2, 3, 3);
plot(f_pos, coupling_xz, 'r-', 'LineWidth', 1.5, 'DisplayName', 'X-Z coupling');
hold on;
plot(f_pos, coupling_yz, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Y-Z coupling');
xlabel('Frequency');
ylabel('Correlation');
title('In-plane / Out-of-plane Coupling');
legend('Location', 'northeast');
ylim([0, 1]);
grid on;
xlim([0, f_pos(end)/2]);

% Alternation (optical character)
subplot(2, 3, 4);
plot(f_pos, alternation, 'k-', 'LineWidth', 1.5);
xlabel('Frequency');
ylabel('Alternation (0=acoustic, 1=optical)');
title('Mode Character: Acoustic vs Optical');
ylim([0, 1]);
grid on;
xlim([0, f_pos(end)/2]);

% Equilibrium z-positions
subplot(2, 3, 5);
scatter(x0, y0, 30, z0, 'filled');
colormap(gca, cool);
colorbar;
axis equal;
title('Equilibrium Z-Heights');
xlabel('x'); ylabel('y');

% Up/Down particle identification
subplot(2, 3, 6);
scatter(x0(down_particles), y0(down_particles), 20, 'b', 'filled', 'DisplayName', 'Down');
hold on;
scatter(x0(up_particles), y0(up_particles), 20, 'r', 'filled', 'DisplayName', 'Up');
axis equal;
legend('Location', 'best');
title('Up/Down Particle Classification');
xlabel('x'); ylabel('y');

saveas(gcf, 'buckled_mode_analysis.png');
saveas(gcf, 'buckled_mode_analysis.fig');

%% Package results
results = struct();
results.f = f_pos;
results.P_x = P_x(1:n_pos);
results.P_y = P_y(1:n_pos);
results.P_z = P_z(1:n_pos);
results.P_z_acoustic = P_z_acoustic(1:n_pos);
results.P_z_optical = P_z_optical(1:n_pos);
results.coupling_xz = coupling_xz;
results.coupling_yz = coupling_yz;
results.alternation = alternation;
results.up_particles = up_particles;
results.down_particles = down_particles;
results.z0 = z0;
results.x0 = x0;
results.y0 = y0;

fprintf('Buckled mode analysis complete.\n');

% Report key findings
[~, max_optical_idx] = max(P_z_optical(1:n_pos));
[~, max_acoustic_idx] = max(P_z_acoustic(1:n_pos));
fprintf('\nKey frequencies:\n');
fprintf('  Peak optical Z-mode: f = %.4f\n', f_pos(max_optical_idx));
fprintf('  Peak acoustic Z-mode: f = %.4f\n', f_pos(max_acoustic_idx));

% Find most coupled modes
[max_coupling, max_coup_idx] = max(coupling_xz + coupling_yz);
fprintf('  Strongest in-plane/out-of-plane coupling: f = %.4f (corr = %.2f)\n', ...
    f_pos(max_coup_idx), max_coupling/2);

end
