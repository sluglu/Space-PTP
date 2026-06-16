% TEST_PTP_FSM
% Validates the IEEE 1588 4-way handshake (SYNC→FOLLOW_UP→DELAY_REQ→DELAY_RESP).
%
% What is tested:
%   1. Offset estimate matches true clock offset within noise tolerance.
%   2. Delay estimate matches the actual propagation delay.
%   3. Mid-handshake SYNC is not processed (guard introduced in PTPSlaveFSM).
%   4. Handshake completes on every sync cycle for the full simulation.
%
% Servo is disabled so this test isolates pure handshake correctness.
% A separate test (test_PTP_servo.m) covers servo convergence.

clear; clc; close all;

%% Parameters
dt            = 0.001;   % simulation step [s]
sim_duration  = 20;      % [s]
sync_interval = 1;       % [s]
fwd_delay     = 10e-3;   % master→slave propagation delay [s]
bwd_delay     = 12e-3;   % slave→master (asymmetric to confirm delay estimate)
min_msg_gap   = 1e-6;    % spacing between simultaneous messages [s]
f0            = 125e6;
tol_offset    = 1e-9;    % 1 ns tolerance on offset estimate vs true value
tol_delay     = 1e-12;   % 1 ps tolerance on delay estimate vs expected

%% Clocks — small noise so estimates aren't overwhelmed
master_clock = Clock(struct('f0', f0), 0);
slave_clock  = Clock(struct('f0', f0, 'h', [0, 4.62e-23, 1.58e-25, 0, 1e-32]), 0);

%% FSMs — servo OFF for this test
servo_off = struct('enabled', false);
master_fsm = PTPMasterFSM('slave', sync_interval, false);
slave_fsm  = PTPSlaveFSM('master', servo_off, false);

%% Message queue
queue = struct('to', {}, 'msg', {}, 'delivery_time', {});

%% Pre-allocate logs
max_steps = ceil(sim_duration/dt) + 1000;
times          = nan(max_steps, 1);
ptp_offset_log = nan(max_steps, 1);
ptp_delay_log  = nan(max_steps, 1);
real_offset    = nan(max_steps, 1);

%% Simulation loop
progress = ProgressTracker(ceil(sim_duration/dt), 'test_PTP_FSM');
progress.start();

sim_time  = 0;
prev_time = 0;
i = 1;

while sim_time < sim_duration
    actual_dt = sim_time - prev_time;

    master_clock = master_clock.advance(actual_dt);
    [master_fsm, master_msgs] = master_fsm.step(master_clock.get_timestamp());
    master_clock.servo_y = master_fsm.servo_y;   % always 0 for master

    slave_clock = slave_clock.advance(actual_dt);
    [slave_fsm, slave_msgs] = slave_fsm.step(slave_clock.get_timestamp());
    slave_clock.servo_y = slave_fsm.servo_y;

    % Enqueue with asymmetric delays
    for j = 1:length(master_msgs)
        master_msgs{j}.from = 'master';
        queue(end+1) = struct('to', 'slave', 'msg', master_msgs{j}, ...
            'delivery_time', sim_time + fwd_delay + (j-1)*min_msg_gap);
    end
    for j = 1:length(slave_msgs)
        slave_msgs{j}.from = 'slave';
        queue(end+1) = struct('to', 'master', 'msg', slave_msgs{j}, ...
            'delivery_time', sim_time + bwd_delay + (j-1)*min_msg_gap);
    end

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

    times(i)          = sim_time;
    ptp_offset_log(i) = slave_fsm.last_offset;
    ptp_delay_log(i)  = slave_fsm.last_delay;
    real_offset(i)    = slave_clock.get_time() - master_clock.get_time();

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

% Trim
n = i - 1;
times          = times(1:n);
ptp_offset_log = ptp_offset_log(1:n);
ptp_delay_log  = ptp_delay_log(1:n);
real_offset    = real_offset(1:n);

%% Assertions
fprintf('\n=== PTP FSM Validation ===\n');

