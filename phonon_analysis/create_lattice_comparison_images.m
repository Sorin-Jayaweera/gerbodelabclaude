%% create_lattice_comparison_images.m
% Creates side-by-side comparison IMAGES (not videos) of different lattice types
% at each driving frequency, for viewing in analysis_viewer
%
% Saves PNG images in analysis_output/comparisons/ folder structure

clear; close all; clc;

%% Configuration
analysis_base = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\analysis_output';
output_folder = fullfile(analysis_base, 'comparisons');

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% Experiments to compare
experiments = {'chevron_side', 'stripe_side', 'frust_side', 'chevron_top', 'frust_top'};
exp_labels = {'Chevron (side)', 'Stripe (side)', 'Frust (side)', 'Chevron (top)', 'Frust (top)'};
exp_colors = {'b', 'r', 'g', 'c', 'm'};

% Find available frequencies
available_freqs = [];
for ei = 1:length(experiments)
    exp_path = fullfile(analysis_base, experiments{ei});
    if exist(exp_path, 'dir')
        freq_folders = dir(exp_path);
        freq_folders = freq_folders([freq_folders.isdir] & startsWith({freq_folders.name}, 'f'));
        for fi = 1:length(freq_folders)
            freq_str = freq_folders(fi).name;
            freq_val = str2double(strrep(freq_str, 'f', ''));
            if ~isnan(freq_val) && ~ismember(freq_val, available_freqs)
                available_freqs(end+1) = freq_val;
            end
        end
        break;
    end
end
available_freqs = sort(available_freqs);

if isempty(available_freqs)
    error('No frequency folders found in %s', analysis_base);
end

fprintf('=== Creating Lattice Comparison Images ===\n');
fprintf('Found %d frequencies\n', length(available_freqs));

%% Plot types to compare
plot_types = {'bode', 'penetration', 'fourier', 'decomposition', 'resonance'};

for pti = 1:length(plot_types)
    plot_type = plot_types{pti};
    fprintf('\n--- %s comparisons ---\n', plot_type);

    % Create output subfolder
    type_folder = fullfile(output_folder, [plot_type '_comparison']);
    if ~exist(type_folder, 'dir')
        mkdir(type_folder);
    end

    for fi = 1:length(available_freqs)
        freq = available_freqs(fi);
        freq_str = sprintf('f%.4f', freq);

        % Collect images that exist for this frequency
        images = {};
        labels = {};

        for ei = 1:length(experiments)
            img_path = fullfile(analysis_base, experiments{ei}, freq_str, [plot_type '.png']);
            if exist(img_path, 'file')
                images{end+1} = imread(img_path);
                labels{end+1} = exp_labels{ei};
            end
        end

        if length(images) < 2
            continue;  % Need at least 2 for comparison
        end

        % Create tiled comparison figure
        n_imgs = length(images);
        if n_imgs <= 2
            n_rows = 1; n_cols = 2;
        elseif n_imgs <= 4
            n_rows = 2; n_cols = 2;
        else
            n_rows = 2; n_cols = 3;
        end

        fig = figure('Position', [50 50 400*n_cols 350*n_rows], 'Visible', 'off', 'Color', 'w');

        for ii = 1:n_imgs
            subplot(n_rows, n_cols, ii);
            imshow(images{ii});
            title(labels{ii}, 'FontSize', 12, 'FontWeight', 'bold');
        end

        sgtitle(sprintf('%s Comparison | f = %.4f', upper(plot_type), freq), ...
            'FontSize', 14, 'FontWeight', 'bold');

        % Save
        out_path = fullfile(type_folder, sprintf('%s_comparison_%s.png', plot_type, freq_str));
        saveas(fig, out_path);
        close(fig);
    end
    fprintf('  Saved %d images\n', length(available_freqs));
end

%% Create wavefront overlay comparisons (from bode_data.mat)
fprintf('\n--- Wavefront overlay comparisons ---\n');
wavefront_folder = fullfile(output_folder, 'wavefront_overlay');
if ~exist(wavefront_folder, 'dir')
    mkdir(wavefront_folder);
end

for fi = 1:length(available_freqs)
    freq = available_freqs(fi);
    freq_str = sprintf('f%.4f', freq);

    fig = figure('Position', [100 100 1200 500], 'Visible', 'off', 'Color', 'w');

    % Left: Amplitude comparison
    subplot(1,2,1);
    hold on;
    legend_entries = {};

    for ei = 1:length(experiments)
        data_path = fullfile(analysis_base, experiments{ei}, freq_str, 'bode_data.mat');
        if exist(data_path, 'file')
            d = load(data_path);
            if isfield(d, 'bode_data') && isfield(d.bode_data, 'ctrs')
                pos_norm = d.bode_data.ctrs / max(d.bode_data.ctrs);
                amp_norm = d.bode_data.amplitudes / max(d.bode_data.amplitudes + eps);

                plot(pos_norm, amp_norm, [exp_colors{ei} '-o'], ...
                    'LineWidth', 2, 'MarkerSize', 4);
                legend_entries{end+1} = exp_labels{ei};
            end
        end
    end

    xlabel('Normalized Distance from Drive');
    ylabel('Normalized Amplitude');
    title(sprintf('Amplitude Decay | f = %.4f', freq));
    if ~isempty(legend_entries)
        legend(legend_entries, 'Location', 'northeast');
    end
    grid on;
    xlim([0 1]);
    ylim([0 1.1]);

    % Right: Phase comparison
    subplot(1,2,2);
    hold on;
    legend_entries = {};

    for ei = 1:length(experiments)
        data_path = fullfile(analysis_base, experiments{ei}, freq_str, 'bode_data.mat');
        if exist(data_path, 'file')
            d = load(data_path);
            if isfield(d, 'bode_data') && isfield(d.bode_data, 'ctrs')
                pos_norm = d.bode_data.ctrs / max(d.bode_data.ctrs);
                phase_deg = unwrap(d.bode_data.phases) * 180/pi;

                plot(pos_norm, phase_deg, [exp_colors{ei} '-o'], ...
                    'LineWidth', 2, 'MarkerSize', 4);
                legend_entries{end+1} = exp_labels{ei};
            end
        end
    end

    xlabel('Normalized Distance from Drive');
    ylabel('Phase (degrees)');
    title('Phase Accumulation');
    if ~isempty(legend_entries)
        legend(legend_entries, 'Location', 'southwest');
    end
    grid on;
    xlim([0 1]);

    sgtitle(sprintf('Wavefront Comparison | f = %.4f', freq), 'FontSize', 14, 'FontWeight', 'bold');

    out_path = fullfile(wavefront_folder, sprintf('wavefront_overlay_%s.png', freq_str));
    saveas(fig, out_path);
    close(fig);
