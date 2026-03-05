%% create_lattice_comparison_videos.m
% Creates side-by-side comparison videos of different lattice types
% (zigzag, stripe, chevron, frustrated) at the same driving frequency
%
% Shows wavefront propagation for each lattice type to compare how
% domain structure affects mechanical wave propagation

clear; close all; clc;

%% Configuration
analysis_base = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\analysis_output';
output_folder = fullfile(analysis_base, 'videos', 'lattice_comparisons');

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% Experiments to compare (must match folder names in analysis_output)
experiments = {'zigzag_topdriven', 'stripe_topdriven', 'chevron_topdriven', 'frust_top'};
exp_labels = {'Zigzag', 'Stripe', 'Chevron', 'Frustrated'};
exp_colors = {'b', 'r', 'g', 'm'};

% Find available frequencies (from first experiment that exists)
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

fprintf('=== Creating Lattice Comparison Videos ===\n');
fprintf('Found %d frequencies\n', length(available_freqs));
fprintf('Experiments: %s\n', strjoin(experiments, ', '));

%% Video settings
fps = 2;  % Slow enough to see each frequency

%% Create comparison video for each plot type
plot_types = {'bode', 'penetration', 'vacf_dos', 'msd', 'fourier', 'decomposition'};

for pti = 1:length(plot_types)
    plot_type = plot_types{pti};
    fprintf('\n--- Creating %s comparison ---\n', plot_type);

    % Collect images for each experiment across frequencies
    exp_images = cell(length(experiments), 1);
    exp_has_data = false(length(experiments), 1);

    for ei = 1:length(experiments)
        exp_path = fullfile(analysis_base, experiments{ei});
        images = {};

        for fi = 1:length(available_freqs)
            freq_str = sprintf('f%.4f', available_freqs(fi));
            img_path = fullfile(exp_path, freq_str, [plot_type '.png']);

            if exist(img_path, 'file')
                images{fi} = img_path;
            else
                images{fi} = '';  % Missing frame
            end
        end

        exp_images{ei} = images;
        exp_has_data(ei) = any(~cellfun(@isempty, images));
    end

    % Count experiments with data
    n_exp_with_data = sum(exp_has_data);
    if n_exp_with_data < 2
        fprintf('  [SKIP] Need at least 2 experiments with data\n');
        continue;
    end

    % Determine grid layout
    if n_exp_with_data <= 2
        n_rows = 1; n_cols = 2;
    elseif n_exp_with_data <= 4
        n_rows = 2; n_cols = 2;
    else
        n_rows = 2; n_cols = 3;
    end

    % Get image dimensions from first available image
    sample_img = [];
    for ei = 1:length(experiments)
        if exp_has_data(ei)
            for fi = 1:length(available_freqs)
                if ~isempty(exp_images{ei}{fi})
                    sample_img = imread(exp_images{ei}{fi});
                    break;
                end
            end
            if ~isempty(sample_img)
                break;
            end
        end
    end

    if isempty(sample_img)
        fprintf('  [SKIP] No images found\n');
        continue;
    end

    [img_h, img_w, ~] = size(sample_img);

    % Scale for reasonable video size
    max_width = 1920;
    scale = min(1, max_width / (n_cols * img_w));
    new_w = round(img_w * scale);
    new_h = round(img_h * scale);

    % Create video
    video_path = fullfile(output_folder, sprintf('lattice_comparison_%s.mp4', plot_type));
    vw = VideoWriter(video_path, 'MPEG-4');
    vw.FrameRate = fps;
    vw.Quality = 95;

    try
        open(vw);

        title_height = 80;
        label_height = 30;

        for fi = 1:length(available_freqs)
            freq = available_freqs(fi);

            % Create canvas
            canvas_h = title_height + n_rows * (new_h + label_height);
            canvas_w = n_cols * new_w;
            canvas = uint8(40 * ones(canvas_h, canvas_w, 3));  % Dark gray

            % Add title
            title_text = sprintf('%s Comparison | f = %.4f Hz [%d/%d]', ...
                upper(plot_type), freq, fi, length(available_freqs));

            try
                canvas = insertText(canvas, [20, 25], title_text, ...
                    'FontSize', 28, 'TextColor', 'white', 'BoxOpacity', 0);
            catch
                % insertText not available - continue without title
            end

            % Add each experiment's image
            plot_idx = 0;
            for ei = 1:length(experiments)
                if ~exp_has_data(ei)
                    continue;
                end

                row = floor(plot_idx / n_cols);
                col = mod(plot_idx, n_cols);
                plot_idx = plot_idx + 1;

                x_start = col * new_w + 1;
                y_start = title_height + row * (new_h + label_height) + 1;

                % Add experiment label
                try
                    label_y = y_start;
                    canvas = insertText(canvas, [x_start + 10, label_y], exp_labels{ei}, ...
                        'FontSize', 16, 'TextColor', 'cyan', 'BoxOpacity', 0);
                catch
                end

                % Add image
                img_y_start = y_start + label_height;

                if ~isempty(exp_images{ei}{fi})
                    img = imread(exp_images{ei}{fi});
                    img = imresize(img, [new_h, new_w]);
                else
                    % Gray placeholder for missing data
                    img = uint8(80 * ones(new_h, new_w, 3));
                    try
                        img = insertText(img, [new_w/2-50, new_h/2], 'No Data', ...
                            'FontSize', 20, 'TextColor', 'white', 'BoxOpacity', 0);
                    catch
                    end
                end

                canvas(img_y_start:img_y_start+new_h-1, x_start:x_start+new_w-1, :) = img;
            end

            writeVideo(vw, canvas);
        end

        close(vw);
        fprintf('  [OK] %s (%d frames)\n', plot_type, length(available_freqs));

    catch ME
        fprintf('  [ERROR] %s: %s\n', plot_type, ME.message);
        if exist('vw', 'var') && isopen(vw)
            close(vw);
        end
    end
