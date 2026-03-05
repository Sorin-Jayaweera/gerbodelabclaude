%% convert_plist_to_xyz.m
% Converts plist.mat files to xyz_data.mat format for use with
% interactive_simulation_viewer and create_drive_comparison_videos
%
% plist format: struct array where plist(i).pos = [N_particles x 3]
% xyz_data format: xyz = [N_particles x 3 x N_frames]

clear; close all; clc;

%% Configuration
base_path = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\sims';

% All simulation types and their folder structures
sim_configs = {
    struct('name', 'chevron_side', 'folder', 'drivensinesims', ...
           'fmt', 'sinusoidal_f%.4f_a2.0');
    struct('name', 'stripe_side', 'folder', 'stripesinesims', ...
           'fmt', 'sinusoidal_f%.4f_a2.0_stripes');
    struct('name', 'frust_side', 'folder', 'frustsinesims', ...
           'fmt', 'frust_f%.4f_a2.0');
    struct('name', 'chevron_top', 'folder', 'topdrivensims', ...
           'fmt', 'topdriven_f%.4f_a2.0');
    struct('name', 'frust_top', 'folder', 'frusttopsims', ...
           'fmt', 'frusttop_f%.4f_a2.0');
};

% Frequencies to check
frequencies = [0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, ...
               0.001,  0.0012, 0.0015, 0.0018, ...
               0.002,  0.0025, 0.003,  0.004,  0.005, ...
               0.007,  0.01,   0.02,   0.05,   0.10];

fprintf('=== Converting plist.mat to xyz_data.mat ===\n');
fprintf('Base path: %s\n\n', base_path);

total_converted = 0;
total_skipped = 0;
total_missing = 0;

for ci = 1:length(sim_configs)
    cfg = sim_configs{ci};
    fprintf('Processing %s (%s)\n', cfg.name, cfg.folder);

    for fi = 1:length(frequencies)
        freq = frequencies(fi);
        sim_name = sprintf(cfg.fmt, freq);

        % Check both direct folder and simulations subfolder
        paths_to_check = {
            fullfile(base_path, cfg.folder, sim_name);
            fullfile(base_path, cfg.folder, 'simulations', sim_name);
        };

        plist_found = false;
        for pi = 1:length(paths_to_check)
            sim_path = paths_to_check{pi};
            plist_path = fullfile(sim_path, 'plist.mat');

            if exist(plist_path, 'file')
                plist_found = true;
                xyz_path = fullfile(sim_path, 'xyz_data.mat');

                % Skip if xyz_data.mat already exists
                if exist(xyz_path, 'file')
                    total_skipped = total_skipped + 1;
                    continue;
                end

                try
                    % Load plist
                    loaded = load(plist_path);
                    if isfield(loaded, 'plist')
                        plist = loaded.plist;
                    else
                        fn = fieldnames(loaded);
                        plist = loaded.(fn{1});
                    end

                    % Handle different plist formats
                    if isstruct(plist) && isfield(plist, 'pos')
                        % Format 1: struct array with .pos field
                        N_frames = length(plist);
                        if N_frames == 0
                            continue;
                        end
                        N_particles = size(plist(1).pos, 1);
                        xyz = zeros(N_particles, 3, N_frames);
                        for t = 1:N_frames
                            xyz(:,:,t) = plist(t).pos;
                        end

                    elseif iscell(plist)
                        % Format 2: cell array of position matrices
                        N_frames = length(plist);
                        if N_frames == 0
                            continue;
                        end
                        N_particles = size(plist{1}, 1);
                        xyz = zeros(N_particles, 3, N_frames);
                        for t = 1:N_frames
                            xyz(:,:,t) = plist{t};
                        end

                    elseif isnumeric(plist) && size(plist, 2) >= 4
                        % Format 3: matrix [x, y, z, frame_id, ...]
                        frame_col = plist(:, 4);
                        all_frame_ids = unique(frame_col);
                        N_frames = length(all_frame_ids);
                        if N_frames == 0
                            continue;
                        end

                        % Count particles in first frame
                        first_frame_mask = (frame_col == all_frame_ids(1));
                        N_particles = sum(first_frame_mask);
                        xyz = zeros(N_particles, 3, N_frames);

                        for t = 1:N_frames
                            mask = (frame_col == all_frame_ids(t));
                            frame_data = plist(mask, 1:3);
                            n_use = min(size(frame_data, 1), N_particles);
                            xyz(1:n_use, :, t) = frame_data(1:n_use, :);
                        end

                    elseif isnumeric(plist) && ndims(plist) == 3
                        % Format 4: already xyz format [N x 3 x frames]
                        xyz = plist;
                        N_particles = size(xyz, 1);
                        N_frames = size(xyz, 3);

                    else
                        error('Unknown plist format: class=%s, size=%s', ...
                            class(plist), mat2str(size(plist)));
                    end

                    % Save xyz_data.mat
                    save(xyz_path, 'xyz', '-v7.3');
                    total_converted = total_converted + 1;
                    fprintf('  f=%.4f: converted (%d particles, %d frames)\n', ...
                        freq, N_particles, N_frames);

                catch ME
                    fprintf('  f=%.4f: ERROR - %s\n', freq, ME.message);
                end
                break;  % Found plist, don't check other paths
            end
        end

        if ~plist_found
            total_missing = total_missing + 1;
        end
    end
end

fprintf('\n=== Conversion Complete ===\n');
fprintf('Converted: %d\n', total_converted);
fprintf('Skipped (already exists): %d\n', total_skipped);
fprintf('Missing plist.mat: %d\n', total_missing);
