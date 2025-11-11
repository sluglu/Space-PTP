clear; clc; close all;

%% Parameters
sim_duration = 10;     % seconds
dt = 0.001;            % time step
f0 = 125e6;
t0 = 0;
sync_interval = 1;
delay = 10e-3;
dtx = 2e-3;
drx = 1e-3;

%% Noise profiles
params_noisy = struct(...
    'delta_f0', 0, ...
    'alpha', 0, ... 
    'power_law_coeffs', [8e-24, 1e-27, 1e-28, 4e-32, 2e-34], ...
    'timestamp_resolution', 0 ...
);

%% Initialize clocks
np_noisy = NoiseProfile(params_noisy);
np_ideal = NoiseProfile();

clock_master = WRClock(f0, t0, np_ideal);
clock_slave  = WRClock(f0, t0, np_noisy);

%% Create nodes
master = MasterNode(clock_master, MasterFSM(sync_interval, true));
slave  = SlaveNode(clock_slave, SlaveFSM(true));

%% Simulation setup
msg_queue = struct('target', {}, 'msg', {}, 'delivery_time', {});
times = [];
slave_freq_log = [];
ptp_delay_log = [];
ptp_offset_log = [];
real_offset = [];

%% Simulation loop
sim_time = t0;
i = 1;
sync_event_times = [];  % Track when sync events complete

while sim_time < sim_duration
    times(i) = sim_time;
    actual_dt = times(max(i,1)) - times(max(i-1,1));

    % Step master and slave nodes
    [master, master_msgs] = master.step(actual_dt);
    [slave, slave_msgs] = slave.step(actual_dt);

    % Check if slave just completed a sync
    if slave.just_synced()
        sync_event_times(end+1) = sim_time;
    end

    % Enqueue messages from master
    for j = 1:length(master_msgs)
        msg_queue(end+1) = struct(...
            'target', 'slave', ...
            'msg', master_msgs{j}, ...
            'delivery_time', sim_time + delay + drx + dtx*j);
    end

    % Enqueue messages from slave
    for j = 1:length(slave_msgs)
        msg_queue(end+1) = struct(...
            'target', 'master', ...
            'msg', slave_msgs{j}, ...
            'delivery_time', sim_time + delay + drx + dtx*j);
    end

    % Deliver messages whose time has come
    if ~isempty(msg_queue)
        to_deliver = [msg_queue.delivery_time] <= sim_time;
        for j = find(to_deliver)
            if strcmp(msg_queue(j).target, 'master')
                master = master.receive(msg_queue(j).msg);
            else
                slave = slave.receive(msg_queue(j).msg);
            end
        end
        % Remove delivered messages from queue
        msg_queue = msg_queue(~to_deliver);
    end

    % Log data
    slave_freq_log(i) = slave.get_freq();
    [ptp_offset_log(i), ptp_delay_log(i)] = slave.get_ptp_estimate();
    
    % Calculate real offset between clocks
    master_time = master.get_time();
    slave_time = slave.get_time();
    real_offset(i) = slave_time - master_time;
    
    % Determine next simulation time
    if ~isempty(msg_queue)
        next_msg_time = min([msg_queue.delivery_time]);
        sim_time = min(sim_time + dt, next_msg_time);
    else
        sim_time = sim_time + dt;
    end
    
    i = i + 1;
end
    
%% Plot results
figure('Name', 'PTP Synchronization Analysis', 'Position', [0 0 1000 800]);

% Plot 1: Clock Time Evolution
subplot(2,3,1);
master_time = zeros(size(times));
slave_time = zeros(size(times));
for idx = 1:length(times)
    if idx <= length(slave_freq_log)
        master_time(idx) = times(idx);  % Master is reference
        slave_time(idx) = times(idx) + real_offset(idx);
    end
end
plot(times, master_time, 'b-', 'LineWidth', 1.5);
hold on;
plot(times, slave_time, 'r--', 'LineWidth', 1.5);
xlabel('Simulation Time (s)');
ylabel('Clock Time (s)');
title('Clock Time Evolution');
legend('Master Clock', 'Slave Clock', 'Location', 'best');
grid on;

% Plot 2,3: PTP Measured Offset
subplot(2,3,[2,3]);
plot(times, ptp_offset_log, 'g-', 'LineWidth', 1.5);
hold on;
plot(times, real_offset, 'r-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Offset (s)');
title('PTP vs Real Offset');
legend("PTP Estimation", "Real");
grid on;

% Plot 4: Frequency Error
subplot(2,3,4);
plot(times, slave_freq_log - 125e6, 'b-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Frequency Error (Hz)');
title('Frequency Error');
grid on;

% Plot 5: PTP Delay Measurement
subplot(2,3,5);
plot(times, ptp_delay_log * 1e3, 'c-', 'LineWidth', 1.5);
hold on;
plot(times, (delay + drx + dtx) * 1e3 * ones(size(times)), 'k--', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Delays (s)');
title('PTP Delay Measurement');
legend('Measured', 'Expected', 'Location', 'best');
grid on;

% Plot 6: Offset Error (Real vs PTP)
subplot(2,3,6);
offset_error = real_offset - ptp_offset_log;
plot(times, offset_error, 'r-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Offset Error (s)');
title('PTP Offset Error');
grid on;

%% Additional Metrics
fprintf('\n--- System Parameters ---\n');
fprintf('Sync Interval      : %.3f s\n', sync_interval);
fprintf('Network Delay      : %.3f ms\n', delay * 1e3);
fprintf('TX Delay           : %.3f ms\n', dtx * 1e3);
fprintf('RX Delay           : %.3f ms\n', drx * 1e3);
fprintf('Total Path Delay   : %.3f ms\n', (delay + dtx + drx) * 1e3);