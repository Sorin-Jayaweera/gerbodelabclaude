%% regenerate_figures.m
% Regenerates all figures from existing .mat data files
% Much faster than re-running full analysis - just loads saved data and plots
%
% Use this after pulling code updates that change visualization
% without needing to recompute the underlying analysis

clear; close all; clc;

%% Configuration
output_base = 'Z:\Colloid Cru\Spring 2026\sorins files\gerbodelabclaude\analysis_output';

opts = struct();
opts.save_fig = true;
opts.save_png = true;

%% Find all experiment folders
exp_folders = dir(output_base);
exp_folders = exp_folders([exp_folders.isdir] & ~startsWith({exp_folders.name}, '.'));
exp_folders = exp_folders(~strcmp({exp_folders.name}, 'documentation'));
exp_folders = exp_folders(~strcmp({exp_folders.name}, 'videos'));

fprintf('=== Regenerating Figures from Saved Data ===\n');
fprintf('Output: %s\n\n', output_base);

total_regenerated = 0;

for ei = 1:length(exp_folders)
    exp_name = exp_folders(ei).name;
    exp_path = fullfile(output_base, exp_name);

    fprintf('Experiment: %s\n', upper(exp_name));

    % Find frequency folders
    freq_folders = dir(exp_path);
    freq_folders = freq_folders([freq_folders.isdir] & startsWith({freq_folders.name}, 'f'));

    for fi = 1:length(freq_folders)
        freq_name = freq_folders(fi).name;
        freq_path = fullfile(exp_path, freq_name);

        % Find all *_data.mat files
        mat_files = dir(fullfile(freq_path, '*_data.mat'));

        for mi = 1:length(mat_files)
            mat_name = mat_files(mi).name;
            mat_path = fullfile(freq_path, mat_name);

            % Determine analysis type from filename
            analysis_type = strrep(mat_name, '_data.mat', '');

            try
                d = load(mat_path);

                % Regenerate figure based on type
                switch analysis_type
                    case 'bode'
                        fig = regenerate_bode(d, exp_name, freq_name);
                    case 'fourier'
                        fig = regenerate_fourier(d, exp_name, freq_name);
                    case 'penetration'
                        fig = regenerate_penetration(d, exp_name, freq_name);
                    case 'resonance'
                        fig = regenerate_resonance(d, exp_name, freq_name);
                    case 'anisotropy'
                        fig = regenerate_anisotropy(d, exp_name, freq_name);
                    case 'momentum'
                        fig = regenerate_momentum(d, exp_name, freq_name);
                    case 'decomposition'
                        fig = regenerate_decomposition(d, exp_name, freq_name);
                    case 'vacf'
                        fig = regenerate_vacf(d, exp_name, freq_name);
                    case 'msd'
                        fig = regenerate_msd(d, exp_name, freq_name);
                    case 'correlation'
                        fig = regenerate_correlation(d, exp_name, freq_name);
                    otherwise
                        continue;
                end

                % Save figure
                if ~isempty(fig) && isvalid(fig)
                    save_plot(fig, freq_path, analysis_type, opts);
                    close(fig);
                    total_regenerated = total_regenerated + 1;
                end

            catch ME
                fprintf('  [ERROR] %s/%s: %s\n', freq_name, analysis_type, ME.message);
            end
        end
    end
    fprintf('  Done.\n');
end

fprintf('\n=== Regenerated %d figures ===\n', total_regenerated);

%% ==================== REGENERATION FUNCTIONS ====================

function fig = regenerate_bode(d, exp_name, freq_name)
    if ~isfield(d, 'bode_data'), fig = []; return; end
    bd = d.bode_data;

    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    plot(bd.positions, bd.amplitudes, 'b-o', 'LineWidth', 1.5);
    xlabel('Distance from Drive (px)');
    ylabel('Amplitude');
    title(sprintf('Bode Amplitude - %s %s', exp_name, freq_name));
    grid on;

    subplot(1,2,2);
    plot(bd.positions, unwrap(bd.phases) * 180/pi, 'r-o', 'LineWidth', 1.5);
    xlabel('Distance from Drive (px)');
    ylabel('Phase (degrees)');
    title('Bode Phase');
    grid on;
end

