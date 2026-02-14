function generate_summary_figures(base_path, output_folder)
%% GENERATE_SUMMARY_FIGURES Create publication-quality summary figures
%
% Combines all analysis results into comprehensive summary plots
%
% INPUTS:
%   base_path     - Base path containing all simulation folders
%   output_folder - Where to save summary figures
%
% Author: Gerbode Lab
% Date: 2026

fprintf('============================================\n');
fprintf('  GENERATING SUMMARY FIGURES\n');
fprintf('============================================\n');

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% Load all available results
domains = {'zigzag', 'stripe', 'random'};
batches = {'drivensinesims', 'stripesinesims', 'randomsinesims'};

disp_results = struct();
freq_results = struct();

for i = 1:length(domains)
    d = domains{i};
    b = batches{i};

    % Dispersion
    disp_file = fullfile(base_path, b, 'analysis', sprintf('dispersion_results_%s.mat', d));
    if exist(disp_file, 'file')
        loaded = load(disp_file);
        disp_results.(d) = loaded.results;
    end

    % Frequency response
    freq_file = fullfile(base_path, b, 'analysis', sprintf('freq_response_%s.mat', d));
    if exist(freq_file, 'file')
        loaded = load(freq_file);
        freq_results.(d) = loaded.results;
    end
end

% Top-driven
td_disp_file = fullfile(base_path, 'topdrivensims', 'analysis', 'dispersion_results_topdriven.mat');
if exist(td_disp_file, 'file')
    loaded = load(td_disp_file);
    disp_results.topdriven = loaded.results;
end

% Control noise
ctrl_file = fullfile(base_path, 'controlsims', 'analysis', 'zigzag_noise_results.mat');
if exist(ctrl_file, 'file')
    loaded = load(ctrl_file);
    noise_results = loaded.results;
else
    noise_results = [];
end

%% Figure 1: Main Results Overview (2x3 grid)
fig1 = figure('Position', [50 50 1800 1000], 'Visible', 'off');

colors = struct('zigzag', [0 0.4470 0.7410], ...
                'stripe', [0.8500 0.3250 0.0980], ...
                'random', [0.4660 0.6740 0.1880], ...
                'topdriven', [0.4940 0.1840 0.5560]);

% 1a: Dispersion relation
subplot(2, 3, 1);
hold on;
legend_str = {};
for d = domains
    dd = d{1};
    if isfield(disp_results, dd)
        r = disp_results.(dd);
        valid = ~isnan(r.k);
        plot(r.k(valid), r.omega(valid), 'o-', 'Color', colors.(dd), ...
            'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', colors.(dd));
        legend_str{end+1} = upper(dd);
    end
end
hold off;
xlabel('Wavevector k (1/px)', 'FontSize', 11);
ylabel('Angular frequency ω (rad/frame)', 'FontSize', 11);
title('(a) Dispersion Relation', 'FontSize', 12, 'FontWeight', 'bold');
legend(legend_str, 'Location', 'northwest');
grid on;

% 1b: Phase velocity
subplot(2, 3, 2);
hold on;
for d = domains
    dd = d{1};
    if isfield(disp_results, dd)
        r = disp_results.(dd);
        valid = ~isnan(r.phase_velocity) & r.phase_velocity > 0;
        semilogx(r.frequencies(valid), r.phase_velocity(valid), 's-', ...
            'Color', colors.(dd), 'LineWidth', 2, 'MarkerSize', 6, ...
            'MarkerFaceColor', colors.(dd));
    end
