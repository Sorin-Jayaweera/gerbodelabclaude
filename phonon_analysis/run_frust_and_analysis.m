%% run_frust_and_analysis.m
% MASTER SCRIPT - Single file to run everything:
%   1. Frustrated stripe side-driven sweep (X-direction, 800x400)
%   2. Frustrated stripe top-driven sweep  (Y-direction, 400x800)
%   3. Full analysis of all domain types (chevron, stripe, random,
%      topdriven, frust_side, frust_top)
%   4. Open interactive viewer
%
% Each sub-script manages its own addpath and clear calls.
% Run this file and leave it overnight.
%
% Author: Gerbode Lab
% Date: 2026

%% STEP 1: Frustrated stripe - side driven (X direction)
fprintf('\n');
fprintf('########################################\n');
fprintf('  STEP 1: Frust stripe SIDE-driven sweep\n');
fprintf('########################################\n\n');
run_frust_stripe_side_sweep

%% STEP 2: Frustrated stripe - top driven (Y direction)
fprintf('\n');
fprintf('########################################\n');
fprintf('  STEP 2: Frust stripe TOP-driven sweep\n');
fprintf('########################################\n\n');
run_frust_stripe_top_sweep

%% STEP 3: Run all analysis (all 6 domain types)
fprintf('\n');
fprintf('########################################\n');
fprintf('  STEP 3: Run all analysis\n');
fprintf('########################################\n\n');
run_all_analysis

%% STEP 4: Open interactive viewer
fprintf('\n');
fprintf('########################################\n');
fprintf('  STEP 4: Opening interactive viewer\n');
fprintf('########################################\n\n');
addpath(genpath('Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\phonon_analysis'));
interactive_simulation_viewer