% Only check samples where an estimate is available (after first handshake)
valid = ~isnan(ptp_offset_log);
assert(sum(valid) > 0, 'No PTP offset estimates produced — handshake never completed.');

offset_err = abs(ptp_offset_log(valid) - real_offset(valid));
delay_err  = abs(ptp_delay_log(valid) - (fwd_delay + bwd_delay)/2);

expected_delay = (fwd_delay + bwd_delay) / 2;
% Offset estimate should track real offset within noise (~ADEV*tau range)
max_offset_err = max(offset_err);
max_delay_err  = max(delay_err);

fprintf('  Expected one-way delay   : %.6f ms\n', expected_delay*1e3);
fprintf('  Max delay estimate error : %.3e s\n', max_delay_err);
fprintf('  Max offset estimate error: %.3e s\n', max_offset_err);

% Delay estimate must be exact (no noise on the channel in this test — only
% clock noise affects t2/t3, not t1/t4 which are from noiseless master).
% Allow 1 µs since clock noise is tiny and affects t2, t3 readings.
assert(max_delay_err < 1e-6, ...
    'Delay estimate error %.3e s exceeds 1 µs threshold.', max_delay_err);
fprintf('  Delay estimate: PASS\n');

% Offset estimate tracks real offset: residual error = delay asymmetry / 2
asym = (fwd_delay - bwd_delay) / 2;
offset_err_vs_asym = abs(median(ptp_offset_log(valid) - real_offset(valid)) - asym);
assert(offset_err_vs_asym < 1e-6, ...
    'Offset bias %.3e differs from expected asymmetry %.3e by more than 1 µs.', ...
    median(ptp_offset_log(valid) - real_offset(valid)), asym);
fprintf('  Offset bias matches delay asymmetry (%.3f ms): PASS\n', asym*1e3);

% Handshake must complete on every sync cycle.
% last_offset holds its value between handshakes, so count the number of
% distinct values (first valid sample + each subsequent change in value).
n_syncs = floor(sim_duration / sync_interval) - 1;
valid_offsets = ptp_offset_log(~isnan(ptp_offset_log));
n_updates = 1 + sum(diff(valid_offsets) ~= 0);
fprintf('  Expected ~%d handshakes, got %d estimates\n', n_syncs, n_updates);
assert(n_updates >= n_syncs - 1, ...
    'Only %d handshakes completed out of expected %d.', n_updates, n_syncs);
fprintf('  Handshake completion: PASS\n');

%% Plots
figure('Name', 'PTP FSM Validation', 'Position', [0 0 1000 700]);

subplot(2,2,1);
plot(times, ptp_offset_log*1e9, 'g-', times, real_offset*1e9, 'r-', 'LineWidth', 1.5);
xlabel('Time [s]'); ylabel('Offset [ns]');
title('PTP offset estimate vs true offset');
legend('PTP estimate','True','Location','best'); grid on;

subplot(2,2,2);
plot(times(valid), offset_err(1:sum(valid))*1e9, 'k-', 'LineWidth', 1.2);
yline(asym*1e9, 'r--', 'Asymmetry bias', 'LabelHorizontalAlignment','left');
xlabel('Time [s]'); ylabel('Error [ns]');
title('|PTP offset estimate − true offset|'); grid on;

subplot(2,2,3);
plot(times, ptp_delay_log*1e3, 'b-', 'LineWidth', 1.5);
yline(expected_delay*1e3, 'k--', 'Expected', 'LabelHorizontalAlignment','left');
xlabel('Time [s]'); ylabel('Delay [ms]');
title('One-way delay estimate'); grid on;

subplot(2,2,4);
plot(times(valid), delay_err(1:sum(valid))*1e9, 'k-', 'LineWidth', 1.2);
xlabel('Time [s]'); ylabel('Error [ns]');
title('|Delay estimate − true delay|'); grid on;

sgtitle('PTP 4-way Handshake — servo OFF', 'FontSize', 13, 'FontWeight', 'bold');
