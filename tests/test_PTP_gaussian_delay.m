% TEST_PTP_GAUSSIAN_DELAY
% Validates PTP offset estimation sensitivity to asymmetric propagation delay.
%
% What is tested:
%   1. Error scales linearly with delay asymmetry std in log-log.
%      Pass: log-log slope within 0.15 of 1.0.
%   2. Amplitude matches the theoretical factor of 0.5.
%      Pass: empirical / (0.5 · σ_asym) in [0.3, 3.0] at the sweep midpoint.
%
% Servo is disabled to isolate raw estimation sensitivity.
% Theoretical model: E[|offset_error|] ≈ σ_asym / 2.

clear; clc; close all;

%% Setup
asym_delay_std = logspace(-12, -2, 60);
N              = length(asym_delay_std);
off_error_mean = nan(N, 1);

%% Run
progress = ProgressTracker(N, 'test_PTP_gaussian_delay');
progress.start();

dq = parallel.pool.DataQueue;
afterEach(dq, @(~) progress.update());

parfor i = 1:N
    off_error_mean(i) = run_sweep(asym_delay_std(i));
    send(dq, i);
end
progress.finish();

%% Assertions
fprintf('\n=== PTP Gaussian Delay ===\n');

valid = ~isnan(off_error_mean) & off_error_mean > 0;
assert(sum(valid) > 10, 'Too few valid sweep points (%d) to fit slope.', sum(valid));

p     = polyfit(log10(asym_delay_std(valid)), log10(off_error_mean(valid)), 1);
slope = p(1);
fprintf('  Log-log slope : %.3f  (expected 1.0, tolerance ±0.15)\n', slope);
assert(abs(slope - 1.0) < 0.15, 'Slope %.3f deviates from 1.0 by more than 0.15.', slope);
fprintf('  PASS\n');

valid_idx    = find(valid);
mid          = valid_idx(max(1, floor(end/2)));
amp_ratio    = off_error_mean(mid) / (0.5 * asym_delay_std(mid));
fprintf('  Amplitude ratio : %.2f  (expected 1.0, range [0.3, 3.0])\n', amp_ratio);
assert(amp_ratio > 0.3 && amp_ratio < 3.0, 'Amplitude ratio %.2f outside [0.3, 3.0].', amp_ratio);
fprintf('  PASS\n\n');

%% Plots
figure('Name', 'PTP Gaussian Delay Sensitivity', 'Position', [100 100 900 500]);
loglog(asym_delay_std(valid), off_error_mean(valid), 'b-o', ...
       'LineWidth', 2, 'MarkerFaceColor', 'b', 'DisplayName', 'Simulation');
hold on; grid on;
loglog(asym_delay_std(valid), 0.5*asym_delay_std(valid), 'r--', ...
       'LineWidth', 1.5, 'DisplayName', 'Theory: 0.5·\sigma_{asym}');
loglog(asym_delay_std(valid), 10.^polyval(p, log10(asym_delay_std(valid))), 'g--', ...
       'LineWidth', 1.5, 'DisplayName', sprintf('Fit (slope = %.2f)', slope));
xlabel('\sigma_{asym} (s)');
ylabel('Mean |offset error| (s)');
title('PTP offset error vs delay asymmetry — servo OFF');
legend('Location', 'best');
sgtitle('PTP Gaussian Delay Sensitivity', 'FontSize', 13, 'FontWeight', 'bold');


%% -----------------------------------------------------------------------
function err_mean = run_sweep(asym_std)
    sim_duration  = 30;
    dt            = 0.001;
    sync_interval = 1;
    base_delay    = 10e-3;
    min_gap       = 1e-6;

    nodes        = protocol_ptp(ox_perfect(0), ox_perfect(0), ...
                       'sync_interval', sync_interval, 'servo_enabled', false);
    master_clock = nodes{1}.clock;  master_fsm = nodes{1}.fsm;
    slave_clock  = nodes{2}.clock;  slave_fsm  = nodes{2}.fsm;

    queue      = struct('to', {}, 'msg', {}, 'delivery_time', {});
    max_steps  = ceil(sim_duration/dt) + 1000;
    offset_log = nan(max_steps, 1);
    real_log   = nan(max_steps, 1);
    sim_time   = 0;  prev_time = 0;  i = 1;

    while sim_time < sim_duration && i <= max_steps
        actual_dt = sim_time - prev_time;

        master_clock = master_clock.advance(actual_dt);
        [master_fsm, master_msgs] = master_fsm.step(master_clock.get_timestamp());
        master_clock.servo_y = master_fsm.servo_y;

        slave_clock = slave_clock.advance(actual_dt);
        [slave_fsm, slave_msgs] = slave_fsm.step(slave_clock.get_timestamp());
        slave_clock.servo_y = slave_fsm.servo_y;

        fwd = base_delay + randn * asym_std;
        bwd = base_delay + randn * asym_std;

        for j = 1:length(master_msgs)
            master_msgs{j}.from = 'master';
            queue(end+1) = struct('to', 'slave', 'msg', master_msgs{j}, ...
                'delivery_time', sim_time + fwd + (j-1)*min_gap);
        end
        for j = 1:length(slave_msgs)
            slave_msgs{j}.from = 'slave';
            queue(end+1) = struct('to', 'master', 'msg', slave_msgs{j}, ...
                'delivery_time', sim_time + bwd + (j-1)*min_gap);
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

        offset_log(i) = slave_fsm.last_offset;
        real_log(i)   = slave_clock.get_time() - master_clock.get_time();

        prev_time = sim_time;
        if ~isempty(queue)
            sim_time = min(sim_time + dt, min([queue.delivery_time]));
        else
            sim_time = sim_time + dt;
        end
        i = i + 1;
    end

    valid = ~isnan(offset_log(1:i-1));
    if sum(valid) < 3; err_mean = NaN; return; end
    err_mean = mean(abs(real_log(valid) - offset_log(valid)));
end