function fig = regenerate_fourier(d, exp_name, freq_name)
    if ~isfield(d, 'fourier_data'), fig = []; return; end
    fd = d.fourier_data;

    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    semilogy(fd.frequencies, fd.power_spectrum, 'b-', 'LineWidth', 1);
    xlabel('Frequency');
    ylabel('Power');
    title(sprintf('Power Spectrum - %s %s', exp_name, freq_name));
    grid on;
    if isfield(fd, 'drive_freq')
        hold on;
        xline(fd.drive_freq, 'r--', 'LineWidth', 1.5);
    end

    subplot(1,2,2);
    if isfield(fd, 'participation')
        plot(fd.frequencies, fd.participation, 'g-', 'LineWidth', 1);
        xlabel('Frequency');
        ylabel('Participation Ratio');
        title('Mode Localization');
        ylim([0 1]);
        grid on;
    end
end

function fig = regenerate_penetration(d, exp_name, freq_name)
    if ~isfield(d, 'pen_data'), fig = []; return; end
    pd = d.pen_data;

    fig = figure('Position', [100 100 600 400], 'Visible', 'off');

    semilogy(pd.positions, pd.amplitudes, 'bo', 'MarkerSize', 6);
    hold on;
    if isfield(pd, 'fit_amplitudes')
        semilogy(pd.positions, pd.fit_amplitudes, 'r-', 'LineWidth', 2);
    end
    xlabel('Distance from Drive (px)');
    ylabel('Amplitude');
    title(sprintf('Penetration - %s %s (δ=%.1f px)', exp_name, freq_name, pd.penetration_depth));
    legend('Data', sprintf('Fit: δ=%.1f', pd.penetration_depth), 'Location', 'northeast');
    grid on;
end

function fig = regenerate_resonance(d, exp_name, freq_name)
    if ~isfield(d, 'res_data'), fig = []; return; end
    rd = d.res_data;

    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    if isfield(rd, 'frequencies') && isfield(rd, 'power')
        semilogy(rd.frequencies, rd.power, 'b-', 'LineWidth', 1);
        hold on;
        if ~isempty(rd.peak_freqs)
            for i = 1:min(5, length(rd.peak_freqs))
                xline(rd.peak_freqs(i), 'r--', 'LineWidth', 1);
            end
        end
    end
    xlabel('Frequency');
    ylabel('Power');
    title(sprintf('Resonance - %s %s', exp_name, freq_name));
    grid on;

    subplot(1,2,2);
    if ~isempty(rd.peak_freqs) && ~isempty(rd.q_factors)
        bar(rd.peak_freqs(1:min(5,length(rd.peak_freqs))), rd.q_factors(1:min(5,length(rd.q_factors))));
        xlabel('Peak Frequency');
        ylabel('Q-Factor');
        title('Quality Factors');
        grid on;
    end
end

function fig = regenerate_anisotropy(d, exp_name, freq_name)
    if ~isfield(d, 'aniso_data'), fig = []; return; end
    ad = d.aniso_data;

    fig = figure('Position', [100 100 800 400], 'Visible', 'off');

    subplot(1,2,1);
    if isfield(ad, 'positions') && isfield(ad, 'ratio')
        plot(ad.positions, ad.ratio, 'mo-', 'LineWidth', 1.5);
        xlabel('Distance from Drive (px)');
        ylabel('X/Y Amplitude Ratio');
        yline(1, 'k--');
        title(sprintf('Anisotropy - %s %s', exp_name, freq_name));
        grid on;
    end

    subplot(1,2,2);
    if isfield(ad, 'mean_ratio')
        bar([ad.amp_x, ad.amp_y]);
        set(gca, 'XTickLabel', {'X', 'Y'});
        ylabel('Mean Amplitude');
        title(sprintf('Mean Ratio: %.2f', ad.mean_ratio));
        grid on;
    end
end

