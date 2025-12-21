function [los_intervals, los_flags] = compute_los_intervals(r1, r2, tspan, dt)
    % Compute Line-of-Sight intervals and flags for satellite communication
    %
    % Inputs:
    %   r1, r2: Function handles for satellite position vectors
    %   tspan: Time vector or [t_start, t_end] range
    %   dt: Time step for LOS computation (optional if tspan is a vector)
    %
    % Outputs:
    %   los_intervals: Nx2 array of [t_start, t_end] for LOS periods
    %   los_flags: Boolean array indicating LOS at each time in tspan
    
    RE = 6371e3; % Earth radius in meters
    
    % Handle different input formats for tspan
    if length(tspan) == 2
        % tspan is [t_start, t_end], use dt
        if nargin < 4
            dt = 20; % default timestep
        end
        times_compute = tspan(1):dt:tspan(2);
        times_output = times_compute;
    else
        % tspan is already a time vector
        times_compute = tspan;
        times_output = tspan;
        dt = times_compute(2) - times_compute(1); % infer dt
    end
    
    % Compute LOS flags for computation times
    los_flags_compute = false(size(times_compute));
    for k = 1:length(times_compute)
        t = times_compute(k);
        p1 = r1(t);
        p2 = r2(t);
        d_vec = p2 - p1;
        dmin = norm(cross(d_vec, p1)) / norm(d_vec);
        los_flags_compute(k) = (dmin > RE);
    end
    
    % Detect continuous LOS intervals
    los_intervals = [];
    in_los = false;
    t_start = NaN;
    for k = 1:length(times_compute)
        if los_flags_compute(k) && ~in_los
            t_start = times_compute(k);
            in_los = true;
        elseif ~los_flags_compute(k) && in_los
            t_end = times_compute(k-1);
            los_intervals = [los_intervals; t_start, t_end];
            in_los = false;
        end
    end
    % If still in LOS at the end
    if in_los
        los_intervals = [los_intervals; t_start, times_compute(end)];
    end
    
    % Create los_flags for the output time vector
    los_flags = false(size(times_output));
    for intv = 1:size(los_intervals, 1)
        t_start = los_intervals(intv, 1);
        t_end = los_intervals(intv, 2);
        idxs = find(times_output >= t_start & times_output <= t_end);
        los_flags(idxs) = true;
    end
end