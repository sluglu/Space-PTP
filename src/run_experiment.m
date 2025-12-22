function results = run_experiment(cfg)
    exp_name = cfg.exp.name;
    
    out_dir = fullfile(cfg.exp.root);
    mkdir(out_dir)
    
    filename = sprintf("%s.mat", exp_name);
    filepath = fullfile(out_dir, filename);
    
    fprintf("Simulating: %s", cfg.exp.name)
    
    results = simulate_ptp_orbital(cfg);
    

    results.meta.exp_name  = strrep(exp_name,'_',' ');
    results.meta.timestamp = datetime("now");
    results.meta.cfg = cfg;
    
    save(filepath, "-fromstruct", results)
    
    fprintf("Saved → %s\n\n", filepath)
end


function [results] = simulate_ptp_orbital(cfg)
    % Extract sim parameters
    start_time = cfg.sim.start_time;
    t0 = cfg.sim.t0;
    dt_ptp = cfg.sim.dt_ptp;
    dt_orbital = cfg.sim.dt_orbital;
    sim_duration = cfg.sim.sim_duration;
    min_los_duration = cfg.sim.min_los_duration;
    orbit_propagator = cfg.sim.orbit_propagator;
    use_interpolation = cfg.sim.use_interpolation;
    carrier_frequency = cfg.sim.carrier_frequency;

    % Extract ptp parameters
    sync_interval = cfg.ptp.sync_interval;
    initial_time_offset = cfg.ptp.initial_time_offset;
    min_msg_interval = cfg.ptp.min_msg_interval;
    verbose = cfg.ptp.verbose;


    % Extract oscillators parameters
    master_f0 = cfg.master_ox.f0;
    slave_f0 = cfg.slave_ox.f0;
    master_noise_profile = cfg.master_ox.np;
    slave_noise_profile = cfg.slave_ox.np;
    
    % Create satellite scenario
    stop_time  = start_time + hours(sim_duration);
    % IMPORTANT: Use dt_orbital as SampleTime for the scenario
    sc = satelliteScenario(start_time, stop_time, dt_orbital);

    % Extract orbital scenario parameters (Keplerian elements and long/lat)
    % and add satellites with specified orbital elements
    name = cfg.scenario.name;

    master_sc = cfg.scenario.master;
    if max(size(master_sc)) < 3
        lat = master_sc{1}; long = master_sc{2};
        master_sc = groundStation(sc, lat, long,"Name", "Master");
    else
        a = master_sc{1};    e = master_sc{2};    i = master_sc{3};
        raan = master_sc{4}; argp = master_sc{5}; ta = master_sc{6};
        master_sc = satellite(sc, a, e, i, raan, argp, ta, ...
                    'OrbitPropagator', orbit_propagator, 'Name', 'Master');
    end

    slave_sc = cfg.scenario.slave;
    if max(size(slave_sc)) < 3
        lat = slave_sc{1}; long = slave_sc{2};
        slave_sc = groundStation(sc,lat, long,"Name", "Slave");
    else
        a = slave_sc{1};    e = slave_sc{2};    i = slave_sc{3};
        raan = slave_sc{4}; argp = slave_sc{5}; ta = slave_sc{6};
        slave_sc = satellite(sc, a, e, i, raan, argp, ta, ...
                    'OrbitPropagator', orbit_propagator, 'Name', 'Slave');
    end
    
    % Initialize PTP components
    master_ox = WRClock(master_f0, t0, master_noise_profile);
    slave_ox = WRClock(slave_f0, t0 + initial_time_offset, slave_noise_profile);
    
    master_node = MasterNode(master_ox, MasterFSM(sync_interval, verbose));
    slave_node = SlaveNode(slave_ox, SlaveFSM(verbose));

    % Generate time span and pre-compute all satellite data in batch
    tspan = 0:dt_orbital:sim_duration*3600;
    fprintf('Main simulation will run from %.1f to %.1f seconds\n', tspan(1), tspan(end));
    
    sat_data = precompute_satellite_data(master_sc, slave_sc, start_time, tspan, carrier_frequency);
    
    % Use satellite data for LOS flags (already computed in sat_data)
    los_flags = sat_data.los_flags;
    
    % Compute LOS intervals from the satellite data
    los_intervals = [];
    in_los = false;
    t_start = NaN;
    
    for k = 1:length(sat_data.tspan)
        if sat_data.los_flags(k) && ~in_los
            t_start = sat_data.tspan(k);
            in_los = true;
        elseif ~sat_data.los_flags(k) && in_los
            t_end = sat_data.tspan(k-1);
            los_intervals = [los_intervals; t_start, t_end];
            in_los = false;
        end
    end
    if in_los
        los_intervals = [los_intervals; t_start, sat_data.tspan(end)];
    end
    
    % Interpolate los_flags to match tspan resolution if needed
    if length(sat_data.tspan) ~= length(tspan)
        fprintf('Interpolating LOS flags to match simulation resolution...\n');
        los_flags = interp1(sat_data.tspan, double(sat_data.los_flags), tspan, 'nearest', 0);
        los_flags = logical(los_flags);
    end
    
    % Filter LOS intervals by minimum duration
    valid_intervals = [];
    for i = 1:size(los_intervals,1)
        duration = los_intervals(i,2) - los_intervals(i,1);
        if duration >= min_los_duration
            valid_intervals = [valid_intervals; los_intervals(i,:)];
        end
    end
    
    if isempty(valid_intervals)
        error('No LOS intervals meet minimum duration requirement of %.1f seconds', min_los_duration);
    end
    
    fprintf('Found %.0f valid LOS intervals (>= %.1f s duration)\n', size(valid_intervals,1), min_los_duration);

    % Pre-allocate arrays for entire simulation
    total_duration = sim_duration * 3600;
    max_steps = ceil(total_duration / dt_ptp) + 1000;
    
    times = nan(max_steps, 1);
    ptp_offset_log = nan(max_steps, 1);
    ptp_delay_log = nan(max_steps, 1);
    ptp_rt_delay_log = nan(max_steps, 1);
    real_offset = nan(max_steps, 1);
    real_freq_shift = nan(max_steps, 1);
    forward_propagation_delays = nan(max_steps, 1);
    backward_propagation_delays = nan(max_steps, 1);
    forward_doppler_shifts = nan(max_steps, 1);
    backward_doppler_shifts = nan(max_steps, 1);
    los_status = zeros(max_steps, 1);
    
    % Message queue
    msg_queue = cell(100, 3);
    queue_size = 0;
    queue_capacity = 100;
    
    % Progress tracking
    total_los_duration = sum(valid_intervals(:,2) - valid_intervals(:,1));
    current_interval = 1;
    processed_los_duration = 0;
    
    % Simulation loop
    sim_time = t0;
    i = 1;
    tic;
    
    while sim_time < total_duration
        times(i) = sim_time;
        actual_dt = times(max(i,1)) - times(max(i-1,1));

        % Determine LOS status
        los_idx = find(tspan <= sim_time, 1, 'last');
        if isempty(los_idx) 
            los_idx = 1; 
        end
        if los_idx > length(los_flags)
            los_idx = length(los_flags); 
        end
        los_status(i) = los_flags(los_idx);
        
        % Calculate real clock offset 
        master_time = master_node.get_time();
        slave_time = slave_node.get_time();
        real_offset(i) = slave_time - master_time;
        real_freq_shift(i) = slave_node.get_freq() - master_node.get_freq();
        
        if los_status(i)
            if use_interpolation
                % Use pre-computed satellite data via interpolation
                forward_propagation_delays(i) = sat_data.forward_delay_interp(sim_time);
                backward_propagation_delays(i) = sat_data.backward_delay_interp(sim_time);
                forward_doppler_shifts(i) = sat_data.forward_doppler_interp(sim_time);
                backward_doppler_shifts(i) = sat_data.backward_doppler_interp(sim_time);
            else
                % Convert current sim_time to a datetime object
                current_dt = startTime + seconds(sim_time);
                
                % Compute exact delays for this specific instant
                forward_propagation_delays(i) = latency(master_sc, slave_sc, current_dt);
                backward_propagation_delays(i) = latency(slave_sc, master_sc, current_dt);
                forward_doppler_shifts(i) = dopplershift(master_sc, slave_sc, current_dt, Frequency=carrier_frequency);
                backward_doppler_shifts(i) = dopplershift(slave_sc, master_sc, current_dt, Frequency=carrier_frequency);
            end


            % PTP operation during LOS
            [master_node, master_msgs] = master_node.step(actual_dt);       
            [slave_node, slave_msgs] = slave_node.step(actual_dt);
            
            % Enqueue messages with propagation delay
            for j = 1:length(master_msgs)
                queue_size = queue_size + 1;
                if queue_size > queue_capacity
                    queue_capacity = queue_capacity * 2;
                    temp_queue = cell(queue_capacity, 3);
                    temp_queue(1:queue_size-1, :) = msg_queue(1:queue_size-1, :);
                    msg_queue = temp_queue;
                end
                % Compute message timing
                if j == 1
                    prop = forward_propagation_delays(i);
                else
                    if use_interpolation
                        prop = sat_data.forward_delay_interp(sim_time + (j-1)*min_msg_interval);
                    else
                        current_dt = startTime + seconds(sim_time + (j-1)*min_msg_interval);
                        prop = latency(master_sc, slave_sc, current_dt);
                    end
                end
                msg_queue{queue_size, 1} = 'slave';
                msg_queue{queue_size, 2} = master_msgs{j};
                msg_queue{queue_size, 3} = sim_time + prop + (j-1)*min_msg_interval;
            end
            
            for j = 1:length(slave_msgs)
                queue_size = queue_size + 1;
                if queue_size > queue_capacity
                    queue_capacity = queue_capacity * 2;
                    temp_queue = cell(queue_capacity, 3);
                    temp_queue(1:queue_size-1, :) = msg_queue(1:queue_size-1, :);
                    msg_queue = temp_queue;
                end
                % Compute message timing
                if j == 1
                    prop = backward_propagation_delays(i);
                else
                    if use_interpolation
                        prop = sat_data.backward_delay_interp(sim_time + (j-1)*min_msg_interval);
                    else
                        current_dt = startTime + seconds(sim_time + (j-1)*min_msg_interval);
                        prop = latency(slave_sc, master_sc, current_dt);
                    end
                    
                end
                msg_queue{queue_size, 1} = 'master';
                msg_queue{queue_size, 2} = slave_msgs{j};
                msg_queue{queue_size, 3} = sim_time + prop + (j-1)*min_msg_interval;
            end
            
            % Deliver messages
            if queue_size > 0
                delivery_times = [msg_queue{1:queue_size, 3}];
                to_deliver = delivery_times <= sim_time;
                
                for j = find(to_deliver)
                    if strcmp(msg_queue{j, 1}, 'master')
                        master_node = master_node.receive(msg_queue{j, 2});
                    else
                        slave_node = slave_node.receive(msg_queue{j, 2});
                    end
                end
                
                if any(to_deliver)
                    keep_indices = find(~to_deliver);
                    for k = 1:length(keep_indices)
                        msg_queue(k, :) = msg_queue(keep_indices(k), :);
                    end
                    queue_size = length(keep_indices);
                end
            end
            
            % Log PTP offset and delay
            [ptp_offset_log(i), ptp_delay_log(i)] = slave_node.get_ptp_estimate();
            ptp_rt_delay_log(i) = slave_node.get_ptp_rt_delay();

            % Determine next simulation time
            if queue_size > 0
                next_msg_time = min([msg_queue{1:queue_size, 3}]);
                sim_time = min(sim_time + dt_ptp, next_msg_time);
            else
                sim_time = sim_time + dt_ptp;
            end
            
            % Progress tracking
            if current_interval <= size(valid_intervals, 1)
                if sim_time >= valid_intervals(current_interval, 1) && sim_time <= valid_intervals(current_interval, 2)
                    interval_duration = valid_intervals(current_interval, 2) - valid_intervals(current_interval, 1);
                    interval_progress = min(sim_time - valid_intervals(current_interval, 1), interval_duration);
                    progress_percent = 100 * (processed_los_duration + interval_progress) / total_los_duration;
                    
                    if mod(i, 10000) == 0
                        fprintf('  Progress: %.1f%% (Interval %d/%d, %.1f min)\n', ...
                            progress_percent, current_interval, size(valid_intervals, 1), sim_time/60);
                    end
                elseif sim_time > valid_intervals(current_interval, 2)
                    processed_los_duration = processed_los_duration + ...
                        (valid_intervals(current_interval, 2) - valid_intervals(current_interval, 1));
                    current_interval = current_interval + 1;
                end
            end
        else
            % No LOS - advance with orbital time step
            master_node = master_node.advance_time(dt_orbital);
            slave_node = slave_node.advance_time(dt_orbital);
            slave_node = slave_node.reset_ptp_estimate();
            queue_size = 0;
            sim_time = sim_time + dt_orbital;
            
            if mod(i, 1000) == 0
                fprintf('  No-LOS period: %.1f min\n', sim_time/60);
            end
        end
        
        i = i + 1;
    end
    
    elapsed_time = toc;
    fprintf('Simulation completed in %.2f seconds\n', elapsed_time);
    
    % Prepare results
    results = struct();
    
    results.times = times;
    results.ptp_offset = ptp_offset_log;
    results.ptp_delay = ptp_delay_log;
    results.ptp_rt_delay = ptp_rt_delay_log;
    results.real_offset = real_offset;
    results.real_freq_shift = real_freq_shift;
    results.forward_propagation_delays = forward_propagation_delays;
    results.backward_propagation_delays = backward_propagation_delays;
    results.forward_doppler_shifts = forward_doppler_shifts;
    results.backward_doppler_shifts = backward_doppler_shifts;
    results.los_status = los_status;
    results.master_sc = master_sc;
    results.slave_sc = slave_sc;
    results.scenario = sc;
    results.master_node = master_node;
    results.slave_node = slave_node;
    %results.los_intervals = valid_intervals;
    %results.los_flags = los_flags;
    %results.total_duration = total_duration;
    %results.tspan = tspan;
    %results.startTime = startTime;
end