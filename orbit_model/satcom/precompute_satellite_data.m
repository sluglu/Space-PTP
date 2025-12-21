function [sat_data] = precompute_satellite_data(sat1, sat2, startTime, tspan, carrier_frequency)
    % Pre-compute all satellite-related data using batch queries
    %
    % Inputs:
    %   sat1, sat2: Satellite objects
    %   startTime: Scenario start time
    %   tspan: Time vector [s] - requested simulation time span
    %   master_f0, slave_f0: Carrier frequencies [Hz]
    %
    % Outputs:
    %   sat_data: Structure with interpolated satellite data functions
    
    fprintf('Pre-computing satellite data using batch queries...\n');
    fprintf('  Requested time span: %.1f to %.1f seconds (%.2f hours)\n', ...
            tspan(1), tspan(end), (tspan(end)-tspan(1))/3600);
    
    fprintf('  Computing forward propagation delays...\n');
    tic;
    % Without time argument, returns full history from StartTime to StopTime/SimulationTime
    [forward_delays, time_out] = latency(sat1, sat2);
    fprintf('    Done in %.2f seconds (%d points)\n', toc, length(time_out));
    
    fprintf('  Computing backward propagation delays...\n');
    tic;
    backward_delays = latency(sat2, sat1);
    fprintf('    Done in %.2f seconds\n', toc);
    
    fprintf('  Computing forward Doppler shifts...\n');
    tic;
    % dopplershift with Frequency parameter returns Doppler shift in Hz
    forward_doppler = dopplershift(sat1, sat2, Frequency=carrier_frequency);
    fprintf('    Done in %.2f seconds\n', toc);
    
    fprintf('  Computing backward Doppler shifts...\n');
    tic;
    backward_doppler = dopplershift(sat2, sat1, Frequency=carrier_frequency);
    fprintf('    Done in %.2f seconds\n', toc);
    
    % Convert time_out (datetime array) to seconds from startTime
    time_out_seconds = seconds(time_out - startTime);
    
    fprintf('  Satellite data time span: %.1f to %.1f seconds\n', ...
            time_out_seconds(1), time_out_seconds(end));
    
    % Check if satellite data covers the requested tspan
    if time_out_seconds(end) < tspan(end)
        warning('Satellite data ends at %.1f s but simulation needs %.1f s. Check scenario StopTime!', ...
                time_out_seconds(end), tspan(end));
    end
    
    % Determine LOS flags
    los_flags = ~isnan(forward_delays);
    
    % Create interpolation functions for fast lookup during simulation
    % Use 'linear' for smooth interpolation between points
    sat_data.forward_delay_interp = @(t) interp1(time_out_seconds, forward_delays, t, 'linear', NaN);
    sat_data.backward_delay_interp = @(t) interp1(time_out_seconds, backward_delays, t, 'linear', NaN);
    sat_data.forward_doppler_interp = @(t) interp1(time_out_seconds, forward_doppler, t, 'linear', NaN);
    sat_data.backward_doppler_interp = @(t) interp1(time_out_seconds, backward_doppler, t, 'linear', NaN);
    sat_data.los_flag_interp = @(t) interp1(time_out_seconds, double(los_flags), t, 'nearest', 0);
    
    % Store raw data as well
    sat_data.tspan = time_out_seconds;
    sat_data.forward_delays = forward_delays;
    sat_data.backward_delays = backward_delays;
    sat_data.forward_doppler = forward_doppler;
    sat_data.backward_doppler = backward_doppler;
    sat_data.los_flags = los_flags;
    
    fprintf('Pre-computation complete!\n\n');
end