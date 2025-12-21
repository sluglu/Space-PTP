function doppler_shift = compute_doppler_shift(r1, r2, t0, f_carrier)
    c = 299792458; % Speed of light [m/s]
    h = 1e-3;      % Time step for numerical differentiation [s]
    
    % Get positions at current time
    pos_tx = r1(t0);
    pos_rx = r2(t0);
    
    % Compute range vector (from transmitter to receiver)
    range_vec = pos_rx - pos_tx;
    range_magnitude = norm(range_vec);
    
    % Unit vector pointing from transmitter to receiver
    range_unit = range_vec / range_magnitude;
    
    % Compute velocities using numerical differentiation
    % Transmitter velocity
    pos_tx_next = r1(t0 + h);
    vel_tx = (pos_tx_next - pos_tx) / h;
    
    % Receiver velocity  
    pos_rx_next = r2(t0 + h);
    vel_rx = (pos_rx_next - pos_rx) / h;
    
    % Relative velocity (receiver velocity - transmitter velocity)
    vel_relative = vel_rx - vel_tx;
    
    % Radial component of relative velocity (positive = approaching)
    v_radial = dot(vel_relative, range_unit);
    
    % Compute Doppler shift
    % Note: Using the approximation f_doppler ≈ f_carrier * (v_radial / c)
    % This is valid for v_radial << c (non-relativistic case)
    doppler_shift = f_carrier * (v_radial / c);
end