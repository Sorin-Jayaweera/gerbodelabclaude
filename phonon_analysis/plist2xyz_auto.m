function xyz = plist2xyz_auto(plist, frame_skip)
%% PLIST2XYZ_AUTO Convert plist to xyz array with automatic dimension detection
%
% Wrapper for plist2xyz that automatically determines num_particles and
% num_saved_frames from the plist data.
%
% INPUT:
%   plist      - Nx4 array where columns are [x, y, z, frame_number]
%                or Nx3 array where columns are [x, y, frame_number]
%   frame_skip - (optional) Only use every Nth frame. Default: 1 (use all)
%                Set to 100 to use every 100th frame, reducing memory usage.
%
% OUTPUT:
%   xyz - [num_particles, 3, num_frames] array of positions
%
% Author: Gerbode Lab

if nargin < 2
    frame_skip = 1;
end

% Determine plist format
[n_rows, n_cols] = size(plist);
fprintf('  plist size: [%d, %d]\n', n_rows, n_cols);

% The last column should be frame numbers
frame_col = plist(:, end);

% Method 1: Count particles in first frame (more robust)
first_frame_val = frame_col(1);
num_particles = sum(frame_col == first_frame_val);

% Number of frames = total rows / particles per frame
num_saved_frames = n_rows / num_particles;

if mod(num_saved_frames, 1) ~= 0
    % Fallback: try unique frame counting
    fprintf('  Warning: uneven division, trying unique frame count...\n');
    frames = unique(frame_col);
    num_saved_frames = length(frames);
    num_particles = n_rows / num_saved_frames;

    if mod(num_particles, 1) ~= 0
        error('plist rows (%d) not evenly divisible. Particles in frame 1: %d, unique frames: %d', ...
            n_rows, sum(frame_col == first_frame_val), length(frames));
    end
end

num_saved_frames = round(num_saved_frames);
num_particles = round(num_particles);

fprintf('  Detected: %d particles, %d frames\n', num_particles, num_saved_frames);

% Apply frame skipping if requested
if frame_skip > 1
    fprintf('  Applying frame_skip=%d (using every %dth frame)...\n', frame_skip, frame_skip);
    num_output_frames = floor(num_saved_frames / frame_skip);
    fprintf('  Output will have %d frames\n', num_output_frames);
else
    num_output_frames = num_saved_frames;
end

% Warning for very large datasets
if num_output_frames > 5000
    fprintf('  WARNING: Still have %d frames. This may use significant memory.\n', num_output_frames);
    fprintf('           Consider using frame_skip parameter: plist2xyz_auto(plist, 100)\n');
end

% Manual conversion (more reliable than plist2xyz for large data)
% plist format: each frame's particles are listed sequentially
% [x1_t1, y1_t1, z1_t1, t1]
% [x2_t1, y2_t1, z2_t1, t1]
% ...
% [x1_t2, y1_t2, z1_t2, t2]
% ...

if n_cols >= 4
    % Has x, y, z, frame
    pos_cols = 1:3;
else
    % Has x, y, frame
    pos_cols = 1:2;
end

% Preallocate output
xyz = zeros(num_particles, 3, num_output_frames);

% Extract frames with skipping
for f_out = 1:num_output_frames
    f_in = (f_out - 1) * frame_skip + 1;  % Index into original frames
    start_idx = (f_in - 1) * num_particles + 1;
    end_idx = f_in * num_particles;

    xyz(:, 1:length(pos_cols), f_out) = plist(start_idx:end_idx, pos_cols);
end

fprintf('  Output xyz size: [%d, %d, %d]\n', size(xyz, 1), size(xyz, 2), size(xyz, 3));

end
