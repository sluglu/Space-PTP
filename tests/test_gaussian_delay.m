% TEST_GAUSSIAN_DELAY
% Sweeps asymmetric delay standard deviation and measures mean PTP offset error.
% Validates that PTP error grows with delay asymmetry.

clear; clc; close all;

%% Parameters
asym_delay_std = logspace(-12, -2, 100);
N              = length(asym_delay_std);
off_error_mean = nan(N, 1);

progress = ProgressTracker(N, 'test_gaussian_delay');
progress.start();

dq = parallel.pool.DataQueue;
afterEach(dq, @(~) progress.update());

parfor i = 1:N
    off_error = run_ptp_with_gaussian_delay(asym_delay_std(i));
    if ~isempty(off_error)
        off_error_mean(i) = abs(mean(off_error));
    end
    send(dq, i);
end

progress.finish();

%% Plot
valid = ~isnan(off_error_mean);

figure('Position', [100 100 900 500]);
loglog(asym_delay_std(valid), off_error_mean(valid), 'b-', 'LineWidth', 2);
hold on; grid on;
xlabel('Asymmetric Delay Std (s)');
ylabel('Mean Absolute Offset Error (s)');
title('PTP Offset Error vs Delay Asymmetry');

if sum(valid) > 10
    p = polyfit(log10(asym_delay_std(valid)), log10(off_error_mean(valid)), 1);
    loglog(asym_delay_std(valid), 10.^polyval(p, log10(asym_delay_std(valid))), 'r--', 'LineWidth', 1.5);
    legend('Simulation', sprintf('Trend (slope=%.2f)', p(1)), 'Location', 'best');
end

fprintf('Offset error range: %.2e – %.2e s\n', min(off_error_mean(valid)), max(off_error_mean(valid)));


%% -----------------------------------------------------------------------
function off_error = run_ptp_with_gaussian_delay(asym_delay_std)
    sim_duration  = 10;
    dt            = 0.001;
    t0            = 0;
    sync_interval = 1;
    base_delay    = 10e-3;
    min_msg_gap   = 1e-3;

    master_clock = Clock(struct('f0', 125e6), t0);
    slave_clock  = Clock(struct('f0', 125e6), t0);
    master_fsm   = MasterFSM(sync_interval, false);
    slave_fsm    = SlaveFSM(false);

    queue = struct('to', {}, 'msg', {}, 'delivery_time', {});

    max_steps      = ceil(sim_duration / dt) + 1000;
    ptp_offset_log = nan(max_steps, 1);
    real_offset    = zeros(max_steps, 1);

    sim_time  = t0;
    prev_time = sim_time;
    i = 1;

    while sim_time < sim_duration && i <= max_steps
        actual_dt = sim_time - prev_time;

        master_clock = master_clock.advance(actual_dt);
        [master_fsm, master_msgs] = master_fsm.step(master_clock.get_timestamp());

        slave_clock = slave_clock.advance(actual_dt);
        [slave_fsm, slave_msgs]   = slave_fsm.step(slave_clock.get_timestamp());

        delay = base_delay + randn * asym_delay_std;

        for j = 1:length(master_msgs)
            queue(end+1) = struct('to', 'slave',  'msg', master_msgs{j}, ...
                                  'delivery_time', sim_time + delay + min_msg_gap*j);
        end
        for j = 1:length(slave_msgs)
            queue(end+1) = struct('to', 'master', 'msg', slave_msgs{j}, ...
                                  'delivery_time', sim_time + delay + min_msg_gap*j);
        end

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

        ptp_offset_log(i) = slave_fsm.last_offset;
        real_offset(i)    = slave_clock.get_time() - master_clock.get_time();

        prev_time = sim_time;
        if ~isempty(queue)
            sim_time = min(sim_time + dt, min([queue.delivery_time]));
        else
            sim_time = sim_time + dt;
        end
        i = i + 1;
    end

    off_error = real_offset(1:i-1) - ptp_offset_log(1:i-1);
    off_error = off_error(~isnan(off_error));
end