function fig = regenerate_momentum(d, exp_name, freq_name)
    if ~isfield(d, 'mom_data'), fig = []; return; end
    md = d.mom_data;

    fig = figure('Position', [100 100 800 600], 'Visible', 'off');

    if isfield(md, 'S_kw') && isfield(md, 'k_vals') && isfield(md, 'omega_vals')
        imagesc(md.k_vals, md.omega_vals, log10(md.S_kw' + eps));
        axis xy;
        colormap(hot);
        colorbar;
        xlabel('Wavevector k');
        ylabel('Frequency ω');
        title(sprintf('S(k,ω) - %s %s', exp_name, freq_name));
    end
end

function fig = regenerate_decomposition(d, exp_name, freq_name)
    if ~isfield(d, 'decomp_data'), fig = []; return; end
    dd = d.decomp_data;

    fig = figure('Position', [100 100 1200 400], 'Visible', 'off');

    subplot(1,3,1);
    bar(dd.explained_variance * 100);
    xlabel('Mode');
    ylabel('Variance Explained (%)');
    title(sprintf('Mode Decomposition - %s %s', exp_name, freq_name));
    xlim([0.5 min(20, length(dd.explained_variance))+0.5]);
    grid on;

    subplot(1,3,2);
    cumvar = cumsum(dd.explained_variance);
    plot(cumvar * 100, 'b-o', 'LineWidth', 1.5);
    xlabel('Number of Modes');
    ylabel('Cumulative Variance (%)');
    title('Cumulative Explained Variance');
    ylim([0 100]);
    grid on;

    subplot(1,3,3);
    % Need x0, y0 positions - check if stored
    if isfield(dd, 'x0') && isfield(dd, 'y0')
        N = length(dd.x0);
        mode1_x = dd.modes(1:N, 1);
        mode1_y = dd.modes(N+1:end, 1);
        mode_amp = sqrt(mode1_x.^2 + mode1_y.^2);
        scatter(dd.x0, dd.y0, 20, mode_amp, 'filled');
        colormap(hot);
        cb = colorbar;
        clim_max = prctile(mode_amp, 95);
        if clim_max > 0
            clim([0 clim_max]);
            cb.Label.String = 'Amplitude (95th pctl)';
        end
        axis equal;
        title('Mode 1 Amplitude');
        xlabel('X'); ylabel('Y');
    else
        text(0.5, 0.5, 'Position data not saved', 'HorizontalAlignment', 'center');
        axis off;
    end
end

function fig = regenerate_vacf(d, exp_name, freq_name)
    if ~isfield(d, 'vacf_data'), fig = []; return; end
    vd = d.vacf_data;

    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    if isfield(vd, 'lags') && isfield(vd, 'vacf')
        plot(vd.lags, vd.vacf, 'b-', 'LineWidth', 1.5);
        xlabel('Lag (frames)');
        ylabel('VACF');
        title(sprintf('Velocity Autocorrelation - %s %s', exp_name, freq_name));
        grid on;
    end

    subplot(1,2,2);
    if isfield(vd, 'dos_freq') && isfield(vd, 'dos')
        plot(vd.dos_freq, vd.dos, 'r-', 'LineWidth', 1.5);
        xlabel('Frequency');
        ylabel('DOS');
        title('Density of States');
        grid on;
    end
end

function fig = regenerate_msd(d, exp_name, freq_name)
    if ~isfield(d, 'msd_data'), fig = []; return; end
    md = d.msd_data;

    fig = figure('Position', [100 100 600 400], 'Visible', 'off');

    if isfield(md, 'lags') && isfield(md, 'msd')
        loglog(md.lags, md.msd, 'g-', 'LineWidth', 1.5);
        hold on;
        if isfield(md, 'alpha')
            % Plot reference line
            ref_line = md.msd(1) * (md.lags / md.lags(1)).^md.alpha;
            loglog(md.lags, ref_line, 'k--', 'LineWidth', 1);
            title(sprintf('MSD - %s %s (α=%.2f)', exp_name, freq_name, md.alpha));
        else
            title(sprintf('MSD - %s %s', exp_name, freq_name));
        end
        xlabel('Lag (frames)');
        ylabel('MSD (px^2)');
        grid on;
    end
end

function fig = regenerate_correlation(d, exp_name, freq_name)
    if ~isfield(d, 'corr_data'), fig = []; return; end
    cd = d.corr_data;

    fig = figure('Position', [100 100 600 400], 'Visible', 'off');

    if isfield(cd, 'distances') && isfield(cd, 'correlation')
        plot(cd.distances, cd.correlation, 'c-o', 'LineWidth', 1.5);
        xlabel('Distance (px)');
        ylabel('Correlation');
        yline(0, 'k--');
        title(sprintf('Spatial Correlation - %s %s', exp_name, freq_name));
        grid on;
    end
end

%% ==================== UTILITY ====================
function save_plot(fig, folder, name, opts)
    if opts.save_fig
        savefig(fig, fullfile(folder, [name '.fig']));
    end
    if opts.save_png
        saveas(fig, fullfile(folder, [name '.png']));
    end
end
