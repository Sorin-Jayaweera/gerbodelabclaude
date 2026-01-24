function xyz = plist2xyz_auto(plist)
%% PLIST2XYZ_AUTO Convert plist to xyz array with automatic dimension detection
%
% Wrapper for plist2xyz that automatically determines num_particles and
% num_saved_frames from the plist data.
%
% INPUT:
%   plist - Nx4 array where columns are [x, y, z, frame_number]
%           or Nx3 array where columns are [x, y, frame_number]
%
% OUTPUT:
%   xyz - [num_particles, 3, num_frames] array of positions
%
% Author: Gerbode Lab

% Determine plist format
[n_rows, n_cols] = size(plist);
fprintf('  plist size: [%d, %d]\n', n_rows, n_cols);

% The last column should be frame numbers
frame_col = plist(:, end);
frames = unique(frame_col);
num_saved_frames = length(frames);

% Number of particles = total rows / number of frames
num_particles = n_rows / num_saved_frames;

if mod(num_particles, 1) ~= 0
    error('plist rows (%d) not evenly divisible by frames (%d)', n_rows, num_saved_frames);
end

num_particles = round(num_particles);

fprintf('  Detected: %d particles, %d frames\n', num_particles, num_saved_frames);

% Check if plist2xyz is available, otherwise do conversion ourselves
if exist('plist2xyz', 'file')
    try
        xyz = plist2xyz(plist, num_particles, num_saved_frames);
        return;
    catch
        fprintf('  plist2xyz failed, using manual conversion...\n');
    end
end

% Manual conversion
% plist format: each frame's particles are listed sequentially
% [x1_t1, y1_t1, z1_t1, t1]
% [x2_t1, y2_t1, z2_t1, t1]
% ...
% [x1_t2, y1_t2, z1_t2, t2]
% ...

if n_cols >= 4
    % Has x, y, z, frame
    pos_data = plist(:, 1:3);
else
    % Has x, y, frame - add zeros for z
    pos_data = [plist(:, 1:2), zeros(n_rows, 1)];
end

% Reshape: we have num_particles rows per frame, num_saved_frames frames
% pos_data is [num_particles * num_saved_frames, 3]
% We want xyz as [num_particles, 3, num_saved_frames]

xyz = zeros(num_particles, 3, num_saved_frames);

for f = 1:num_saved_frames
    start_idx = (f - 1) * num_particles + 1;
    end_idx = f * num_particles;
    xyz(:, :, f) = pos_data(start_idx:end_idx, :);
end

fprintf('  Output xyz size: [%d, %d, %d]\n', size(xyz, 1), size(xyz, 2), size(xyz, 3));

end
