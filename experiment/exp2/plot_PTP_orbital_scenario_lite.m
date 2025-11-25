function plot_PTP_orbital_scenario_lite(results)
    % Extracts satellite positions over time (can be used for 3D trajectory plots)
    pos1 = zeros(3, length(results.tspan));
    pos2 = zeros(3, length(results.tspan));
    for k = 1:length(results.tspan)
        pos1(:,k) = results.r1(results.tspan(k));
        pos2(:,k) = results.r2(results.tspan(k));
    end
    
    
    figure('Position', [100, 100, 1400, 800]);
    
    % Set the main title for the figure
    name = results.scenario{1};
    sgtitle(sprintf('PTP Orbital Simulation Results - %s', name), 'FontSize', 16, 'FontWeight', 'bold');

    % Extract orbital parameters from the results structure
    alt1 = results.scenario{2}; alt2 = results.scenario{3};
    inc1 = results.scenario{4}; inc2 = results.scenario{5};
    anom1 = results.scenario{6}; anom2 = results.scenario{7};
    raan1 = results.scenario{8}; raan2 = results.scenario{9};

    % Format parameter strings with explicit labels
    deg = pi/180;
    rE = 6371e3;
    s1_params_str = sprintf('S1: Altitude=%.0f km, Inclination=%.1f°, Anomaly=%.1f°, RAAN=%.1f°', (alt1 - rE)*1e-3, inc1/deg, anom1/deg, raan1/deg);
    s2_params_str = sprintf('S2: Altitude=%.0f km, Inclination=%.1f°, Anomaly=%.1f°, RAAN=%.1f°', (alt2 - rE)*1e-3, inc2/deg, anom2/deg, raan2/deg);
    full_param_str = {s1_params_str, s2_params_str};

    annotation('textbox', [0.15, 0.88, 0.7, 0.05], ... % Lowered 'bottom' from 0.9 to 0.88
               'String', full_param_str, ...
               'EdgeColor', 'none', ...
               'HorizontalAlignment', 'center', ...
               'FontSize', 10, ...
               'FontWeight', 'normal');

    % Plots

    subplot('Position', [0.13, 0.65, 0.775, 0.2]); % Lowered 'bottom' and adjusted height
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
    
    subplot('Position', [0.13, 0.35, 0.775, 0.2]); % Standard position for bottom plot
    hold on;
    plot(results.times/60, results.real_offset, 'r-', 'LineWidth', 1.5, 'DisplayName', 'True Offset');
    plot(results.times/60, results.ptp_offset, '-b', 'LineWidth', 1.5, 'DisplayName', 'PTP Estimate');
    
    ylabel('Clock Offset [s]');
    xlabel('Time [min]');
    title('Clock Offset and PTP Offset Estimate');
    legend('show', 'Location', 'best');
    grid on;
    hold off;

    subplot('Position', [0.13, 0.05, 0.775, 0.2]); % Standard position for bottom plot
    hold on;
    plot(results.times/60, results.ptp_offset - results.real_offset, '-g', 'LineWidth', 1.5, 'DisplayName', 'PTP Offset Error');
    
    ylabel('Clock Offset [s]');
    xlabel('Time [min]');
    title('PTP Clock Offset Error');
    grid on;
    hold off;
    
        
end