end

%% Also create a wavefront evolution video from raw bode data
fprintf('\n--- Creating Wavefront Comparison Video ---\n');
create_wavefront_video(analysis_base, experiments, exp_labels, exp_colors, available_freqs, output_folder, fps);

fprintf('\n=== Videos saved to: %s ===\n', output_folder);

%% ==================== WAVEFRONT VIDEO FUNCTION ====================
function create_wavefront_video(analysis_base, experiments, exp_labels, exp_colors, frequencies, output_folder, fps)
    % Creates a video showing wavefront profiles for all lattice types
    % overlaid on the same axes for direct comparison

    video_path = fullfile(output_folder, 'wavefront_comparison.mp4');
    vw = VideoWriter(video_path, 'MPEG-4');
    vw.FrameRate = fps;
    vw.Quality = 95;

    try
        open(vw);

        for fi = 1:length(frequencies)
            freq = frequencies(fi);
            freq_str = sprintf('f%.4f', freq);

            % Create figure
            fig = figure('Position', [100 100 1200 500], 'Visible', 'off', 'Color', 'w');

            % Left: Amplitude comparison
            subplot(1,2,1);
            hold on;
            legend_entries = {};

            for ei = 1:length(experiments)
                data_path = fullfile(analysis_base, experiments{ei}, freq_str, 'bode_data.mat');
                if exist(data_path, 'file')
                    d = load(data_path);
                    if isfield(d, 'bode_data') && isfield(d.bode_data, 'positions')
                        % Normalize position to [0, 1]
                        pos_norm = d.bode_data.positions / max(d.bode_data.positions);
                        % Normalize amplitude to max = 1
                        amp_norm = d.bode_data.amplitudes / max(d.bode_data.amplitudes + eps);

                        plot(pos_norm, amp_norm, [exp_colors{ei} '-o'], ...
                            'LineWidth', 2, 'MarkerSize', 4);
                        legend_entries{end+1} = exp_labels{ei};
                    end
                end
            end

            xlabel('Normalized Distance from Drive');
            ylabel('Normalized Amplitude');
            title(sprintf('Amplitude Decay | f = %.4f Hz', freq));
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
                    if isfield(d, 'bode_data') && isfield(d.bode_data, 'positions')
                        pos_norm = d.bode_data.positions / max(d.bode_data.positions);
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

            % Add overall title
            sgtitle(sprintf('Lattice Comparison [%d/%d]', fi, length(frequencies)), 'FontSize', 14);

            % Capture frame
            frame = getframe(fig);
            writeVideo(vw, frame.cdata);
            close(fig);
        end

        close(vw);
        fprintf('  [OK] wavefront_comparison (%d frames)\n', length(frequencies));

    catch ME
        fprintf('  [ERROR] wavefront: %s\n', ME.message);
        if exist('vw', 'var') && isopen(vw)
            close(vw);
        end
    end
end
