function results = run_experiment(cfg)
% RUN_EXPERIMENT  Run a PTP simulation and return results.
% Does NOT save to disk — call save_results(results, cfg) separately.

    fprintf('Simulating: %s\n', cfg.exp.name);
    results = simulate(cfg);
    results.meta = struct( ...
        'exp_name',  cfg.exp.name, ...
        'timestamp', datetime('now'), ...
        'cfg',       cfg);
end


% -------------------------------------------------------------------------
function results = simulate(cfg)
    dt_ptp      = cfg.sim.dt_ptp;
    dt_orbital  = cfg.sim.dt_orbital;
    total_time  = cfg.sim.sim_duration * 3600;
    min_msg_gap = cfg.ptp.min_msg_interval;

    % --- Satellite scenario and precomputed channel data ---
    [sat_data, sc] = setup_scenario(cfg);  %#ok<ASGLU>

    % --- Clocks and FSMs ---
    master_clock = Clock(cfg.master_ox, cfg.sim.t0);
    slave_clock  = Clock(cfg.slave_ox,  cfg.sim.t0 + cfg.ptp.initial_time_offset);
    master_fsm   = MasterFSM(cfg.ptp.sync_interval, cfg.ptp.verbose);
    slave_fsm    = SlaveFSM(cfg.ptp.verbose);

    % --- Channel (geometric delay by default; add effects via channel.add_effect) ---
    channel = Channel(sat_data);

    % --- Pre-allocate logs ---
    max_steps = ceil(total_time / dt_ptp) + 1000;
    log = preallocate_log(max_steps);

    % --- Message queue ---
    queue = struct('to', {}, 'msg', {}, 'delivery_time', {});

    % --- Progress ---
    progress = ProgressTracker(ceil(total_time / dt_ptp), 'Simulation');
    progress.start();

    sim_time  = cfg.sim.t0;
    prev_time = sim_time;
    i = 1;

    while sim_time < total_time
        actual_dt = sim_time - prev_time;
        in_los    = logical(sat_data.los_flag_interp(sim_time));

        if in_los
            ch = channel.compute(sim_time);

            % Advance clocks and step FSMs
            master_clock = master_clock.advance(actual_dt);
            [master_fsm, master_msgs] = master_fsm.step(master_clock.get_timestamp());

            slave_clock = slave_clock.advance(actual_dt);
            [slave_fsm, slave_msgs]   = slave_fsm.step(slave_clock.get_timestamp());

            % Enqueue outgoing messages
            queue = enqueue_msgs(queue, 'slave',  master_msgs, sim_time, ch.fwd_delay, min_msg_gap);
            queue = enqueue_msgs(queue, 'master', slave_msgs,  sim_time, ch.bwd_delay, min_msg_gap);

            % Deliver due messages
            if ~isempty(queue)
                due = [queue.delivery_time] <= sim_time;
                for k = find(due)
                    if strcmp(queue(k).to, 'master')
                        master_fsm = master_fsm.receive(queue(k).msg, master_clock.get_timestamp());
                    else
                        slave_fsm  = slave_fsm.receive(queue(k).msg,  slave_clock.get_timestamp());
                    end
                end
                queue = queue(~due);
            end

            % Log
            log.times(i)        = sim_time;
            log.los(i)          = 1;
            log.real_offset(i)  = slave_clock.get_time() - master_clock.get_time();
            log.real_freq(i)    = slave_clock.f - master_clock.f;
            log.fwd_delay(i)    = ch.fwd_delay;
            log.bwd_delay(i)    = ch.bwd_delay;
            log.fwd_doppler(i)  = ch.fwd_doppler;
            log.bwd_doppler(i)  = ch.bwd_doppler;
            log.ptp_offset(i)   = slave_fsm.last_offset;
            log.ptp_delay(i)    = slave_fsm.last_delay;
            log.ptp_rt_delay(i) = slave_fsm.last_rt_delay;

            % Advance time
            prev_time = sim_time;
            if ~isempty(queue)
                sim_time = min(sim_time + dt_ptp, min([queue.delivery_time]));
            else
                sim_time = sim_time + dt_ptp;
            end

        else
            master_clock = master_clock.advance(dt_orbital);
            slave_clock  = slave_clock.advance(dt_orbital);
            slave_fsm    = slave_fsm.reset();
            queue        = struct('to', {}, 'msg', {}, 'delivery_time', {});

            log.times(i) = sim_time;
            log.los(i)   = 0;

            prev_time = sim_time;
            sim_time  = sim_time + dt_orbital;
        end

        progress.update();
        i = i + 1;
    end

    progress.finish();

    results = struct( ...
        'times',        log.times(1:i-1), ...
        'ptp_offset',   log.ptp_offset(1:i-1), ...
        'ptp_delay',    log.ptp_delay(1:i-1), ...
        'ptp_rt_delay', log.ptp_rt_delay(1:i-1), ...
        'real_offset',  log.real_offset(1:i-1), ...
        'real_freq',    log.real_freq(1:i-1), ...
        'fwd_delay',    log.fwd_delay(1:i-1), ...
        'bwd_delay',    log.bwd_delay(1:i-1), ...
        'fwd_doppler',  log.fwd_doppler(1:i-1), ...
        'bwd_doppler',  log.bwd_doppler(1:i-1), ...
        'los',          log.los(1:i-1), ...
        'scenario',     cfg.scenario);   % orbital params, not satcom objects
