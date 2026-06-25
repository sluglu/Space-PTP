function sat_data = precompute_satellite_data(scfg)
% PRECOMPUTE_SATELLITE_DATA  Batch-query satellite data for fast simulation lookup.
%
%   sat_data = precompute_satellite_data(scfg)
%
%   scfg  — scenario struct from any sc_*() config (must have a .sc field)
%
% node1 and node2 are inferred from scfg.sc: satellites first, then ground stations.
% Doppler is stored as fractional (dimensionless, df/f₀ = v_r/c).
% Multiply by carrier frequency to get Hz.
%
% Returns sat_data with interpolation functions for delays, Doppler, and
% ECI position/velocity (needed by Channel effects such as Shapiro delay).

    % --- Infer node1 / node2 from scenario ---
    sc   = scfg.sc;
    sats = sc.Satellites;
    gsts = sc.GroundStations;
    if length(sats) >= 2
        node1 = sats(1);  node2 = sats(2);
    elseif length(sats) == 1 && ~isempty(gsts)
        node1 = sats(1);  node2 = gsts(1);
    else
        error('precompute_satellite_data: scenario must have at least 2 platforms.');
    end

    start_time = sc.StartTime;
    dt         = sc.SampleTime;
    total_time = seconds(sc.StopTime - sc.StartTime);
    tspan      = 0 : dt : total_time;

    fprintf('Pre-computing satellite data...\n');
    fprintf('  Time span: %.1f – %.1f s (%.2f h)\n', tspan(1), tspan(end), total_time/3600);

    % --- Propagation delays ---
    fprintf('  Forward delays... '); tic;
    [fwd_delays, time_out] = latency(node1, node2);
    fprintf('%.2f s (%d points)\n', toc, length(time_out));

    fprintf('  Backward delays... '); tic;
    bwd_delays = latency(node2, node1);
    fprintf('%.2f s\n', toc);

    % --- Fractional Doppler (df/f0 = v_r/c, dimensionless) ---
    % Passing Frequency=1 to dopplershift yields df for a 1 Hz carrier = v_r/c.
    fprintf('  Forward Doppler... '); tic;
    fwd_doppler = dopplershift(node1, node2, 'Frequency', 1);
    fprintf('%.2f s\n', toc);

    fprintf('  Backward Doppler... '); tic;
    bwd_doppler = dopplershift(node2, node1, 'Frequency', 1);
    fprintf('%.2f s\n', toc);

    % --- ECI position and velocity ---
    fprintf('  Satellite states (ECI)... '); tic;
    try
        [pos1, vel1] = states(node1, 'CoordinateFrame', 'inertial');
        [pos2, vel2] = states(node2, 'CoordinateFrame', 'inertial');
        has_states = true;
    catch e
        warning('Could not compute satellite states: %s', e.message);
        has_states = false;
    end
    fprintf('%.2f s\n', toc);

    % Convert datetime array to seconds from start_time
    t_sec = seconds(time_out - start_time);

    if t_sec(end) < tspan(end)
        warning('Satellite data ends at %.1f s but simulation needs %.1f s.', t_sec(end), tspan(end));
    end

    % --- LOS flags ---
    los_flags = ~isnan(fwd_delays);

    % --- Build interpolants ---
    sat_data.forward_delay_interp    = @(t) interp1(t_sec, fwd_delays,  t, 'linear', NaN);
    sat_data.backward_delay_interp   = @(t) interp1(t_sec, bwd_delays,  t, 'linear', NaN);
    sat_data.forward_doppler_interp  = @(t) interp1(t_sec, fwd_doppler, t, 'linear', NaN);
    sat_data.backward_doppler_interp = @(t) interp1(t_sec, bwd_doppler, t, 'linear', NaN);
    sat_data.los_flag_interp         = @(t) interp1(t_sec, double(los_flags), t, 'nearest', 0);

    % --- Raw data ---
    sat_data.tspan            = t_sec;
    sat_data.forward_delays   = fwd_delays;
    sat_data.backward_delays  = bwd_delays;
    sat_data.forward_doppler  = fwd_doppler;   % fractional: df/f0
    sat_data.backward_doppler = bwd_doppler;   % fractional: df/f0
    sat_data.los_flags        = los_flags;

    if has_states
        sat_data.pos_master = pos1;   % 3×N [m, ECI]
        sat_data.vel_master = vel1;   % 3×N [m/s, ECI]
        sat_data.pos_slave  = pos2;
        sat_data.vel_slave  = vel2;
    end

    fprintf('Pre-computation complete.\n\n');
end
