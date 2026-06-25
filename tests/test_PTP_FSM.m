% TEST_PTP_FSM
% Validates the PTP 4-way handshake (SYNC → FOLLOW_UP → DELAY_REQ → DELAY_RESP)
% and PI servo for two OCXO nodes over a fixed-delay channel.
%
% What is tested:
%   1. PTP exchanges complete — slave produces valid offset and delay estimates.
%      Pass: at least 10 non-NaN estimates in the run.
%   2. Delay estimate accuracy — measured one-way delay matches the channel geometry.
%      Pass: mean estimate within 10 % of (delay + drx + dtx).
%   3. Offset tracking — PTP estimate follows the true clock offset.
%      Pass: RMS tracking error < 10 µs in the second half of the run.
%
% Both nodes use realistic OCXO clocks (independent noise and drift).
% Verbose FSM output is enabled so state transitions are visible in the console.

clear; clc; close all;

%% Setup
sim_duration  = 30;
dt            = 0.001;
sync_interval = 1;
delay         = 10e-3;
dtx           = 2e-3;
drx           = 1e-3;

nodes        = protocol_ptp(ox_ocxo(0), ox_ocxo(0), 'sync_interval', sync_interval, 'verbose', true);
master_clock = nodes{1}.clock;  master_fsm = nodes{1}.fsm;
slave_clock  = nodes{2}.clock;  slave_fsm  = nodes{2}.fsm;

queue          = struct('to', {}, 'msg', {}, 'delivery_time', {});
times          = nan(ceil(sim_duration/dt)+100, 1);
ptp_delay_log  = nan(size(times));
ptp_offset_log = nan(size(times));
real_offset    = nan(size(times));
slave_freq_log = nan(size(times));

%% Run
progress = ProgressTracker(ceil(sim_duration/dt), 'test_PTP_FSM');
progress.start();

sim_time  = 0;
prev_time = 0;
i         = 1;

while sim_time < sim_duration
    actual_dt = sim_time - prev_time;

    master_clock = master_clock.advance(actual_dt);
    [master_fsm, master_msgs] = master_fsm.step(master_clock.get_timestamp());
    master_clock.servo_y = master_fsm.servo_y;

    slave_clock = slave_clock.advance(actual_dt);
    [slave_fsm, slave_msgs] = slave_fsm.step(slave_clock.get_timestamp());
    slave_clock.servo_y = slave_fsm.servo_y;

    for j = 1:length(master_msgs)
        master_msgs{j}.from = 'master';
        queue(end+1) = struct('to', 'slave',  'msg', master_msgs{j}, ...
                              'delivery_time', sim_time + delay + drx + dtx*j);
    end
    for j = 1:length(slave_msgs)
        slave_msgs{j}.from = 'slave';
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

    times(i)          = sim_time;
    ptp_delay_log(i)  = slave_fsm.last_delay;
    ptp_offset_log(i) = slave_fsm.last_offset;
    real_offset(i)    = slave_clock.get_time() - master_clock.get_time();
    slave_freq_log(i) = slave_clock.f;

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

n              = i - 1;
times          = times(1:n);
ptp_delay_log  = ptp_delay_log(1:n);
ptp_offset_log = ptp_offset_log(1:n);
real_offset    = real_offset(1:n);
slave_freq_log = slave_freq_log(1:n);

%% Assertions
fprintf('\n=== PTP FSM ===\n');

valid = ~isnan(ptp_delay_log);
fprintf('  Valid PTP exchanges : %d\n', sum(valid));
assert(sum(valid) >= 10, 'Too few valid exchanges (%d), expected >= 10.', sum(valid));
fprintf('  PASS\n');

expected_delay = delay + drx + dtx;
mean_delay     = mean(ptp_delay_log(valid));
delay_err      = abs(mean_delay - expected_delay) / expected_delay;
fprintf('  Mean delay estimate : %.4f ms  (expected %.4f ms, error %.1f %%)\n', ...
        mean_delay*1e3, expected_delay*1e3, delay_err*100);
assert(delay_err < 0.10, 'Delay estimate error %.1f %% exceeds 10 %%.', delay_err*100);
fprintf('  PASS\n');

half   = times > sim_duration/2;
err    = real_offset(half & valid) - ptp_offset_log(half & valid);
rms_err = sqrt(mean(err.^2));
fprintf('  Offset tracking RMS : %.2e s  (threshold 10 µs)\n', rms_err);
assert(rms_err < 10e-6, 'Offset tracking RMS %.2e s exceeds 10 µs.', rms_err);
fprintf('  PASS\n\n');

%% Plots
figure('Name', 'PTP FSM Validation', 'Position', [0 0 1000 800]);

subplot(2,3,1);
plot(times, times, 'b-', times, times + real_offset, 'r--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Clock time (s)');
title('Clock time evolution');
legend('Master', 'Slave', 'Location', 'best'); grid on;

subplot(2,3,[2 3]);
plot(times, ptp_offset_log, 'g-', times, real_offset, 'r-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Offset (s)');
title('PTP estimate vs true offset');
legend('PTP estimate', 'True offset', 'Location', 'best'); grid on;

subplot(2,3,4);
plot(times, slave_freq_log - slave_clock.f0, 'b-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Frequency error (Hz)');
title('Slave frequency error'); grid on;

subplot(2,3,5);
plot(times, ptp_delay_log, 'c-', 'LineWidth', 1.5, 'DisplayName', 'Measured');
hold on;
yline(expected_delay, 'r--', 'Expected', 'LabelHorizontalAlignment', 'left');
xlabel('Time (s)'); ylabel('Delay (s)');
title('PTP delay estimate');
legend('Location', 'best'); grid on;

subplot(2,3,6);
plot(times, real_offset - ptp_offset_log, 'r-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Error (s)');
title('Offset tracking error'); grid on;

sgtitle('PTP FSM — OCXO two-node handshake', 'FontSize', 13, 'FontWeight', 'bold');
