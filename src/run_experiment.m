function results = run_experiment(cfg)
% RUN_EXPERIMENT  Run a simulation and return results.
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
    dt_los      = cfg.sim.dt_los;
    dt_orbital  = cfg.sim.dt_orbital;
    total_time  = cfg.sim.sim_duration * 3600;
    min_msg_gap = cfg.sim.min_msg_interval;

    % --- Satellite scenario ---
    [sat_data, sc] = setup_scenario(cfg);  %#ok<ASGLU>

    % --- Nodes: each has id, clock, fsm ---
    n_nodes = length(cfg.nodes);
    clocks  = cell(1, n_nodes);
    fsms    = cell(1, n_nodes);
    ids     = cell(1, n_nodes);
    for k = 1:n_nodes
        ids{k}    = cfg.nodes{k}.id;
        clocks{k} = Clock(cfg.nodes{k}.ox, cfg.sim.t0 + cfg.nodes{k}.time_offset);
        fsms{k}   = cfg.nodes{k}.fsm;
    end

    % --- Channel ---
    channel = Channel(sat_data);
    for k = 1:length(cfg.channel_effects)
        channel = channel.add_effect(cfg.channel_effects{k});
    end

    % --- Pre-allocate logs ---
    max_steps = ceil(total_time / dt_los) + 1000;
    log = preallocate_log(max_steps, n_nodes);

    % --- Message queue ---
    queue = struct('to', {}, 'msg', {}, 'delivery_time', {});

    % --- Progress ---
    progress = ProgressTracker(ceil(total_time / dt_los), 'Simulation');
    progress.start();

    sim_time  = cfg.sim.t0;
    prev_time = sim_time;
    i = 1;

    while sim_time < total_time
        actual_dt = sim_time - prev_time;
        in_los    = logical(sat_data.los_flag_interp(sim_time));

        if in_los
            ch = channel.compute(sim_time);

            % Advance all clocks and step all FSMs
            out_msgs = {};
            for k = 1:n_nodes
                clocks{k} = clocks{k}.advance(actual_dt);
                ts = clocks{k}.get_timestamp();
                [fsms{k}, msgs] = fsms{k}.step(ts);
                for j = 1:length(msgs)
                    msgs{j}.from = ids{k};
                end
                out_msgs = [out_msgs, msgs];  %#ok<AGROW>
            end

            % Enqueue outgoing messages
            queue = enqueue_msgs(queue, out_msgs, sim_time, ch, min_msg_gap, ids{1});

            % Deliver due messages
            if ~isempty(queue)
                due = [queue.delivery_time] <= sim_time;
                for k = find(due)
                    node_idx = find(strcmp(ids, queue(k).to), 1);
                    if ~isempty(node_idx)
                        ts = clocks{node_idx}.get_timestamp();
                        fsms{node_idx} = fsms{node_idx}.receive(queue(k).msg, ts);
                    end
                end
                queue = queue(~due);
            end

            % Log
            log.times(i) = sim_time;
            log.los(i)   = 1;
            for k = 1:n_nodes
                log.real_offset{k}(i) = clocks{k}.get_time();
                log.real_freq{k}(i)   = clocks{k}.f;
                log.offset_est{k}(i)  = fsms{k}.last_offset;
                log.delay_est{k}(i)   = fsms{k}.last_delay;
            end
            log.fwd_delay(i)   = ch.fwd_delay;
            log.bwd_delay(i)   = ch.bwd_delay;
            log.fwd_doppler(i) = ch.fwd_doppler;
            log.bwd_doppler(i) = ch.bwd_doppler;

            % Advance time
            prev_time = sim_time;
            if ~isempty(queue)
                sim_time = min(sim_time + dt_los, min([queue.delivery_time]));
            else
                sim_time = sim_time + dt_los;
            end

        else
            for k = 1:n_nodes
                clocks{k} = clocks{k}.advance(dt_orbital);
                fsms{k}   = fsms{k}.reset();
            end
            queue = struct('to', {}, 'msg', {}, 'delivery_time', {});

            log.times(i) = sim_time;
            log.los(i)   = 0;

            prev_time = sim_time;
            sim_time  = sim_time + dt_orbital;
        end

        progress.update();
        i = i + 1;
    end

    progress.finish();

    % --- Build results ---
    % Offsets are relative to node 1 (reference)
    ref_time = log.real_offset{1}(1:i-1);
    results  = struct( ...
        'times',       log.times(1:i-1), ...
        'los',         log.los(1:i-1), ...
        'fwd_delay',   log.fwd_delay(1:i-1), ...
        'bwd_delay',   log.bwd_delay(1:i-1), ...
        'fwd_doppler', log.fwd_doppler(1:i-1), ...
        'bwd_doppler', log.bwd_doppler(1:i-1), ...
        'scenario',    cfg.scenario);

    results.nodes = cell(1, n_nodes);
    for k = 1:n_nodes
        results.nodes{k} = struct( ...
            'id',          ids{k}, ...
            'real_offset', log.real_offset{k}(1:i-1) - ref_time, ...
            'real_freq',   log.real_freq{k}(1:i-1), ...
            'offset_est',  log.offset_est{k}(1:i-1), ...
            'delay_est',   log.delay_est{k}(1:i-1));
    end

    % Convenience aliases for 2-node experiments (used by plot_experiment)
    if n_nodes == 2
        results.real_offset  = results.nodes{2}.real_offset;
        results.real_freq    = results.nodes{2}.real_freq;
        results.offset_est   = results.nodes{2}.offset_est;
        results.delay_est    = results.nodes{2}.delay_est;
    end
