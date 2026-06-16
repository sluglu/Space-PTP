% TEST_PTP_SERVO
% Validates the PI frequency servo in PTPSlaveFSM against three cases.
%
% Case 1 — Phase offset, servo ON
%   Slave starts 1 ms ahead (perfect matching frequency).
%   The P branch should steer the true clock offset back to zero.
%   Pass: |real_off| at end < 1 % of initial.
%
% Case 2 — Frequency offset, servo ON
%   Slave runs +10 ppb fast (no initial phase error).
%   The I branch must eliminate the steady-state frequency error.
%   Pass: rate of true offset growth < 1 ns/s after t > 80 s.
%
% Case 3 — Phase offset, servo OFF  (control)
%   Same setup as case 1 but with servo disabled.
%   True offset must remain near the initial value (no self-correction).
%   Pass: |real_off| at end > 90 % of initial.
%
% All scenarios use perfect clocks (no noise) so results are deterministic.

clear; clc; close all;

%% Shared parameters
f0            = 100e6;    % nominal frequency [Hz]
dt            = 0.01;     % simulation step [s]
sync_interval = 1;        % PTP sync period [s]
delay         = 5e-3;     % symmetric propagation delay [s]
servo_on  = struct('enabled', true,  'kp', 0.5, 'ki', 0.05, 'sync_interval', sync_interval);
servo_off = struct('enabled', false);

%% Case 1 — phase offset, servo ON
init_offset_s = 1e-3;   % slave starts 1 ms ahead
sim_dur_1     = 50;

cfg1 = struct('f0', f0, 'dt', dt, 'sim_duration', sim_dur_1, ...
              'sync_interval', sync_interval, 'delay', delay, ...
              'phase_offset', init_offset_s, 'freq_offset_rel', 0, ...
              'servo', servo_on);
[t1, est1, real1] = run_sim(cfg1);

valid1     = ~isnan(est1);
final_off1 = abs(real1(end));
ratio1     = final_off1 / init_offset_s;

fprintf('Case 1 — phase offset, servo ON\n');
fprintf('  Initial true offset : %.3f ms\n', init_offset_s*1e3);
fprintf('  Final   true offset : %.4f ms  (%.1f %% of initial)\n', final_off1*1e3, ratio1*100);
assert(ratio1 < 0.01, ...
    'Case 1 FAIL: offset did not converge (%.1f %% remaining, need < 1 %%)', ratio1*100);
fprintf('  PASS\n\n');

%% Case 2 — frequency offset, servo ON
freq_rel  = 10e-9;   % +10 ppb
sim_dur_2 = 150;

cfg2 = struct('f0', f0, 'dt', dt, 'sim_duration', sim_dur_2, ...
              'sync_interval', sync_interval, 'delay', delay, ...
              'phase_offset', 0, 'freq_offset_rel', freq_rel, ...
              'servo', servo_on);
[t2, ~, real2] = run_sim(cfg2);

% Fit a line to the true offset in the last 30 % of the run
tail_mask = t2 > 0.7 * sim_dur_2;
p = polyfit(t2(tail_mask), real2(tail_mask), 1);
residual_rate = abs(p(1));   % s/s

fprintf('Case 2 — frequency offset (+%.0f ppb), servo ON\n', freq_rel*1e9);
fprintf('  Residual drift rate : %.2e s/s  (threshold 1e-9 s/s)\n', residual_rate);
assert(residual_rate < 1e-9, ...
    'Case 2 FAIL: integrator did not remove freq error (rate %.2e s/s)', residual_rate);
fprintf('  PASS\n\n');

%% Case 3 — phase offset, servo OFF
cfg3 = struct('f0', f0, 'dt', dt, 'sim_duration', sim_dur_1, ...
              'sync_interval', sync_interval, 'delay', delay, ...
              'phase_offset', init_offset_s, 'freq_offset_rel', 0, ...
              'servo', servo_off);
[t3, ~, real3] = run_sim(cfg3);

final_off3 = abs(real3(end));
fprintf('Case 3 — phase offset, servo OFF\n');
fprintf('  Final true offset : %.3f ms  (started at %.3f ms)\n', final_off3*1e3, init_offset_s*1e3);
assert(final_off3 > 0.9 * init_offset_s, ...
    'Case 3 FAIL: offset converged without servo (%.3f ms remaining)', final_off3*1e3);
fprintf('  PASS\n\n');

%% Plots
figure('Name', 'PTP Servo Validation', 'Position', [100 100 1100 800]);

% --- Case 1 : time trace ---
subplot(2,3,1);
plot(t1, real1*1e3, 'r-', 'LineWidth', 1.5, 'DisplayName', 'True offset');
hold on;
plot(t1(valid1), est1(valid1)*1e3, 'b.', 'MarkerSize', 8, 'DisplayName', 'PTP estimate');
yline(0, 'k--');
xlabel('Time [s]'); ylabel('Offset [ms]');
title('Case 1 — Phase offset, servo ON');
legend('Location','northeast'); grid on;

