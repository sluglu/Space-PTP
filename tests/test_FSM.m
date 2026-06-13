clear; clc; close all;

%% Parameters
sim_duration  = 10;
dt            = 0.001;
f0            = 125e6;
t0            = 0;
sync_interval = 1;
delay         = 10e-3;
dtx           = 2e-3;
drx           = 1e-3;

%% Clocks (perfect oscillators)
master_clock = Clock(struct('f0', f0), t0);
slave_clock  = Clock(struct('f0', f0, 'h', [8e-24, 1e-27, 1e-28, 4e-32, 2e-34]), t0);

%% FSMs
master_fsm = MasterFSM(sync_interval, true);
slave_fsm  = SlaveFSM(true);

%% Message queue
queue = struct('to', {}, 'msg', {}, 'delivery_time', {});

times          = [];
ptp_delay_log  = [];
ptp_offset_log = [];
real_offset    = [];
slave_freq_log = [];

%% Progress
progress = ProgressTracker(ceil(sim_duration/dt), 'test_FSM');
progress.start();

%% Simulation loop
sim_time  = t0;
prev_time = sim_time;
i = 1;

while sim_time < sim_duration
    times(i)  = sim_time;
    actual_dt = sim_time - prev_time;

    master_clock = master_clock.advance(actual_dt);
    [master_fsm, master_msgs] = master_fsm.step(master_clock.get_timestamp());

    slave_clock = slave_clock.advance(actual_dt);
    [slave_fsm, slave_msgs]   = slave_fsm.step(slave_clock.get_timestamp());

    for j = 1:length(master_msgs)
        queue(end+1) = struct('to', 'slave',  'msg', master_msgs{j}, ...
                              'delivery_time', sim_time + delay + drx + dtx*j);
    end
    for j = 1:length(slave_msgs)
        queue(end+1) = struct('to', 'master', 'msg', slave_msgs{j}, ...
                              'delivery_time', sim_time + delay + drx + dtx*j);
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

    slave_freq_log(i)  = slave_clock.f;
    ptp_offset_log(i)  = slave_fsm.last_offset;
    ptp_delay_log(i)   = slave_fsm.last_delay;
    real_offset(i)     = slave_clock.get_time() - master_clock.get_time();

    prev_time = sim_time;
    if ~isempty(queue)
        sim_time = min(sim_time + dt, min([queue.delivery_time]));
    else
        sim_time = sim_time + dt;
    end

    progress.update();
    i = i + 1;
end

progress.finish();

%% Plot
figure('Name', 'PTP Synchronization Analysis', 'Position', [0 0 1000 800]);

subplot(2,3,1);
plot(times, times, 'b-', times, times + real_offset, 'r--', 'LineWidth', 1.5);
xlabel('Simulation Time (s)'); ylabel('Clock Time (s)');
title('Clock Time Evolution');
legend('Master', 'Slave', 'Location', 'best'); grid on;

subplot(2,3,[2 3]);
plot(times, ptp_offset_log, 'g-', times, real_offset, 'r-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Offset (s)');
title('PTP vs Real Offset');
legend('PTP Estimation', 'Real'); grid on;

subplot(2,3,4);
plot(times, slave_freq_log - f0, 'b-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Frequency Error (Hz)');
title('Frequency Error'); grid on;

subplot(2,3,5);
plot(times, ptp_delay_log*1e3, 'c-', ...
     times, (delay+drx+dtx)*1e3*ones(size(times)), 'k--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Delay (ms)');
title('PTP Delay Measurement');
legend('Measured', 'Expected', 'Location', 'best'); grid on;

subplot(2,3,6);
plot(times, real_offset - ptp_offset_log, 'r-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Error (s)');
title('PTP Offset Error'); grid on;

fprintf('\n--- Parameters ---\n');
fprintf('Sync interval : %.3f s\n',  sync_interval);
fprintf('Network delay : %.3f ms\n', delay*1e3);
fprintf('TX delay      : %.3f ms\n', dtx*1e3);
fprintf('RX delay      : %.3f ms\n', drx*1e3);
