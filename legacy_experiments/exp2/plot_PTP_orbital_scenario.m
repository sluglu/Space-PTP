function plot_PTP_orbital_scenario(results)
    
    pos1 = zeros(3, length(results.tspan));
    pos2 = zeros(3, length(results.tspan));
    for k = 1:length(results.tspan)
        pos1(:,k) = results.r1(results.tspan(k));
        pos2(:,k) = results.r2(results.tspan(k));
    end
    
    
    figure('Position', [100, 100, 1400, 800]);
    
    % Plot 1: 3D Orbital trajectories with LOS links
    subplot(3,3,1);
    hold on;
    plot3(pos1(1,:), pos1(2,:), pos1(3,:), '-', 'Color', [1 0 0], 'LineWidth', 1.2, 'DisplayName', 'Satellite 1');
    plot3(pos2(1,:), pos2(2,:), pos2(3,:), '-', 'Color', [0 0 1], 'LineWidth', 1.2, 'DisplayName', 'Satellite 2');
    
    % Earth sphere
    rE = 6371e3; 
    [xe, ye, ze] = sphere(50);
    surf(xe*rE, ye*rE, ze*rE, 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'FaceColor', [0.6 0.6 1], 'DisplayName', 'Earth');
    
    % LOS connection lines
    for intv = 1:size(results.los_intervals,1)
        idxs = find(results.tspan >= results.los_intervals(intv,1) & results.tspan <= results.los_intervals(intv,2));
        for k = idxs(1:5:end)
            if k <= size(pos1,2)
                plot3([pos1(1,k), pos2(1,k)], [pos1(2,k), pos2(2,k)], [pos1(3,k), pos2(3,k)], ...
                      'g-', 'LineWidth', 0.5);
            end
        end
    end
    
    axis equal; grid on;
    xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
    title('3D Orbital Trajectories with LOS');
    hold off;
    
    % Plot 2: LOS intervals overview
    subplot(3,3,2);
    area(results.tspan/60, results.los_flags, 'FaceColor', [0.8 0.8 0.8], 'FaceAlpha', 0.5, 'DisplayName', 'LOS Available');
    hold on;
    for i = 1:size(results.los_intervals,1)
        plot([results.los_intervals(i,1)/60, results.los_intervals(i,2)/60], [1.1, 1.1], 'r-', 'LineWidth', 3);
    end
    ylim([0, 1.2]);
    xlabel('Time [min]'); ylabel('LOS Status');
    title('LOS Intervals');
    legend('LOS Available', 'PTP Simulated', 'Location', 'best');
    grid on;
    hold off;
    
    % Plot 3: Propagation delays and PTP delay estimates
    subplot(3,3,3);
    % remove times (time already stored in fwd and bwd prop vector) 
    plot(results.times/60, results.forward_propagation_delays, 'r', 'DisplayName', 'forward Propagation Delay');
    hold on;
    plot(results.times/60, results.backward_propagation_delays, 'b', 'DisplayName', 'backward Propagation Delay');
    hold on;
    plot(results.times/60, results.ptp_delay, 'g', 'DisplayName', 'PTP Delay Estimate');
    xlabel('Time [min]');
    xlim([0 results.sim_duration*60]);
    ylabel('Delay [s]');
    title('Propagation Delays and PTP Delays Estimate');
    legend('show', 'Location', 'best');
    grid on;
    
    % Plot 4-6: Clock synchronization performance
    subplot(3,3,[4,6]);
    hold on;
    % Clock offset plots
    plot(results.times/60, results.real_offset, 'r-', 'LineWidth', 1.5, 'DisplayName', 'True Offset');
    
    plot(results.times/60, results.ptp_offset, '-b', 'LineWidth', 1.5, 'DisplayName', 'PTP Estimate');
    
    ylabel('Clock Offset [s]');
    xlabel('Time [min]');
    title('Clock Offset and PTP Offset Estimate');
    legend('show', 'Location', 'best');
    grid on;
    hold off;

    % Plot 7-10: Clock syntonization performance
    subplot(3,3,[7,9]);
    hold on;
    % Clock freq offset plots
    plot(results.times/60, results.real_freq_shift, 'r-', 'LineWidth', 1.5, 'DisplayName', 'True Frequency Offset');
   
    ylabel('Clock Frequency Offset [Hz]');
    xlabel('Time [min]');
    title('Clock Syntonization Performance Over Time');
    legend('show', 'Location', 'best');
    grid on;
    hold off;
    
    
    name = results.scenario{1};
    sgtitle(sprintf('PTP Orbital Simulation Results - %s', name), 'FontSize', 14, 'FontWeight', 'bold');
end
