% TEST_PTP_SERVO
% Validates the PI frequency servo in PTPSlaveFSM for a slave with a
% frequency offset relative to its master.
%
% What is tested:
%   1. Servo ON — I branch eliminates steady-state frequency drift.
%      Pass: residual drift rate < 1 ns/s in the last 30 % of the run.
%   2. Servo OFF — offset grows linearly without correction (control case).
%      Pass: final offset > 90 % of open-loop drift prediction.
%
% Perfect clocks (no noise) so results are deterministic.

clear; clc; close all;

%% Setup
sim_duration  = 150;
dt            = 0.01;
sync_interval = 1;
delay         = 5e-3;
freq_rel      = 10e-9;   % +10 ppb
f0            = ox_perfect().f0;

%% Run

% Case 1 — servo ON
nodes = protocol_ptp(ox_perfect(0), ox_perfect(0, 'delta_f0', freq_rel * f0), ...
            'sync_interval', sync_interval, 'servo_enabled', true, ...
            'servo_kp', 0.5, 'servo_ki', 0.05);
[t1, real1, est1] = sim_loop(nodes, sim_duration, dt, delay);

% Case 2 — servo OFF
nodes = protocol_ptp(ox_perfect(0), ox_perfect(0, 'delta_f0', freq_rel * f0), ...
            'sync_interval', sync_interval, 'servo_enabled', false);
[t2, real2, ~] = sim_loop(nodes, sim_duration, dt, delay);

%% Assertions
fprintf('\n=== PTP Servo ===\n');

tail  = t1 > 0.7 * sim_duration;
p1    = polyfit(t1(tail), real1(tail), 1);
rate1 = abs(p1(1));
fprintf('  Case 1 residual drift rate : %.2e s/s  (threshold 1e-9)\n', rate1);
assert(rate1 < 1e-9, 'Case 1 FAIL: drift rate %.2e s/s', rate1);
fprintf('  PASS\n');

expected_drift = freq_rel * sim_duration;
fprintf('  Case 2 final offset        : %.2e s  (expected > %.2e)\n', abs(real2(end)), 0.9*expected_drift);
assert(abs(real2(end)) > 0.9 * expected_drift, 'Case 2 FAIL: offset %.2e s', abs(real2(end)));
fprintf('  PASS\n\n');

%% Plots
figure('Name', 'PTP Servo Validation', 'Position', [100 100 1100 500]);

subplot(1,3,1);
valid = ~isnan(est1);
plot(t1, real1, 'r-', 'LineWidth', 1.5, 'DisplayName', 'True offset');
hold on;
plot(t1(valid), est1(valid), 'b.', 'MarkerSize', 6, 'DisplayName', 'PTP estimate');
yline(0, 'k--'); xlabel('Time (s)'); ylabel('Offset (s)');
title('Case 1 — Servo ON'); legend('Location', 'best'); grid on;

subplot(1,3,2);
t_tail = t1(tail);
plot(t_tail, real1(tail), 'r-', 'LineWidth', 1.5, 'DisplayName', 'True offset');
hold on;
plot(t_tail, polyval(p1, t_tail), 'r--', 'LineWidth', 1.2, ...
     'DisplayName', sprintf('Fit  %.1e s/s', rate1));
xlabel('Time (s)'); ylabel('Offset (s)');
title('Case 1 — Steady-state residual'); legend('Location', 'best'); grid on;

subplot(1,3,3);
plot(t1, real1, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Servo ON');
hold on;
plot(t2, real2, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Servo OFF');
yline(0, 'k--'); xlabel('Time (s)'); ylabel('Offset (s)');
title('Servo ON vs OFF'); legend('Location', 'best'); grid on;

sgtitle('PTP PI Servo — frequency offset convergence', 'FontSize', 13, 'FontWeight', 'bold');


%% -----------------------------------------------------------------------
function [times, real_off, offset_est] = sim_loop(nodes, sim_duration, dt, delay)
    master_clock = nodes{1}.clock;  master_fsm = nodes{1}.fsm;
    slave_clock  = nodes{2}.clock;  slave_fsm  = nodes{2}.fsm;

    queue      = struct('to', {}, 'msg', {}, 'delivery_time', {});
    max_steps  = ceil(sim_duration / dt) + 1000;
    times      = nan(max_steps, 1);
    real_off   = nan(max_steps, 1);
    offset_est = nan(max_steps, 1);
    sim_time   = 0;  prev_time = 0;  i = 1;

    while sim_time < sim_duration && i <= max_steps
        actual_dt = sim_time - prev_time;

        master_clock = master_clock.advance(actual_dt);
        [master_fsm, master_msgs] = master_fsm.step(master_clock.get_timestamp());
        master_clock.servo_y = master_fsm.servo_y;

        slave_clock = slave_clock.advance(actual_dt);
        [slave_fsm, slave_msgs] = slave_fsm.step(slave_clock.get_timestamp());
        slave_clock.servo_y = slave_fsm.servo_y;

        for j = 1:length(master_msgs)
            master_msgs{j}.from = 'master';
            queue(end+1) = struct('to', 'slave', 'msg', master_msgs{j}, ...
                'delivery_time', sim_time + delay + (j-1)*1e-6);
        end
        for j = 1:length(slave_msgs)
            slave_msgs{j}.from = 'slave';
            queue(end+1) = struct('to', 'master', 'msg', slave_msgs{j}, ...
                'delivery_time', sim_time + delay + (j-1)*1e-6);
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

        times(i)      = sim_time;
        real_off(i)   = slave_clock.get_time() - master_clock.get_time();
        offset_est(i) = slave_fsm.last_offset;

        prev_time = sim_time;
        if ~isempty(queue)
            sim_time = min(sim_time + dt, min([queue.delivery_time]));
        else
            sim_time = sim_time + dt;
        end
        i = i + 1;
    end

    n = i - 1;
    times = times(1:n);  real_off = real_off(1:n);  offset_est = offset_est(1:n);
end
