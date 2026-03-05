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
    plot(bd.ctrs, bd.amplitudes, 'b-o', 'LineWidth', 1.5);
    xlabel('Distance from Drive (px)');
    ylabel('Amplitude');
    title(sprintf('Bode Amplitude - %s %s', exp_name, freq_name));
    grid on;

    subplot(1,2,2);
    plot(bd.ctrs, unwrap(bd.phases) * 180/pi, 'r-o', 'LineWidth', 1.5);
    xlabel('Distance from Drive (px)');
    ylabel('Phase (degrees)');
    title('Bode Phase');
    grid on;
end

function fig = regenerate_fourier(d, exp_name, freq_name)
    if ~isfield(d, 'fourier_data'), fig = []; return; end
    fd = d.fourier_data;

    fig = figure('Position', [100 100 1200 400], 'Visible', 'off');

    subplot(1,3,1);
    semilogy(fd.f, fd.P_total, 'k-', 'LineWidth', 1.5);
    xlabel('Frequency (1/frame)');
    ylabel('Power Spectral Density');
    title(sprintf('Total Power - %s %s', exp_name, freq_name));
    xlim([0 0.15]);
    grid on;

    subplot(1,3,2);
    semilogy(fd.f, fd.Px, 'r-', 'LineWidth', 1.5, 'DisplayName', 'X');
    hold on;
    semilogy(fd.f, fd.Py, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Y');
    semilogy(fd.f, fd.Pz, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Z');
    xlabel('Frequency');
    ylabel('Power');
    title('Component Spectra');
    legend('Location', 'northeast');
    xlim([0 0.15]);
    grid on;

    subplot(1,3,3);
    plot(fd.f, fd.participation, 'm-', 'LineWidth', 1.5);
    xlabel('Frequency');
    ylabel('Participation Ratio');
    title('Mode Localization');
    ylim([0 1]);
    xlim([0 0.15]);
    grid on;
end

function fig = regenerate_penetration(d, exp_name, freq_name)
    if ~isfield(d, 'pen_data'), fig = []; return; end
    pd = d.pen_data;

    fig = figure('Position', [100 100 600 400], 'Visible', 'off');

    semilogy(pd.ctrs, pd.rms_amp + eps, 'bo', 'MarkerSize', 6);
    hold on;
    if isfield(pd, 'fit_amp')
        semilogy(pd.ctrs, pd.fit_amp, 'r-', 'LineWidth', 2);
    end
    xlabel('Distance from Drive (px)');
    ylabel('RMS Amplitude');
    delta = pd.penetration_depth;
    if isnan(delta), delta = 0; end
    title(sprintf('Penetration - %s %s (δ=%.1f px)', exp_name, freq_name, delta));
    legend('Data', sprintf('Fit: δ=%.1f', delta), 'Location', 'northeast');
    grid on;
end

function fig = regenerate_resonance(d, exp_name, freq_name)
    if ~isfield(d, 'res_data'), fig = []; return; end
    rd = d.res_data;

    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    if isfield(rd, 'f') && isfield(rd, 'P')
        semilogy(rd.f, rd.P, 'b-', 'LineWidth', 1);
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
    xlim([0 0.15]);
    grid on;

    subplot(1,2,2);
    if ~isempty(rd.peak_freqs) && ~isempty(rd.q_factors)
        n_peaks = min(5, min(length(rd.peak_freqs), length(rd.q_factors)));
        bar(rd.peak_freqs(1:n_peaks), rd.q_factors(1:n_peaks));
        xlabel('Peak Frequency');
        ylabel('Q-Factor');
        title('Quality Factors');
        grid on;
    end
end

function fig = regenerate_anisotropy(d, exp_name, freq_name)
    if ~isfield(d, 'anis_data'), fig = []; return; end
    ad = d.anis_data;

    fig = figure('Position', [100 100 800 400], 'Visible', 'off');

    subplot(1,2,1);
    % Compute ratio from rms_x and rms_y
    ratio = ad.rms_x ./ (ad.rms_y + eps);
    if isfield(ad, 'ctrs')
        plot(ad.ctrs, ratio, 'mo-', 'LineWidth', 1.5);
    else
        plot(ratio, 'mo-', 'LineWidth', 1.5);
    end
    xlabel('Distance from Drive (px)');
    ylabel('X/Y Amplitude Ratio');
    yline(1, 'k--');
    title(sprintf('Anisotropy - %s %s', exp_name, freq_name));
    grid on;

    subplot(1,2,2);
    mean_x = mean(ad.rms_x(ad.rms_x > 0));
    mean_y = mean(ad.rms_y(ad.rms_y > 0));
    bar([mean_x, mean_y]);
    set(gca, 'XTickLabel', {'X', 'Y'});
    ylabel('Mean RMS Amplitude');
    title(sprintf('Mean Ratio: %.2f', mean_x / (mean_y + eps)));
    grid on;
end

function fig = regenerate_momentum(d, exp_name, freq_name)
    if ~isfield(d, 'mom_data'), fig = []; return; end
    md = d.mom_data;

    fig = figure('Position', [100 100 1000 400], 'Visible', 'off');

    subplot(1,2,1);
    if isfield(md, 'S_k_omega') && isfield(md, 'k') && isfield(md, 'f')
        imagesc(md.k, md.f, log10(md.S_k_omega' + eps));
        axis xy;
        colormap(hot);
        colorbar;
        xlabel('Wavevector k');
        ylabel('Frequency');
        title(sprintf('S(k,ω) - %s %s', exp_name, freq_name));
        ylim([0 0.15]);
    end

    subplot(1,2,2);
    if isfield(md, 'S_k')
        plot(md.k, md.S_k, 'b-', 'LineWidth', 1.5);
        xlabel('Wavevector k');
        ylabel('S(k)');
        title('Static Structure Factor');
        grid on;
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
    if isfield(vd, 't_lag') && isfield(vd, 'vacf')
        plot(vd.t_lag, vd.vacf, 'b-', 'LineWidth', 1.5);
        xlabel('Lag (frames)');
        ylabel('Normalized VACF');
        title(sprintf('Velocity Autocorrelation - %s %s', exp_name, freq_name));
        yline(0, 'k--');
        grid on;
    end

    subplot(1,2,2);
    if isfield(vd, 'f_dos') && isfield(vd, 'dos')
        plot(vd.f_dos, vd.dos, 'r-', 'LineWidth', 1.5);
        xlabel('Frequency');
        ylabel('DOS');
        title('Density of States');
        xlim([0 0.15]);
        grid on;
    end
end

function fig = regenerate_msd(d, exp_name, freq_name)
    if ~isfield(d, 'msd_data'), fig = []; return; end
    md = d.msd_data;

    fig = figure('Position', [100 100 600 400], 'Visible', 'off');

    if isfield(md, 't_lag') && isfield(md, 'msd')
        loglog(md.t_lag, md.msd, 'g-', 'LineWidth', 1.5);
        hold on;
        if isfield(md, 'alpha') && ~isnan(md.alpha)
            % Plot reference line
            valid = md.t_lag > 0 & md.msd > 0;
            if any(valid)
                t_ref = md.t_lag(valid);
                ref_line = md.msd(find(valid,1)) * (t_ref / t_ref(1)).^md.alpha;
                loglog(t_ref, ref_line, 'k--', 'LineWidth', 1);
            end
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

    fig = figure('Position', [100 100 800 400], 'Visible', 'off');

    subplot(1,2,1);
    if isfield(cd, 'r') && isfield(cd, 'corr_xx')
        plot(cd.r, cd.corr_xx, 'r-o', 'LineWidth', 1.5);
        xlabel('Distance (px)');
        ylabel('C_{xx}');
        yline(0, 'k--');
        title(sprintf('X-X Correlation - %s %s', exp_name, freq_name));
        grid on;
    end

    subplot(1,2,2);
    if isfield(cd, 'r') && isfield(cd, 'corr_yy')
        plot(cd.r, cd.corr_yy, 'b-o', 'LineWidth', 1.5);
        xlabel('Distance (px)');
        ylabel('C_{yy}');
        yline(0, 'k--');
        title('Y-Y Correlation');
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