end
fprintf('  Saved %d wavefront overlays\n', length(available_freqs));

%% Create side vs top driven comparisons
fprintf('\n--- Side vs Top drive comparisons ---\n');
drive_folder = fullfile(output_folder, 'side_vs_top');
if ~exist(drive_folder, 'dir')
    mkdir(drive_folder);
end

% Pairs: chevron side vs top, frust side vs top
pairs = {
    {'chevron_side', 'chevron_top', 'Chevron'};
    {'frust_side', 'frust_top', 'Frustrated'};
};

for pi = 1:length(pairs)
    pair = pairs{pi};
    side_exp = pair{1};
    top_exp = pair{2};
    pair_name = pair{3};

    pair_folder = fullfile(drive_folder, lower(pair_name));
    if ~exist(pair_folder, 'dir')
        mkdir(pair_folder);
    end

    for fi = 1:length(available_freqs)
        freq = available_freqs(fi);
        freq_str = sprintf('f%.4f', freq);

        side_bode = fullfile(analysis_base, side_exp, freq_str, 'bode_data.mat');
        top_bode = fullfile(analysis_base, top_exp, freq_str, 'bode_data.mat');

        has_side = exist(side_bode, 'file');
        has_top = exist(top_bode, 'file');

        if ~has_side && ~has_top
            continue;
        end

        fig = figure('Position', [100 100 1000 400], 'Visible', 'off', 'Color', 'w');

        % Amplitude comparison
        subplot(1,2,1);
        hold on;
        legend_entries = {};

        if has_side
            d = load(side_bode);
            if isfield(d, 'bode_data')
                pos_norm = d.bode_data.ctrs / max(d.bode_data.ctrs);
                amp_norm = d.bode_data.amplitudes / max(d.bode_data.amplitudes + eps);
                plot(pos_norm, amp_norm, 'c-o', 'LineWidth', 2, 'MarkerSize', 4);
                legend_entries{end+1} = 'Side-driven';
            end
        end

        if has_top
            d = load(top_bode);
            if isfield(d, 'bode_data')
                pos_norm = d.bode_data.ctrs / max(d.bode_data.ctrs);
                amp_norm = d.bode_data.amplitudes / max(d.bode_data.amplitudes + eps);
                plot(pos_norm, amp_norm, 'r-o', 'LineWidth', 2, 'MarkerSize', 4);
                legend_entries{end+1} = 'Top-driven';
            end
        end

        xlabel('Normalized Distance from Drive');
        ylabel('Normalized Amplitude');
        title(sprintf('%s: Amplitude | f = %.4f', pair_name, freq));
        legend(legend_entries, 'Location', 'northeast');
        grid on;
        xlim([0 1]);
        ylim([0 1.1]);

        % Phase comparison
        subplot(1,2,2);
        hold on;
        legend_entries = {};

        if has_side
            d = load(side_bode);
            if isfield(d, 'bode_data')
                pos_norm = d.bode_data.ctrs / max(d.bode_data.ctrs);
                phase_deg = unwrap(d.bode_data.phases) * 180/pi;
                plot(pos_norm, phase_deg, 'c-o', 'LineWidth', 2, 'MarkerSize', 4);
                legend_entries{end+1} = 'Side-driven';
            end
        end

        if has_top
            d = load(top_bode);
            if isfield(d, 'bode_data')
                pos_norm = d.bode_data.ctrs / max(d.bode_data.ctrs);
                phase_deg = unwrap(d.bode_data.phases) * 180/pi;
                plot(pos_norm, phase_deg, 'r-o', 'LineWidth', 2, 'MarkerSize', 4);
                legend_entries{end+1} = 'Top-driven';
            end
        end

        xlabel('Normalized Distance from Drive');
        ylabel('Phase (degrees)');
        title('Phase Accumulation');
        legend(legend_entries, 'Location', 'southwest');
        grid on;
        xlim([0 1]);

        out_path = fullfile(pair_folder, sprintf('side_vs_top_%s.png', freq_str));
        saveas(fig, out_path);
        close(fig);
    end
    fprintf('  %s: %d images\n', pair_name, length(available_freqs));
end

fprintf('\n=== Comparison images saved to: %s ===\n', output_folder);
fprintf('Open analysis_viewer and navigate to the "comparisons" folder to view.\n');
