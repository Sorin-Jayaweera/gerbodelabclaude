%% runfile.m
% Simple launcher for running all simulations sequentially
% Use this instead of run_all_simulations_parallel to avoid
% MATLAB transparency violations in parfor

% Pull latest code
!git pull origin main

% Navigate to phonon_analysis
cd(fileparts(mfilename('fullpath')));

% Run sequential version (no parallel pool needed)
run_all_simulations
