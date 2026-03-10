function paths = get_paths()
% GET_PATHS Returns all base paths for the analysis scripts
% Centralizes path configuration for easy switching between systems
%
% Usage:
%   paths = get_paths();
%   addpath(genpath(paths.colloid_work));
%   sim_folder = fullfile(paths.sims, 'drivensinesims');

    % Detect OS and set root accordingly
    if ispc
        % Windows paths
        root = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude';
        paths.colloid_work = 'Z:\Colloid Cru\Colloid Work Folder';
        paths.simulations = 'Z:\Colloid Cru\Simulations';
    else
        % Linux paths
        root = '/home/sorin/AllSaves/code/gerbodelabclaude';
        paths.colloid_work = fullfile(root, 'Colloid Work Folder');
        paths.simulations = fullfile(root, 'TDsim');
    end

    % Common paths relative to root
    paths.root = root;
    paths.sims = fullfile(root, 'sims');
    paths.phonon_analysis = fullfile(root, 'phonon_analysis');
    paths.analysis_output = fullfile(root, 'analysis_output');
    paths.interesting_videos = fullfile(root, 'interesting videos');
    paths.bdsims = fullfile(root, 'BDsim');
end
