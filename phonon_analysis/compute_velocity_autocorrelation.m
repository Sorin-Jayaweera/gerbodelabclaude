function [vacf, t_lag, dos] = compute_velocity_autocorrelation(xyz, dt, max_lag_fraction)
%% COMPUTE_VELOCITY_AUTOCORRELATION Compute velocity autocorrelation function
%
% The velocity autocorrelation function (VACF) is a key quantity in
% statistical mechanics. Its Fourier transform gives the density of states (DOS).
%
% VACF(t) = <v(0) . v(t)> averaged over all particles and time origins
%
% INPUTS:
%   xyz             - Position data [N_particles, 3, N_frames]
%   dt              - Time step between frames
%   max_lag_fraction - Maximum lag as fraction of total time (default: 0.5)
%
% OUTPUTS:
%   vacf            - Velocity autocorrelation function
%   t_lag           - Time lag array
%   dos             - Density of states (Fourier transform of VACF)
%
% Author: Gerbode Lab

if nargin < 3
    max_lag_fraction = 0.5;
end

[N_particles, N_dims, N_frames] = size(xyz);

% Compute velocities using central differences
fprintf('Computing velocities...\n');
v = zeros(N_particles, N_dims, N_frames-2);
for d = 1:N_dims
    pos = squeeze(xyz(:, d, :));
    v(:, d, :) = (pos(:, 3:end) - pos(:, 1:end-2)) / (2*dt);
end

N_frames_v = N_frames - 2;
max_lag = floor(N_frames_v * max_lag_fraction);

%% Compute VACF using FFT for efficiency
fprintf('Computing velocity autocorrelation function...\n');

% For each particle and dimension, compute autocorrelation
vacf_all = zeros(max_lag + 1, N_particles, N_dims);

for i = 1:N_particles
    for d = 1:N_dims
        vi = squeeze(v(i, d, :));

        % Use FFT-based autocorrelation for efficiency
        % Pad to next power of 2
        n_fft = 2^nextpow2(2*N_frames_v - 1);
        vi_fft = fft(vi, n_fft);
        acf_full = ifft(vi_fft .* conj(vi_fft));

        % Take positive lags and normalize
        acf = real(acf_full(1:max_lag+1));

        % Normalize by number of overlapping points
        norm_factor = N_frames_v - (0:max_lag)';
        acf = acf ./ norm_factor;

        vacf_all(:, i, d) = acf;
    end
end

% Average over all particles and dimensions
vacf = mean(mean(vacf_all, 3), 2);

% Normalize so VACF(0) = 1
vacf = vacf / vacf(1);

% Time lag array
t_lag = (0:max_lag)' * dt;

%% Compute density of states (DOS) via Fourier transform
fprintf('Computing density of states...\n');

% Apply windowing
window = hann_window(length(vacf));
vacf_windowed = vacf .* window;

% Zero-pad for better frequency resolution
n_fft_dos = 2^nextpow2(4 * length(vacf));
dos_complex = fft(vacf_windowed, n_fft_dos);
dos = real(dos_complex(1:n_fft_dos/2+1));

% Frequency array
f_dos = (0:n_fft_dos/2) / (n_fft_dos * dt);

%% Create output structure
dos_struct.f = f_dos;
dos_struct.g = dos;
dos = dos_struct;

%% Visualization
figure('Position', [100, 100, 1200, 400]);

subplot(1, 3, 1);
plot(t_lag, vacf, 'b-', 'LineWidth', 1.5);
xlabel('Time lag');
ylabel('VACF (normalized)');
title('Velocity Autocorrelation Function');
grid on;

subplot(1, 3, 2);
% Plot first part of VACF to see oscillations
t_short = min(100, length(t_lag));
plot(t_lag(1:t_short), vacf(1:t_short), 'b-', 'LineWidth', 1.5);
xlabel('Time lag');
ylabel('VACF (normalized)');
title('VACF (zoomed)');
grid on;

subplot(1, 3, 3);
plot(dos.f, dos.g, 'r-', 'LineWidth', 1.5);
xlabel('Frequency');
ylabel('Density of States');
title('Vibrational Density of States');
xlim([0, max(dos.f)/4]);  % Focus on lower frequencies
grid on;

fprintf('VACF computation complete.\n');

end
