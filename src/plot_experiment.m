function plot_experiment(cfg)    
    exp_name = strrep(cfg.exp.name,' ','_');
    
    filepath = fullfile( ...
        cfg.exp.root, sprintf("%s.mat", exp_name));
    
    data = load(filepath);
    plot_ptp_orbital(data)
end


function plot_ptp_orbital(results)
    
    figure('Position', [100, 0, 1400, 1000]);
    
    % --- Main Title ---
    name = results.meta.exp_name;
    
    % Extract orbital parameters
    
    sat1 = results.meta.cfg.scenario.sat1;
    sat2 = results.meta.cfg.scenario.sat2;
    a1 = sat1{1};    e1 = sat1{2};    i1 = sat1{3};
    raan1 = sat1{4}; argp1 = sat1{5}; ta1 = sat1{6};
    a2 = sat2{1};    e2 = sat2{2};    i2 = sat2{3};
    raan2 = sat2{4}; argp2 = sat2{5}; ta2 = sat2{6};

    % Format parameter strings with Keplerian elements
    rE = 6371e3;
    
    % Create main title with scenario name
    main_title = sgtitle(sprintf('PTP Orbital Simulation Results - %s ', name), ...
            'FontSize', 16, 'FontWeight', 'bold', 'Interpreter', 'none');
    
    
    % Create subtitle with orbital parameters in a more compact format
    subtitle_str = sprintf(['Sat1: a=%.0fkm, e=%.4f, i=%.1f°, RAAN=%.1f°, ω=%.1f°, TA=%.1f°  |  ' ...
                           'Sat2: a=%.0fkm, e=%.4f, i=%.1f°, RAAN=%.1f°, ω=%.1f°, TA=%.1f°'], ...
                            a1*1e-3, e1, i1, raan1, argp1, ta1, ...
                            a2*1e-3, e2, i2, raan2, argp2, ta2);
    
    % Add subtitle text positioned just below the title
    annotation('textbox', [0.1, 0.913, 0.8, 0.03], ...
               'String', subtitle_str, ...
               'EdgeColor', 'none', ...
               'HorizontalAlignment', 'center', ...
               'FontSize', 9, ...
               'FontWeight', 'normal', ...
               'VerticalAlignment', 'middle', ...
               'Interpreter', 'none', ...
               'FitBoxToText', 'off');

    % --- Plot 1: Propagation delays and PTP delay estimates ---
    subplot(4, 1, 1);
    subplot(4, 1, 1);
    plot(results.times/60, results.forward_propagation_delays, 'r', 'DisplayName', 'Forward Propagation Delay', 'LineWidth', 1.2);
    hold on;
    plot(results.times/60, results.backward_propagation_delays, 'b', 'DisplayName', 'Backward Propagation Delay', 'LineWidth', 1.2);
    plot(results.times/60, results.ptp_delay, 'g', 'DisplayName', 'PTP Delay Estimate', 'LineWidth', 1.5);
    xlabel('Time [min]', 'FontSize', 10);
    xlim([0 results.sim_duration*60]);
    ylabel('Delay [s]', 'FontSize', 10);
    title('Propagation Delays and PTP Delay Estimate', 'FontSize', 11, 'FontWeight', 'bold');
    legend('show', 'Location', 'best', 'FontSize', 9);
    grid on;
    
    % --- Plot 2: Doppler shifts ---
    subplot(4, 1, 2);
    plot(results.times/60, results.forward_doppler_shifts, 'r', 'DisplayName', 'Forward Doppler Shift', 'LineWidth', 1.2);
    hold on;
    plot(results.times/60, results.backward_doppler_shifts, 'b', 'DisplayName', 'Backward Doppler Shift', 'LineWidth', 1.2);
    xlabel('Time [min]', 'FontSize', 10);
    xlim([0 results.sim_duration*60]);
    ylabel('Doppler Shift [Hz]', 'FontSize', 10);
    title('Doppler Shifts', 'FontSize', 11, 'FontWeight', 'bold');
    legend('show', 'Location', 'best', 'FontSize', 9);
    grid on;
    
    % --- Plot 3: Clock synchronization performance ---
    subplot(4, 1, 3);
    hold on;
    plot(results.times/60, results.real_offset, 'r-', 'LineWidth', 1.5, 'DisplayName', 'True Offset');
    plot(results.times/60, results.ptp_offset, '-b', 'LineWidth', 1.5, 'DisplayName', 'PTP Estimate');
    ylabel('Clock Offset [s]', 'FontSize', 10);
    xlabel('Time [min]', 'FontSize', 10);
    xlim([0 results.sim_duration*60]);
    title('Clock Offset and PTP Offset Estimate', 'FontSize', 11, 'FontWeight', 'bold');
    legend('show', 'Location', 'best', 'FontSize', 9);
    grid on;
    hold off;

    % --- Plot 4: PTP offset error ---
    subplot(4, 1, 4);
    hold on;
    offset_error = results.ptp_offset - results.real_offset;
    plot(results.times/60, offset_error, '-g', 'LineWidth', 1.5, 'DisplayName', 'PTP Offset Error');
    
    % Add statistics text
    valid_idx = ~isnan(offset_error);
    if any(valid_idx)
        mean_err = mean(offset_error(valid_idx));
        std_err = std(offset_error(valid_idx));
        max_err = max(abs(offset_error(valid_idx)));
        
        stats_str = sprintf('Mean: %.2e s | Std: %.2e s | Max: %.2e s', mean_err, std_err, max_err);
        text(0.02, 0.95, stats_str, 'Units', 'normalized', ...
             'FontSize', 9, 'BackgroundColor', 'white', ...
             'EdgeColor', 'black', 'VerticalAlignment', 'top');
    end
    
    ylabel('Offset Error [s]', 'FontSize', 10);
    xlabel('Time [min]', 'FontSize', 10);
    xlim([0 results.sim_duration*60]);
    title('PTP Clock Offset Error', 'FontSize', 11, 'FontWeight', 'bold');
    grid on;
    hold off;
    
end