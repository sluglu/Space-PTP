function [results] = simulate_ptp_orbital(sim_params, ptp_params, scenario)
    % Extract sim parameters
    dt_ptp = sim_params.dt_ptp;
    dt_orbital = sim_params.dt_orbital;
    sim_duration = sim_params.sim_duration;
    min_los_duration = sim_params.min_los_duration;

    % Extract ptp parameters
    master_f0 = ptp_params.master_f0;
    slave_f0 = ptp_params.slave_f0;
    sync_interval = ptp_params.sync_interval;
    verbose = ptp_params.verbose;
    min_msg_interval = ptp_params.min_msg_interval;
    master_noise_profile = ptp_params.master_noise_profile;
    slave_noise_profile = ptp_params.slave_noise_profile;
    t0 = ptp_params.t0;
    initial_time_offset = ptp_params.initial_time_offset;

    % Extract orbital scenario parameters
    r1_val = scenario{2}; r2_val = scenario{3};
    i1 = scenario{4};     i2 = scenario{5};
    th1 = scenario{6};    th2 = scenario{7};
    omega1 = scenario{8}; omega2 = scenario{9};
    
    params1 = struct('r', r1_val, 'i', i1, 'theta0', th1, 'RAAN', omega1);
    params2 = struct('r', r2_val, 'i', i2, 'theta0', th2, 'RAAN', omega2);
    
    % Initialize PTP components
    clock_master = WRClock(master_f0, t0, master_noise_profile);
    clock_slave = WRClock(slave_f0, t0 + initial_time_offset, slave_noise_profile);
    
    master = MasterNode(clock_master, MasterFSM(sync_interval, verbose));
    slave = SlaveNode(clock_slave, SlaveFSM(verbose));

    % Generate Orbital Functions and LOS Data
    [r1, r2] = generate_position_functions(params1, params2);
    tspan = 0:dt_orbital:sim_duration*3600;
    [los_intervals, los_flags] = compute_los_intervals(r1, r2, tspan);
    
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
    real_offset = nan(max_steps, 1);
    real_freq_shift = nan(max_steps, 1);
    forward_propagation_delays = nan(max_steps, 1);
    backward_propagation_delays = nan(max_steps, 1);
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
    
    while sim_time < total_duration && i <= max_steps
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
        master_time = master.get_time();
        slave_time = slave.get_time();
        real_offset(i) = slave_time - master_time;
        real_freq_shift(i) = slave.get_freq() - master.get_freq();
        
        if los_status(i)
            % Calculate propagation delay
            forward_propagation_delays(i)= compute_propagation_delay(r1, r2, sim_time, forward_propagation_delays(max(i-1,1)));
            backward_propagation_delays(i) = compute_propagation_delay(r2, r1, sim_time, backward_propagation_delays(max(i-1,1)));

            % PTP operation during LOS
            [master, master_msgs] = master.step(actual_dt);       
            [slave, slave_msgs] = slave.step(actual_dt);

            
            
            % Enqueue messages with propagation delay
            for j = 1:length(master_msgs)
                queue_size = queue_size + 1;
                if queue_size > queue_capacity
                    queue_capacity = queue_capacity * 2;
                    temp_queue = cell(queue_capacity, 3);
                    temp_queue(1:queue_size-1, :) = msg_queue(1:queue_size-1, :);
                    msg_queue = temp_queue;
                end
                if j == 1
                    prop = forward_propagation_delays(i);
                else
                    prop = compute_propagation_delay(r1, r2, sim_time + (j-1)*min_msg_interval, forward_propagation_delays(max(i-1,1))); % MS -> r1r2
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
                if j == 1
                    prop = backward_propagation_delays(i);
                else
                    prop = compute_propagation_delay(r2, r1, sim_time + (j-1)*min_msg_interval, backward_propagation_delays(max(i-1,1))); %SM ->r2r1
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
                        master = master.receive(msg_queue{j, 2});
                    else
                        slave = slave.receive(msg_queue{j, 2});
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
            [ptp_offset_log(i), ptp_delay_log(i)] = slave.get_ptp_estimate();

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
            master = master.advance_time(dt_orbital);
            slave = slave.advance_time(dt_orbital);
            slave = slave.reset_ptp_estimate(); % to remove abberation at start of LOS intervals
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
    results.real_offset = real_offset;
    results.real_freq_shift = real_freq_shift;
    results.forward_propagation_delays = forward_propagation_delays;
    results.backward_propagation_delays = backward_propagation_delays;
    results.los_status = los_status;
    results.los_flags = los_flags;
    results.total_duration = total_duration;
    results.tspan = tspan;
    results.r1 = r1;
    results.r2 = r2;
    results.los_intervals = valid_intervals;
    results.sim_duration = sim_duration;
    results.scenario = scenario;
end