function compare_domain_dispersions(base_path, output_folder)
%% COMPARE_DOMAIN_DISPERSIONS Compare dispersion relations across domain types
%
% Loads analysis results from zigzag, stripe, and random simulations
% and creates comparison plots
%
% INPUTS:
%   base_path     - Base path containing all simulation folders
%   output_folder - Where to save comparison results
%
% Author: Gerbode Lab
% Date: 2026

fprintf('============================================\n');
fprintf('  COMPARING DOMAIN DISPERSIONS\n');
fprintf('============================================\n');

%% Load all available results
domain_types = {'zigzag', 'stripe', 'random'};
batch_names = {'drivensinesims', 'stripesinesims', 'randomsinesims'};
colors = {'b', 'r', 'g'};
markers = {'o', 's', 'd'};

all_results = struct();
found_count = 0;

for i = 1:length(domain_types)
    dtype = domain_types{i};
    batch = batch_names{i};

    results_file = fullfile(base_path, batch, 'analysis', sprintf('dispersion_results_%s.mat', dtype));

    if exist(results_file, 'file')
        loaded = load(results_file);
        all_results.(dtype) = loaded.results;
        found_count = found_count + 1;
        fprintf('  Loaded: %s\n', dtype);
    else
        fprintf('  Not found: %s\n', dtype);
        all_results.(dtype) = [];
    end
end

if found_count < 2
    warning('Need at least 2 domain types for comparison');
    return;
end

%% Create comparison figure
fig = figure('Position', [100 100 1600 1000], 'Visible', 'off');

% Plot 1: Dispersion relation ω(k)
subplot(2, 3, 1);
hold on;
legend_entries = {};
for i = 1:length(domain_types)
    dtype = domain_types{i};
    if ~isempty(all_results.(dtype))
        r = all_results.(dtype);
        valid = ~isnan(r.k);
        plot(r.k(valid), r.omega(valid), [markers{i} '-'], ...
            'Color', colors{i}, 'LineWidth', 2, 'MarkerSize', 8, ...
            'MarkerFaceColor', colors{i});
        legend_entries{end+1} = upper(dtype);
    end
end
hold off;
xlabel('Wavevector k (1/px)');
ylabel('Angular frequency ω (rad/frame)');
title('Dispersion Relation ω(k)');
legend(legend_entries, 'Location', 'best');
grid on;

% Plot 2: Wavelength vs frequency
subplot(2, 3, 2);
hold on;
for i = 1:length(domain_types)
    dtype = domain_types{i};
    if ~isempty(all_results.(dtype))
        r = all_results.(dtype);
        valid = ~isnan(r.wavelengths);
        semilogy(r.frequencies(valid), r.wavelengths(valid), [markers{i} '-'], ...
            'Color', colors{i}, 'LineWidth', 2, 'MarkerSize', 8, ...
            'MarkerFaceColor', colors{i});
    end
end
hold off;
xlabel('Drive frequency f');
ylabel('Wavelength λ (px)');
title('Wavelength vs Frequency');
legend(legend_entries, 'Location', 'best');
grid on;

% Plot 3: Phase velocity
subplot(2, 3, 3);
hold on;
for i = 1:length(domain_types)
    dtype = domain_types{i};
    if ~isempty(all_results.(dtype))
        r = all_results.(dtype);
        valid = ~isnan(r.phase_velocity);
        semilogx(r.frequencies(valid), r.phase_velocity(valid), [markers{i} '-'], ...
            'Color', colors{i}, 'LineWidth', 2, 'MarkerSize', 8, ...
            'MarkerFaceColor', colors{i});
    end
end
hold off;
xlabel('Drive frequency f');
ylabel('Phase velocity v_p (px/frame)');
title('Phase Velocity');
legend(legend_entries, 'Location', 'best');
grid on;

% Plot 4: Response amplitude
subplot(2, 3, 4);
hold on;
for i = 1:length(domain_types)
    dtype = domain_types{i};
    if ~isempty(all_results.(dtype))
        r = all_results.(dtype);
        valid = ~isnan(r.amplitudes);
        loglog(r.frequencies(valid), r.amplitudes(valid), [markers{i} '-'], ...
            'Color', colors{i}, 'LineWidth', 2, 'MarkerSize', 8, ...
            'MarkerFaceColor', colors{i});
    end
end
hold off;
xlabel('Drive frequency f');
ylabel('Response amplitude (px)');
title('Amplitude Response');
legend(legend_entries, 'Location', 'best');
grid on;

% Plot 5: Decay length
subplot(2, 3, 5);
hold on;
for i = 1:length(domain_types)
    dtype = domain_types{i};
    if ~isempty(all_results.(dtype))
        r = all_results.(dtype);
        valid = ~isnan(r.decay_length) & r.decay_length > 0;
        if any(valid)
            loglog(r.frequencies(valid), r.decay_length(valid), [markers{i} '-'], ...
                'Color', colors{i}, 'LineWidth', 2, 'MarkerSize', 8, ...
                'MarkerFaceColor', colors{i});
        end
    end
end
hold off;
xlabel('Drive frequency f');
ylabel('Decay length (px)');
title('Penetration Depth');
legend(legend_entries, 'Location', 'best');
grid on;

% Plot 6: Ratio comparison (zigzag / stripe)
subplot(2, 3, 6);
if ~isempty(all_results.zigzag) && ~isempty(all_results.stripe)
    zr = all_results.zigzag;
    sr = all_results.stripe;

    % Find common frequencies
    [common_f, iz, is] = intersect(zr.frequencies, sr.frequencies);

    if ~isempty(common_f)
        ratio_wavelength = zr.wavelengths(iz) ./ sr.wavelengths(is);
        ratio_amplitude = zr.amplitudes(iz) ./ sr.amplitudes(is);

        hold on;
        semilogx(common_f, ratio_wavelength, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'DisplayName', 'λ_{zig}/λ_{stripe}');
        semilogx(common_f, ratio_amplitude, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
            'DisplayName', 'A_{zig}/A_{stripe}');
        yline(1, '--k', 'DisplayName', 'Equal');
        hold off;
        xlabel('Frequency f');
        ylabel('Ratio');
        title('Zigzag / Stripe Ratio');
        legend('Location', 'best');
        grid on;
    end
else
    text(0.5, 0.5, 'Insufficient data', 'HorizontalAlignment', 'center');
    axis off;
end

sgtitle('Domain Structure Comparison', 'FontSize', 16);

%% Save
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

saveas(fig, fullfile(output_folder, 'domain_comparison.png'));
saveas(fig, fullfile(output_folder, 'domain_comparison.fig'));
close(fig);

% Save combined results
save(fullfile(output_folder, 'domain_comparison_data.mat'), 'all_results');

fprintf('Comparison saved to: %s\n', output_folder);
fprintf('============================================\n\n');

end