end


% -------------------------------------------------------------------------
function [sat_data, sc] = setup_scenario(cfg)
    start_time = cfg.sim.start_time;
    stop_time  = start_time + hours(cfg.sim.sim_duration);
    tspan      = 0 : cfg.sim.dt_orbital : cfg.sim.sim_duration * 3600;

    sc = satelliteScenario(start_time, stop_time, cfg.sim.dt_orbital);

    master_sc = create_platform(sc, cfg.scenario.master, cfg.sim.orbit_propagator, 'Master');
    slave_sc  = create_platform(sc, cfg.scenario.slave,  cfg.sim.orbit_propagator, 'Slave');

    sat_data = precompute_satellite_data(master_sc, slave_sc, start_time, tspan, cfg.sim.carrier_frequency);
    sat_data.master_sc = master_sc;
    sat_data.slave_sc  = slave_sc;

    % Blank out LOS flags for intervals shorter than min_los_duration
    sat_data = filter_short_los(sat_data, cfg.sim.min_los_duration);
end


% -------------------------------------------------------------------------
function sat_data = filter_short_los(sat_data, min_duration)
    flags = sat_data.los_flags;
    t     = sat_data.tspan;
    in_los = false;
    t_start = NaN;

    for k = 1:length(flags)
        if flags(k) && ~in_los
            t_start = t(k);
            in_los  = true;
        elseif ~flags(k) && in_los
            if (t(k-1) - t_start) < min_duration
                flags(t >= t_start & t <= t(k-1)) = false;
            end
            in_los = false;
        end
    end
    if in_los && (t(end) - t_start) < min_duration
        flags(t >= t_start) = false;
    end

    sat_data.los_flags       = flags;
    sat_data.los_flag_interp = @(t_q) interp1(t, double(flags), t_q, 'nearest', 0);
end


% -------------------------------------------------------------------------
function platform = create_platform(sc, params, propagator, name)
    if length(params) < 3
        platform = groundStation(sc, params{1}, params{2}, 'Name', name);
    else
        platform = satellite(sc, params{1}, params{2}, params{3}, params{4}, params{5}, params{6}, ...
                             'OrbitPropagator', propagator, 'Name', name);
    end
end


% -------------------------------------------------------------------------
function queue = enqueue_msgs(queue, recipient, msgs, send_time, base_delay, min_gap)
    for j = 1:length(msgs)
        queue(end+1) = struct( ...
            'to',            recipient, ...
            'msg',           msgs{j}, ...
            'delivery_time', send_time + (j-1)*min_gap + base_delay);
    end
end


% -------------------------------------------------------------------------
function log = preallocate_log(n)
    nan_vec = nan(n, 1);
    log = struct( ...
        'times',        nan_vec, ...
        'los',          zeros(n,1), ...
        'real_offset',  nan_vec, ...
        'real_freq',    nan_vec, ...
        'fwd_delay',    nan_vec, ...
        'bwd_delay',    nan_vec, ...
        'fwd_doppler',  nan_vec, ...
        'bwd_doppler',  nan_vec, ...
        'ptp_offset',   nan_vec, ...
        'ptp_delay',    nan_vec, ...
        'ptp_rt_delay', nan_vec);
end
