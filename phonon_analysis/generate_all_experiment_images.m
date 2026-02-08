%% Generate Images for All Experiments
% Runs generate_images_from_plist on all completed simulations
% Creates video-ready image sequences for visual inspection

clear; clc;

%% Add paths
addpath(genpath('Z:\Colloid Cru\Colloid Work Folder'));
addpath(genpath('Z:\Colloid Cru\Simulations'));

%% Configuration
batch_folder = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\drivensinesims';
simulations_folder = fullfile(batch_folder, 'simulations');

% Check folder structure
if exist(simulations_folder, 'dir')
    sim_base_path = simulations_folder;
else
    sim_base_path = batch_folder;
end

% Image generation options
options = struct();
options.frame_skip = 1;       % Save every frame (set to 2 or 5 to reduce count)
options.show_progress = true;
options.particle_size = 10;

%% Find all completed simulations
sim_dirs = dir(fullfile(sim_base_path, 'sinusoidal_f*_a*.0'));
completed = {};

for i = 1:length(sim_dirs)
    folder_path = fullfile(sim_base_path, sim_dirs(i).name);
    plist_file = fullfile(folder_path, 'plist.mat');
    if exist(plist_file, 'file')
        completed{end+1} = folder_path;
    end
end

fprintf('Found %d completed simulations\n', length(completed));
fprintf('==============================================\n\n');

%% Generate images for each simulation
total_start = tic;

for i = 1:length(completed)
    sim_folder = completed{i};
    [~, sim_name] = fileparts(sim_folder);

    fprintf('\n[%d/%d] Processing %s\n', i, length(completed), sim_name);
    fprintf('----------------------------------------------\n');

    % Output folder inside the simulation folder
    output_folder = fullfile(sim_folder, 'images');

    % Check if images already exist
    if exist(output_folder, 'dir')
        existing_images = dir(fullfile(output_folder, 'frame_*.png'));
        if length(existing_images) > 1000
            fprintf('  Images already exist (%d files), skipping.\n', length(existing_images));
            fprintf('  Delete %s to regenerate.\n', output_folder);
            continue;
        end
    end

    % Generate images
    try
        generate_images_from_plist(sim_folder, output_folder, options);
    catch ME
        fprintf('  ERROR: %s\n', ME.message);
        continue;
    end
end

total_elapsed = toc(total_start);
fprintf('\n==============================================\n');
fprintf('All done! Total time: %.1f minutes\n', total_elapsed / 60);
fprintf('==============================================\n');

%% Print summary
fprintf('\nImage folders created:\n');
for i = 1:length(completed)
    [~, sim_name] = fileparts(completed{i});
    img_folder = fullfile(completed{i}, 'images');
    if exist(img_folder, 'dir')
        n_images = length(dir(fullfile(img_folder, 'frame_*.png')));
        fprintf('  %s: %d images\n', sim_name, n_images);
    end
end

fprintf('\nTo view as video, open folder in Windows Explorer and use:\n');
fprintf('  - Windows Photos app (slideshow)\n');
fprintf('  - IrfanView (fast slideshow with arrow keys)\n');
fprintf('  - Or use MATLAB: implay(''folder_path'')\n');