end


% -------------------------------------------------------------------------
function [sat_data, sc] = setup_scenario(cfg)
    start_time = cfg.sim.start_time;
    stop_time  = start_time + hours(cfg.sim.sim_duration);
    tspan      = 0 : cfg.sim.dt_orbital : cfg.sim.sim_duration * 3600;

    sc = satelliteScenario(start_time, stop_time, cfg.sim.dt_orbital);

    node1_sc = create_platform(sc, cfg.scenario.node1, cfg.sim.orbit_propagator, 'Node1');
    node2_sc = create_platform(sc, cfg.scenario.node2, cfg.sim.orbit_propagator, 'Node2');

    sat_data = precompute_satellite_data(node1_sc, node2_sc, start_time, tspan, cfg.sim.carrier_frequency);
    sat_data = filter_short_los(sat_data, cfg.sim.min_los_duration);
end


% -------------------------------------------------------------------------
function sat_data = filter_short_los(sat_data, min_duration)
    flags   = sat_data.los_flags;
    t       = sat_data.tspan;
    in_los  = false;
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
function queue = enqueue_msgs(queue, msgs, send_time, ch, min_gap, node1_id)
    for j = 1:length(msgs)
        msg = msgs{j};
        % node1→node2 = fwd delay, node2→node1 = bwd delay.
        % For >2 nodes extend this mapping as needed.
        if strcmp(msg.to, node1_id)
            delay = ch.bwd_delay;
        else
            delay = ch.fwd_delay;
        end
        queue(end+1) = struct( ...
            'to',            msg.to, ...
            'msg',           msg, ...
            'delivery_time', send_time + delay + (j-1)*min_gap);
    end
end


% -------------------------------------------------------------------------
function log = preallocate_log(n, n_nodes)
    nan_vec  = nan(n, 1);
    zero_vec = zeros(n, 1);
    log = struct( ...
        'times',       nan_vec, ...
        'los',         zero_vec, ...
        'fwd_delay',   nan_vec, ...
        'bwd_delay',   nan_vec, ...
        'fwd_doppler', nan_vec, ...
        'bwd_doppler', nan_vec);
    log.real_offset = repmat({nan(n, 1)}, 1, n_nodes);
    log.real_freq   = repmat({nan(n, 1)}, 1, n_nodes);
    log.offset_est  = repmat({nan(n, 1)}, 1, n_nodes);
    log.delay_est   = repmat({nan(n, 1)}, 1, n_nodes);
end