end
hold off;
xlabel('Frequency f', 'FontSize', 11);
ylabel('Phase velocity v_p (px/frame)', 'FontSize', 11);
title('(b) Phase Velocity', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

% 1c: Wavelength
subplot(2, 3, 3);
hold on;
for d = domains
    dd = d{1};
    if isfield(disp_results, dd)
        r = disp_results.(dd);
        valid = ~isnan(r.wavelengths);
        loglog(r.frequencies(valid), r.wavelengths(valid), 'd-', ...
            'Color', colors.(dd), 'LineWidth', 2, 'MarkerSize', 6, ...
            'MarkerFaceColor', colors.(dd));
    end
end
hold off;
xlabel('Frequency f', 'FontSize', 11);
ylabel('Wavelength λ (px)', 'FontSize', 11);
title('(c) Wavelength', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

% 1d: Amplitude (transfer function magnitude)
subplot(2, 3, 4);
hold on;
for d = domains
    dd = d{1};
    if isfield(disp_results, dd)
        r = disp_results.(dd);
        valid = ~isnan(r.amplitudes);
        loglog(r.frequencies(valid), r.amplitudes(valid), '^-', ...
            'Color', colors.(dd), 'LineWidth', 2, 'MarkerSize', 6, ...
            'MarkerFaceColor', colors.(dd));
    end
end
% Add noise floor if available
if ~isempty(noise_results)
    yline(noise_results.rms_x, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5, ...
        'DisplayName', 'Noise floor');
end
hold off;
xlabel('Frequency f', 'FontSize', 11);
ylabel('Response amplitude (px)', 'FontSize', 11);
title('(d) Amplitude Response', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

% 1e: Decay length / penetration depth
subplot(2, 3, 5);
hold on;
for d = domains
    dd = d{1};
    if isfield(disp_results, dd)
        r = disp_results.(dd);
        valid = ~isnan(r.decay_length) & r.decay_length > 0;
        if any(valid)
            loglog(r.frequencies(valid), r.decay_length(valid), 'v-', ...
                'Color', colors.(dd), 'LineWidth', 2, 'MarkerSize', 6, ...
                'MarkerFaceColor', colors.(dd));
        end
    end
end
hold off;
xlabel('Frequency f', 'FontSize', 11);
ylabel('Decay length (px)', 'FontSize', 11);
title('(e) Penetration Depth', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

% 1f: Anisotropy (X vs Y for zigzag)
subplot(2, 3, 6);
if isfield(disp_results, 'zigzag') && isfield(disp_results, 'topdriven')
    xr = disp_results.zigzag;
    yr = disp_results.topdriven;
    [common_f, ix, iy] = intersect(xr.frequencies, yr.frequencies);

    if ~isempty(common_f)
        ratio = xr.phase_velocity(ix) ./ yr.phase_velocity(iy);
        valid = ~isnan(ratio);

        semilogx(common_f(valid), ratio(valid), 'ko-', 'LineWidth', 2, ...
            'MarkerSize', 8, 'MarkerFaceColor', 'k');
        hold on;
        yline(1, '--r', 'LineWidth', 1.5);
        hold off;
        xlabel('Frequency f', 'FontSize', 11);
        ylabel('v_x / v_y', 'FontSize', 11);
        title('(f) Directional Anisotropy', 'FontSize', 12, 'FontWeight', 'bold');
        grid on;
    else
        text(0.5, 0.5, 'No matching frequencies', 'HorizontalAlignment', 'center');
        axis off;
    end
else
    text(0.5, 0.5, 'X/Y comparison not available', 'HorizontalAlignment', 'center');
    axis off;
end

sgtitle('Phonon Dispersion in Colloidal Monolayers', 'FontSize', 16, 'FontWeight', 'bold');

saveas(fig1, fullfile(output_folder, 'summary_main.png'));
saveas(fig1, fullfile(output_folder, 'summary_main.fig'));
close(fig1);

%% Figure 2: Domain comparison ratios
fig2 = figure('Position', [100 100 1200 500], 'Visible', 'off');

if isfield(disp_results, 'zigzag') && isfield(disp_results, 'stripe')
    zr = disp_results.zigzag;
    sr = disp_results.stripe;
    [common_f, iz, is] = intersect(zr.frequencies, sr.frequencies);

    if ~isempty(common_f)
        subplot(1, 3, 1);
        ratio = zr.wavelengths(iz) ./ sr.wavelengths(is);
        semilogx(common_f, ratio, 'bo-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'MarkerFaceColor', 'b');
        hold on; yline(1, '--k'); hold off;
        xlabel('Frequency f');
        ylabel('λ_{zigzag} / λ_{stripe}');
        title('Wavelength Ratio');
        grid on;

        subplot(1, 3, 2);
        ratio = zr.phase_velocity(iz) ./ sr.phase_velocity(is);
        semilogx(common_f, ratio, 'rs-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'MarkerFaceColor', 'r');
        hold on; yline(1, '--k'); hold off;
        xlabel('Frequency f');
        ylabel('v_{zigzag} / v_{stripe}');
        title('Phase Velocity Ratio');
        grid on;

        subplot(1, 3, 3);
        ratio = zr.amplitudes(iz) ./ sr.amplitudes(is);
        semilogx(common_f, ratio, 'gd-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'MarkerFaceColor', 'g');
        hold on; yline(1, '--k'); hold off;
        xlabel('Frequency f');
        ylabel('A_{zigzag} / A_{stripe}');
        title('Amplitude Ratio');
        grid on;
    end
end

sgtitle('Zigzag vs Stripe Domain Comparison', 'FontSize', 14, 'FontWeight', 'bold');

saveas(fig2, fullfile(output_folder, 'summary_ratios.png'));
saveas(fig2, fullfile(output_folder, 'summary_ratios.fig'));
close(fig2);

%% Figure 3: Parameter table (as an image)
fig3 = figure('Position', [100 100 800 400], 'Visible', 'off');
axis off;

% Create summary text
summary_text = {
    'PHONON ANALYSIS SUMMARY';
    '========================';
    '';
    sprintf('Generated: %s', datestr(now));
    '';
};

for d = domains
    dd = d{1};
    if isfield(disp_results, dd)
        r = disp_results.(dd);
        n_freqs = sum(~isnan(r.wavelengths));
        avg_v = nanmean(r.phase_velocity);
        summary_text{end+1} = sprintf('%s: %d frequencies, avg v_p = %.2f px/frame', ...
            upper(dd), n_freqs, avg_v);
    end
end

text(0.05, 0.95, summary_text, 'FontName', 'FixedWidth', 'FontSize', 10, ...
    'VerticalAlignment', 'top', 'HorizontalAlignment', 'left');

saveas(fig3, fullfile(output_folder, 'summary_text.png'));
close(fig3);

fprintf('Summary figures saved to: %s\n', output_folder);
fprintf('============================================\n\n');

end
