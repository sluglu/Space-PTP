function off_error = simulate_ptp_gaussian(asym_delay_std, verbose)
    %% Parameters for individual sim
    sim_duration = 10;     % seconds
    dt = 0.001;            % time step
    f0 = 125e6;
    t0 = 0;
    sync_interval = 1;
    delay_a = 10e-3;
    min_msg_interval = 1e-3;
    
    %% Noise profiles
    ideal_noise_profile = NoiseProfile();
    
    %% Initialize clocks    
    clock_master = WRClock(f0, t0, ideal_noise_profile);
    clock_slave  = WRClock(f0, t0, ideal_noise_profile);
    
    %% Create nodes
    master = MasterNode(clock_master, MasterFSM(sync_interval,verbose));
    slave  = SlaveNode(clock_slave, SlaveFSM(verbose));
    
    %% Pre-allocate arrays
    max_steps = ceil(sim_duration / dt) + 1000; % Extra buffer for variable timesteps
    times = zeros(max_steps, 1);
    ptp_offset_log = nan(max_steps, 1);
    real_offset = zeros(max_steps, 1);
    
    %% Message queue
    msg_queue = cell(100, 3); % [target, msg, delivery_time] - pre-allocate
    queue_size = 0;
    queue_capacity = 100;
    
    %% Simulation loop
    sim_time = t0;
    i = 1;
    
    while sim_time < sim_duration && i <= max_steps
        times(i) = sim_time;
        actual_dt = times(max(i,1)) - times(max(i-1,1));
        
        % Step master and slave nodes
        [master, master_msgs] = master.step(actual_dt);
        [slave, slave_msgs] = slave.step(actual_dt);
        
        % Pre-calculate delay once per iteration
        delay = delay_a + randn * asym_delay_std;
        
        % Enqueue messages from master
        for j = 1:length(master_msgs)
            queue_size = queue_size + 1;
            if queue_size > queue_capacity
                % Expand queue if needed
                queue_capacity = queue_capacity * 2;
                temp_queue = cell(queue_capacity, 3);
                temp_queue(1:queue_size-1, :) = msg_queue(1:queue_size-1, :);
                msg_queue = temp_queue;
            end
            msg_queue{queue_size, 1} = 'slave';
            msg_queue{queue_size, 2} = master_msgs{j};
            msg_queue{queue_size, 3} = sim_time + delay + min_msg_interval*j;
        end
        
        % Enqueue messages from slave
        for j = 1:length(slave_msgs)
            queue_size = queue_size + 1;
            if queue_size > queue_capacity
                % Expand queue if needed
                queue_capacity = queue_capacity * 2;
                temp_queue = cell(queue_capacity, 3);
                temp_queue(1:queue_size-1, :) = msg_queue(1:queue_size-1, :);
                msg_queue = temp_queue;
            end
            msg_queue{queue_size, 1} = 'master';
            msg_queue{queue_size, 2} = slave_msgs{j};
            msg_queue{queue_size, 3} = sim_time + delay + min_msg_interval*j;
        end
        
        % Deliver messages whose time has come
        if queue_size > 0
            % Find messages to deliver
            delivery_times = [msg_queue{1:queue_size, 3}];
            to_deliver = delivery_times <= sim_time;
            
            % Process deliveries
            for j = find(to_deliver)
                if strcmp(msg_queue{j, 1}, 'master')
                    master = master.receive(msg_queue{j, 2});
                else
                    slave = slave.receive(msg_queue{j, 2});
                end
            end
            
            % Remove delivered messages
            if any(to_deliver)
                keep_indices = find(~to_deliver);
                for k = 1:length(keep_indices)
                    msg_queue(k, :) = msg_queue(keep_indices(k), :);
                end
                queue_size = length(keep_indices);
            end
        end
        
        % Log data
        [ptp_offset_log(i), ~] = slave.get_ptp_estimate();
        
        % Calculate real offset between clocks
        master_time = master.get_time();
        slave_time = slave.get_time();
        real_offset(i) = slave_time - master_time;
        
        % Determine next simulation time
        if queue_size > 0
            next_msg_time = min([msg_queue{1:queue_size, 3}]);
            sim_time = min(sim_time + dt, next_msg_time);
        else
            sim_time = sim_time + dt;
        end
        
        i = i + 1;
    end

    off_error = real_offset - ptp_offset_log;
    off_error = off_error(~isnan(off_error));
end