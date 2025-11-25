function plot_PTP_orbital_scenario_satcom(results)
    
    figure('Position', [100, 100, 1400, 1000]);
    
    % --- Main Title and Scenario Parameters Annotation ---
    name = results.scenario{1};
    sgtitle(sprintf('PTP Orbital Simulation Results - %s (with Doppler)', name), 'FontSize', 16, 'FontWeight', 'bold');

    % Extract orbital parameters
    a1 = results.scenario{2}; e1 = results.scenario{3}; i1 = results.scenario{4};
    raan1 = results.scenario{5}; argp1 = results.scenario{6}; ta1 = results.scenario{7};
    a2 = results.scenario{8}; e2 = results.scenario{9}; i2 = results.scenario{10};
    raan2 = results.scenario{11}; argp2 = results.scenario{12}; ta2 = results.scenario{13};

    % Format parameter strings with Keplerian elements
    rE = 6371e3;
    s1_params_str = sprintf('S1: a=%.0f km, e=%.4f, i=%.1f°, RAAN=%.1f°, ω=%.1f°, TA=%.1f°', ...
                            a1*1e-3, e1, i1, raan1, argp1, ta1);
    s2_params_str = sprintf('S2: a=%.0f km, e=%.4f, i=%.1f°, RAAN=%.1f°, ω=%.1f°, TA=%.1f°', ...
                            a2*1e-3, e2, i2, raan2, argp2, ta2);
    full_param_str = {s1_params_str, s2_params_str};

    % Add annotation textbox
    annotation('textbox', [0.15, 0.93, 0.7, 0.05], ...
               'String', full_param_str, ...
               'EdgeColor', 'none', ...
               'HorizontalAlignment', 'center', ...
               'FontSize', 9, ...
               'FontWeight', 'normal');

    % --- Plot 1: Propagation delays and PTP delay estimates ---
    subplot('Position', [0.13, 0.73, 0.775, 0.15]);
    plot(results.times/60, results.forward_propagation_delays, 'r', 'DisplayName', 'Forward Propagation Delay');
    hold on;
    plot(results.times/60, results.backward_propagation_delays, 'b', 'DisplayName', 'Backward Propagation Delay');
    plot(results.times/60, results.ptp_delay, 'g', 'DisplayName', 'PTP Delay Estimate');
    xlabel('Time [min]');
    xlim([0 results.sim_duration*60]);
    ylabel('Delay [s]');
    title('Propagation Delays and PTP Delays Estimate');
    legend('show', 'Location', 'best');
    grid on;
    
    % --- Plot 2: Doppler shifts ---
    subplot('Position', [0.13, 0.53, 0.775, 0.15]);
    plot(results.times/60, results.forward_doppler_shifts, 'r', 'DisplayName', 'Forward Doppler Shift');
    hold on;
    plot(results.times/60, results.backward_doppler_shifts, 'b', 'DisplayName', 'Backward Doppler Shift');
    xlabel('Time [min]');
    xlim([0 results.sim_duration*60]);
    ylabel('Doppler Shift [Hz]');
    title('Doppler Shifts');
    legend('show', 'Location', 'best');
    grid on;
    
    % --- Plot 3: Clock synchronization performance ---
    subplot('Position', [0.13, 0.33, 0.775, 0.15]);
    hold on;
    plot(results.times/60, results.real_offset, 'r-', 'LineWidth', 1.5, 'DisplayName', 'True Offset');
    plot(results.times/60, results.ptp_offset, '-b', 'LineWidth', 1.5, 'DisplayName', 'PTP Estimate');
    
    ylabel('Clock Offset [s]');
    xlabel('Time [min]');
    title('Clock Offset and PTP Offset Estimate');
    legend('show', 'Location', 'best');
    grid on;
    hold off;

    % --- Plot 4: PTP offset error ---
    subplot('Position', [0.13, 0.13, 0.775, 0.15]);
    hold on;
    plot(results.times/60, results.ptp_offset - results.real_offset, '-g', 'LineWidth', 1.5, 'DisplayName', 'PTP Offset Error');
    
    ylabel('Offset Error [s]');
    xlabel('Time [min]');
    title('PTP Clock Offset Error');
    grid on;
    hold off;
    
end