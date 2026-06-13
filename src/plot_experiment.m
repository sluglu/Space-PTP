function plot_experiment(results_or_cfg)
% PLOT_EXPERIMENT  Plot PTP simulation results.
%   plot_experiment(results)  — pass results struct directly
%   plot_experiment(cfg)      — load results from disk using cfg.exp

    if isfield(results_or_cfg, 'meta')
        results = results_or_cfg;
    else
        cfg      = results_or_cfg;
        filepath = fullfile(cfg.exp.root, sprintf('%s.mat', cfg.exp.name));
        results  = load(filepath);
    end

    plot_ptp_orbital(results);
end


function plot_ptp_orbital(results)

    figure('Position', [100, 0, 1400, 1000]);

    name = results.meta.exp_name;
    sgtitle(sprintf('PTP Orbital Simulation Results - %s', name), ...
        'FontSize', 16, 'FontWeight', 'bold', 'Interpreter', 'none');

    sim_duration_min = results.meta.cfg.sim.sim_duration * 60;

    % --- Plot 1: Propagation delays and PTP delay estimate ---
    subplot(4, 1, 1);
    plot(results.times/60, results.fwd_delay, 'r', 'DisplayName', 'Forward Propagation Delay', 'LineWidth', 1.2);
    hold on;
    plot(results.times/60, results.bwd_delay, 'b', 'DisplayName', 'Backward Propagation Delay', 'LineWidth', 1.2);
    plot(results.times/60, results.delay_est, 'g', 'DisplayName', 'PTP Delay Estimate', 'LineWidth', 1.5);
    xlabel('Time [min]', 'FontSize', 10);
    xlim([0 sim_duration_min]);
    ylabel('Delay [s]', 'FontSize', 10);
    title('Propagation Delays and PTP Delay Estimate', 'FontSize', 11, 'FontWeight', 'bold');
    legend('show', 'Location', 'best', 'FontSize', 9);
    grid on;

    % --- Plot 2: Doppler shifts ---
    subplot(4, 1, 2);
    plot(results.times/60, results.fwd_doppler, 'r', 'DisplayName', 'Forward Doppler Shift', 'LineWidth', 1.2);
    hold on;
    plot(results.times/60, results.bwd_doppler, 'b', 'DisplayName', 'Backward Doppler Shift', 'LineWidth', 1.2);
    xlabel('Time [min]', 'FontSize', 10);
    xlim([0 sim_duration_min]);
    ylabel('Doppler Shift [Hz]', 'FontSize', 10);
    title('Doppler Shifts', 'FontSize', 11, 'FontWeight', 'bold');
    legend('show', 'Location', 'best', 'FontSize', 9);
    grid on;

    % --- Plot 3: Clock offset and PTP estimate ---
    subplot(4, 1, 3);
    plot(results.times/60, results.real_offset, 'r-', 'LineWidth', 1.5, 'DisplayName', 'True Offset');
    hold on;
    plot(results.times/60, results.offset_est, 'b-', 'LineWidth', 1.5, 'DisplayName', 'PTP Estimate');
    ylabel('Clock Offset [s]', 'FontSize', 10);
    xlabel('Time [min]', 'FontSize', 10);
    xlim([0 sim_duration_min]);
    title('Clock Offset and PTP Offset Estimate', 'FontSize', 11, 'FontWeight', 'bold');
    legend('show', 'Location', 'best', 'FontSize', 9);
    grid on;

    % --- Plot 4: PTP offset error ---
    subplot(4, 1, 4);
    offset_error = results.offset_est - results.real_offset;
    plot(results.times/60, offset_error, 'g-', 'LineWidth', 1.5, 'DisplayName', 'PTP Offset Error');
    hold on;

    valid_idx = ~isnan(offset_error);
    if any(valid_idx)
        mean_err = mean(offset_error(valid_idx));
        std_err  = std(offset_error(valid_idx));
        max_err  = max(abs(offset_error(valid_idx)));
        stats_str = sprintf('Mean: %.2e s | Std: %.2e s | Max: %.2e s', mean_err, std_err, max_err);
        text(0.02, 0.95, stats_str, 'Units', 'normalized', ...
             'FontSize', 9, 'BackgroundColor', 'white', ...
             'EdgeColor', 'black', 'VerticalAlignment', 'top');
    end

    ylabel('Offset Error [s]', 'FontSize', 10);
    xlabel('Time [min]', 'FontSize', 10);
    xlim([0 sim_duration_min]);
    title('PTP Clock Offset Error', 'FontSize', 11, 'FontWeight', 'bold');
    grid on;

end