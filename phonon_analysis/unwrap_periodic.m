function xyz_unwrapped = unwrap_periodic(xyz, box_size)
%% UNWRAP_PERIODIC Remove periodic boundary jumps from particle trajectories
%
% When particles cross periodic boundaries (e.g., x goes from 499 to 1),
% this creates artificial jumps. This function "unwraps" the trajectories
% so displacements are continuous.
%
% INPUTS:
%   xyz      - Position data [N_particles, 3, N_frames]
%   box_size - [Lx, Ly, Lz] size of periodic box (can be [Lx, Ly] for 2D)
%
% OUTPUT:
%   xyz_unwrapped - Unwrapped positions with continuous trajectories
%
% Author: Gerbode Lab

[N_particles, N_dims, N_frames] = size(xyz);

% Handle 2D case
if length(box_size) == 2
    box_size = [box_size, inf];  % No wrapping in z
end

xyz_unwrapped = xyz;

fprintf('Unwrapping periodic boundaries (box: [%.1f, %.1f, %.1f])...\n', ...
    box_size(1), box_size(2), box_size(3));

n_wraps = 0;

for p = 1:N_particles
    for d = 1:min(N_dims, length(box_size))
        L = box_size(d);
        if isinf(L)
            continue;
        end

        % Get trajectory for this particle and dimension
        traj = squeeze(xyz(p, d, :));

        % Find jumps larger than half the box size
        diff_traj = diff(traj);

        % Cumulative correction
        correction = zeros(N_frames, 1);

        for t = 1:N_frames-1
            if diff_traj(t) > L/2
                % Jumped backward (wrapped from high to low)
                correction(t+1:end) = correction(t+1:end) - L;
                n_wraps = n_wraps + 1;
            elseif diff_traj(t) < -L/2
                % Jumped forward (wrapped from low to high)
                correction(t+1:end) = correction(t+1:end) + L;
                n_wraps = n_wraps + 1;
            end
        end

        xyz_unwrapped(p, d, :) = traj + correction;
    end
end

fprintf('  Corrected %d boundary crossings\n', n_wraps);

% Verify
x_range = max(xyz_unwrapped(:,1,:),[],'all') - min(xyz_unwrapped(:,1,:),[],'all');
y_range = max(xyz_unwrapped(:,2,:),[],'all') - min(xyz_unwrapped(:,2,:),[],'all');

fprintf('  New position ranges: X=[%.1f], Y=[%.1f]\n', x_range, y_range);

end
