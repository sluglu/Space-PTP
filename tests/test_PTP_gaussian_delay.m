% TEST_PTP_GAUSSIAN_DELAY
% Sweeps asymmetric delay standard deviation and measures PTP offset error.
%
% What is tested:
%   The PTP offset estimation error should grow proportionally with delay
%   asymmetry std.  In the log-log domain the slope should be ≈ 1.0.
%
% Servo is disabled so we isolate the raw estimation sensitivity.
% The slope assertion validates the fundamental PTP error model:
%   E[offset_error] ≈ σ_asym / 2  (factor of 0.5 from the two-way average).

clear; clc; close all;

%% Sweep parameters
asym_delay_std = logspace(-12, -2, 60);
N              = length(asym_delay_std);
off_error_mean = nan(N, 1);

progress = ProgressTracker(N, 'test_PTP_gaussian_delay');
progress.start();

dq = parallel.pool.DataQueue;
afterEach(dq, @(~) progress.update());

parfor i = 1:N
    off_error_mean(i) = run_ptp_sweep(asym_delay_std(i));
    send(dq, i);
end
progress.finish();

%% Assertions
valid = ~isnan(off_error_mean) & off_error_mean > 0;
assert(sum(valid) > 10, 'Too few valid sweep points to fit slope.');

p = polyfit(log10(asym_delay_std(valid)), log10(off_error_mean(valid)), 1);
slope = p(1);

fprintf('\n=== PTP Gaussian Delay Sensitivity ===\n');
fprintf('  Log-log slope: %.3f (expected ≈ 1.0)\n', slope);
assert(abs(slope - 1.0) < 0.15, ...
    'Slope %.3f deviates from expected 1.0 by more than 0.15.', slope);
fprintf('  Slope check: PASS\n');

% At the midpoint of the valid sweep, verify the scaling factor is ~0.5
valid_idx = find(valid);
mid       = valid_idx(max(1, floor(end/2)));   % median valid index, always in-bounds
expected_mid = 0.5 * asym_delay_std(mid);
ratio = off_error_mean(mid) / expected_mid;
fprintf('  Amplitude ratio (empirical / 0.5·σ_asym): %.2f (expected ≈ 1.0)\n', ratio);
assert(ratio > 0.3 && ratio < 3.0, ...
    'Amplitude ratio %.2f outside [0.3, 3.0]; scaling constant is wrong.', ratio);
fprintf('  Amplitude check: PASS\n');

%% Plot
figure('Name', 'PTP Gaussian Delay Sensitivity', 'Position', [100 100 900 500]);
loglog(asym_delay_std(valid), off_error_mean(valid), 'b-o', ...
       'LineWidth', 2, 'MarkerFaceColor', 'b', 'DisplayName', 'Simulation');
hold on; grid on;
loglog(asym_delay_std(valid), 0.5*asym_delay_std(valid), 'k--', ...
       'LineWidth', 1.5, 'DisplayName', 'Theory: 0.5·\sigma_{asym}');
loglog(asym_delay_std(valid), ...
       10.^polyval(p, log10(asym_delay_std(valid))), 'r--', ...
       'LineWidth', 1.5, 'DisplayName', sprintf('Fit (slope=%.2f)', slope));
xlabel('Asymmetric delay std \sigma_{asym} [s]');
ylabel('Mean |offset error| [s]');
title('PTP offset error vs delay asymmetry — servo OFF');
legend('Location','best');


%% -----------------------------------------------------------------------
function err_mean = run_ptp_sweep(asym_std)
    sim_duration  = 30;
    dt            = 0.001;
    sync_interval = 1;
    base_delay    = 10e-3;
    min_msg_gap   = 1e-6;
    f0            = 125e6;

    master_clock = Clock(struct('f0', f0), 0);
    slave_clock  = Clock(struct('f0', f0), 0);
    master_fsm   = PTPMasterFSM('slave', sync_interval, false);
    slave_fsm    = PTPSlaveFSM('master', struct('enabled', false), false);

    queue = struct('to', {}, 'msg', {}, 'delivery_time', {});

    max_steps      = ceil(sim_duration/dt) + 1000;
    offset_log     = nan(max_steps, 1);
    real_off_log   = nan(max_steps, 1);

    sim_time  = 0;
    prev_time = 0;
    i = 1;

    while sim_time < sim_duration && i <= max_steps
        actual_dt = sim_time - prev_time;

        master_clock = master_clock.advance(actual_dt);
        [master_fsm, master_msgs] = master_fsm.step(master_clock.get_timestamp());

        slave_clock = slave_clock.advance(actual_dt);
        [slave_fsm, slave_msgs] = slave_fsm.step(slave_clock.get_timestamp());
        slave_clock.servo_y = slave_fsm.servo_y;  % always 0 (servo disabled)

        fwd = base_delay + randn * asym_std;
        bwd = base_delay + randn * asym_std;

        for j = 1:length(master_msgs)
            master_msgs{j}.from = 'master';
            queue(end+1) = struct('to', 'slave', 'msg', master_msgs{j}, ...
                'delivery_time', sim_time + fwd + (j-1)*min_msg_gap);
        end
        for j = 1:length(slave_msgs)
            slave_msgs{j}.from = 'slave';
            queue(end+1) = struct('to', 'master', 'msg', slave_msgs{j}, ...
                'delivery_time', sim_time + bwd + (j-1)*min_msg_gap);
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

        offset_log(i)   = slave_fsm.last_offset;
        real_off_log(i) = slave_clock.get_time() - master_clock.get_time();

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
    err_mean = mean(abs(real_off_log(valid) - offset_log(valid)));
end