% --- Case 1 : log convergence ---
subplot(2,3,4);
semilogy(t1, abs(real1)*1e3 + 1e-7, 'r-', 'LineWidth', 1.5);
yline(0.01 * init_offset_s * 1e3, 'k--', '1 % threshold', ...
      'LabelHorizontalAlignment','left', 'FontSize', 8);
xlabel('Time [s]'); ylabel('|True offset| [ms]');
title('Case 1 — Convergence (log scale)'); grid on;

% --- Case 2 : time trace ---
subplot(2,3,2);
plot(t2, real2*1e6, 'r-', 'LineWidth', 1.5);
yline(0, 'k--');
xlabel('Time [s]'); ylabel('True offset [µs]');
title('Case 2 — Freq offset (+10 ppb), servo ON'); grid on;

% --- Case 2 : tail linear fit to show residual rate ---
subplot(2,3,5);
t_tail  = t2(tail_mask);
r_tail  = real2(tail_mask);
plot(t_tail, r_tail*1e9, 'r-', 'LineWidth', 1.5, 'DisplayName', 'True offset');
hold on;
plot(t_tail, polyval(p, t_tail)*1e9, 'k--', 'LineWidth', 1.2, ...
     'DisplayName', sprintf('Fit  rate = %.1e s/s', residual_rate));
xlabel('Time [s]'); ylabel('True offset [ns]');
title('Case 2 — Steady-state residual');
legend('Location','best'); grid on;

% --- Case 3 vs Case 1 : comparison ---
subplot(2,3,[3 6]);
plot(t1, real1*1e3, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Servo ON  (case 1)');
hold on;
plot(t3, real3*1e3, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Servo OFF (case 3)');
yline(0, 'k--');
xlabel('Time [s]'); ylabel('True offset [ms]');
title('Servo ON vs OFF — same initial condition');
legend('Location','best'); grid on;

sgtitle('PTP PI Servo — True clock offset convergence', 'FontSize', 13, 'FontWeight','bold');


%% -----------------------------------------------------------------------
function [times, offset_est, real_off] = run_sim(cfg)
    ox_master = struct('f0', cfg.f0);
    ox_slave  = struct('f0', cfg.f0, 'delta_f0', cfg.freq_offset_rel * cfg.f0);

    master_clock = Clock(ox_master, 0);
    slave_clock  = Clock(ox_slave,  0);
    slave_clock.phi = 2*pi * cfg.f0 * cfg.phase_offset;   % set initial phase

    master_fsm = PTPMasterFSM('slave',  cfg.sync_interval, false);
    slave_fsm  = PTPSlaveFSM('master', cfg.servo,          false);

    queue = struct('to', {}, 'msg', {}, 'delivery_time', {});

    max_steps  = ceil(cfg.sim_duration / cfg.dt) + 1000;
    times      = nan(max_steps, 1);
    offset_est = nan(max_steps, 1);
    real_off   = nan(max_steps, 1);

    sim_time  = 0;
    prev_time = 0;
    i = 1;
    min_gap = 1e-6;

    while sim_time < cfg.sim_duration && i <= max_steps
        actual_dt = sim_time - prev_time;

        master_clock = master_clock.advance(actual_dt);
        [master_fsm, master_msgs] = master_fsm.step(master_clock.get_timestamp());
        master_clock.servo_y = master_fsm.servo_y;

        slave_clock = slave_clock.advance(actual_dt);
        [slave_fsm,  slave_msgs]  = slave_fsm.step(slave_clock.get_timestamp());
        slave_clock.servo_y = slave_fsm.servo_y;

        for j = 1:length(master_msgs)
            master_msgs{j}.from = 'master';
            queue(end+1) = struct('to','slave','msg',master_msgs{j}, ...
                'delivery_time', sim_time + cfg.delay + (j-1)*min_gap);
        end
        for j = 1:length(slave_msgs)
            slave_msgs{j}.from = 'slave';
            queue(end+1) = struct('to','master','msg',slave_msgs{j}, ...
                'delivery_time', sim_time + cfg.delay + (j-1)*min_gap);
        end

        if ~isempty(queue)
            due = [queue.delivery_time] <= sim_time;
            for k = find(due)
                if strcmp(queue(k).to,'master')
                    master_fsm = master_fsm.receive(queue(k).msg, master_clock.get_timestamp());
                else
                    slave_fsm  = slave_fsm.receive(queue(k).msg,  slave_clock.get_timestamp());
                end
            end
            queue = queue(~due);
        end

        times(i)      = sim_time;
        offset_est(i) = slave_fsm.last_offset;
        real_off(i)   = slave_clock.get_time() - master_clock.get_time();

        prev_time = sim_time;
        if ~isempty(queue)
            sim_time = min(sim_time + cfg.dt, min([queue.delivery_time]));
        else
            sim_time = sim_time + cfg.dt;
        end
        i = i + 1;
    end

    n          = i - 1;
    times      = times(1:n);
    offset_est = offset_est(1:n);
    real_off   = real_off(1:n);
end
