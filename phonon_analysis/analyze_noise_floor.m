function results = analyze_noise_floor(sim_path, output_prefix)
%% ANALYZE_NOISE_FLOOR Analyze thermal noise in control (no-drive) simulations
%
% INPUTS:
%   sim_path      - Path to the no-drive simulation folder
%   output_prefix - Prefix for output files
%
% OUTPUTS:
%   results       - Structure with noise analysis results
%
% Author: Gerbode Lab
% Date: 2026

fprintf('Analyzing noise floor: %s\n', sim_path);

%% Load data
plist_file = fullfile(sim_path, 'plist.mat');
if ~exist(plist_file, 'file')
    error('No plist.mat found in %s', sim_path);
end

loaded = load(plist_file);
plist = loaded.plist;

% Load parameters
params_file = fullfile(sim_path, 'sim_params.mat');
if exist(params_file, 'file')
    params = load(params_file);
    sim_params = params.sim_params;
else
    sim_params = struct('width', 800, 'height', 400, 'data_saving_frequency', 2);
end

%% Convert to xyz
frames = unique(plist(:, 4));
n_frames = length(frames);
n_particles = sum(plist(:, 4) == frames(1));

xyz = zeros(n_particles, 3, n_frames);
for ff = 1:n_frames
    frame_mask = plist(:, 4) == frames(ff);
    xyz(:, :, ff) = plist(frame_mask, 1:3);
end

fprintf('  %d particles, %d frames\n', n_particles, n_frames);

%% Compute equilibrium positions
n_equil = min(100, n_frames);
x0 = mean(squeeze(xyz(:, 1, 1:n_equil)), 2);
y0 = mean(squeeze(xyz(:, 2, 1:n_equil)), 2);
z0 = mean(squeeze(xyz(:, 3, 1:n_equil)), 2);

%% Compute displacements
dx = squeeze(xyz(:, 1, :)) - x0;
dy = squeeze(xyz(:, 2, :)) - y0;
dz = squeeze(xyz(:, 3, :)) - z0;

%% Statistics
results = struct();
results.sim_path = sim_path;
results.n_particles = n_particles;
results.n_frames = n_frames;

% RMS displacements
results.rms_x = rms(dx(:));
results.rms_y = rms(dy(:));
results.rms_z = rms(dz(:));
results.rms_total = sqrt(results.rms_x^2 + results.rms_y^2);

% Standard deviation per particle
results.std_x_per_particle = std(dx, 0, 2);
results.std_y_per_particle = std(dy, 0, 2);

% Power spectrum of average displacement
avg_dx = mean(dx, 1);
avg_dy = mean(dy, 1);

% FFT
dt = sim_params.data_saving_frequency;
fs = 1 / dt;  % Sampling frequency
n_fft = length(avg_dx);
freqs = (0:n_fft-1) * fs / n_fft;

fft_x = fft(avg_dx);
fft_y = fft(avg_dy);

power_x = abs(fft_x(1:floor(n_fft/2))).^2 / n_fft;
power_y = abs(fft_y(1:floor(n_fft/2))).^2 / n_fft;
freqs_half = freqs(1:floor(n_fft/2));

results.freqs = freqs_half;
results.power_x = power_x;
results.power_y = power_y;

% Noise floor estimate (median of power spectrum)
results.noise_floor_x = median(power_x);
results.noise_floor_y = median(power_y);

fprintf('  RMS displacement: x=%.4f, y=%.4f, z=%.4f px\n', ...
    results.rms_x, results.rms_y, results.rms_z);
fprintf('  Noise floor: x=%.2e, y=%.2e\n', ...
    results.noise_floor_x, results.noise_floor_y);

%% Save results
[output_dir, ~, ~] = fileparts(output_prefix);
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

save([output_prefix '_results.mat'], 'results');

%% Generate plots
fig = figure('Position', [100 100 1200 400], 'Visible', 'off');

% Plot 1: Displacement histogram
subplot(1, 3, 1);
histogram(dx(:), 50, 'Normalization', 'pdf', 'FaceAlpha', 0.7);
hold on;
histogram(dy(:), 50, 'Normalization', 'pdf', 'FaceAlpha', 0.7);
hold off;
xlabel('Displacement (px)');
ylabel('Probability density');
title('Thermal Fluctuations');
legend('X', 'Y');
xlim([-20 20]);  % Zoom to relevant range

% Plot 2: Power spectrum
subplot(1, 3, 2);
loglog(freqs_half(2:end), power_x(2:end), '-', 'LineWidth', 1.5);
hold on;
loglog(freqs_half(2:end), power_y(2:end), '-', 'LineWidth', 1.5);
yline(results.noise_floor_x, '--', 'Color', [0.5 0.5 0.5]);
hold off;
xlabel('Frequency');
ylabel('Power');
title('Noise Power Spectrum');
legend('X', 'Y', 'Noise floor');

% Plot 3: Spatial map of fluctuation magnitude
subplot(1, 3, 3);
scatter(x0, y0, 20, results.std_x_per_particle, 'filled');
colorbar;
xlabel('X position');
ylabel('Y position');
title('Local fluctuation amplitude');
axis equal tight;

sgtitle('Control Simulation (No Drive)', 'FontSize', 12);

saveas(fig, [output_prefix '_noise.png']);
close(fig);

fprintf('  Saved to: %s\n\n', output_prefix);

end
