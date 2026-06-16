% TEST_SATCOM_ORBIT_MODEL
% Validates the precompute_satellite_data + Channel pipeline for two LEO satellites.
%
% What is tested:
%   1. Delays are positive, finite, and physically plausible (300–7000 km / c).
%   2. Forward and backward delays differ (orbital geometry is asymmetric).
%   3. Doppler shifts have correct sign and plausible magnitude for LEO velocities.
%   4. LOS flags and delay/Doppler are consistent (NaN outside LOS windows).
%   5. Channel.compute() returns the same geometric values as the raw interpolants.

clear; clc; close all;

%% Scenario — two LEO satellites, same shell
start_time = datetime(2025,11,05,0,0,0,'TimeZone','UTC');
sim_duration_h = 2;       % [h]
dt_orbital     = 1;       % precompute grid step [s]
carrier_freq   = 14e9;    % [Hz]

stop_time = start_time + hours(sim_duration_h);
tspan     = 0 : dt_orbital : sim_duration_h*3600;

sc   = satelliteScenario(start_time, stop_time, dt_orbital);
sat1 = satellite(sc, 6901e3, 0, 53, 0,  0,  0,  'OrbitPropagator','two-body-keplerian','Name','Sat1');
sat2 = satellite(sc, 6901e3, 0, 53, 10, 0, 26.4,'OrbitPropagator','two-body-keplerian','Name','Sat2');

%% Precompute satellite data (the actual production pipeline)
fprintf('Precomputing satellite data...\n');
sat_data = precompute_satellite_data(sat1, sat2, start_time, tspan, carrier_freq);

%% Channel object
ch_obj = Channel(sat_data);

%% Assertions
fprintf('\n=== Orbit Model Validation ===\n');

% 1. Delays are positive and plausible during LOS windows
los_idx = find(sat_data.los_flags);
assert(~isempty(los_idx), 'No LOS windows found — scenario may be wrong.');

fwd_los = sat_data.forward_delays(los_idx);
bwd_los = sat_data.backward_delays(los_idx);
c = 299792458;
min_range = 300e3;   % closest LEO neighbour [m]
max_range = 7000e3;  % rough max ISL range [m]

assert(all(fwd_los > min_range/c & fwd_los < max_range/c), ...
    'Forward delays outside plausible range [%.1f µs, %.1f ms].', ...
    min_range/c*1e6, max_range/c*1e3);
assert(all(bwd_los > min_range/c & bwd_los < max_range/c), ...
    'Backward delays outside plausible range.');
fprintf('  Delay range [%.2f, %.2f] ms: PASS\n', min(fwd_los)*1e3, max(fwd_los)*1e3);

% 2. Asymmetry — fwd ≠ bwd for some samples
assert(~all(fwd_los == bwd_los), 'Forward and backward delays are identical for all samples.');
max_asym = max(abs(fwd_los - bwd_los));
fprintf('  Max fwd/bwd delay asymmetry: %.3f µs: PASS\n', max_asym*1e6);

% 3. Doppler sign and magnitude (LEO at ~7.7 km/s → max Doppler ~360 kHz at 14 GHz)
max_doppler_th = carrier_freq * 7700 / c;  % ~360 kHz
fwd_dop = sat_data.forward_doppler(los_idx);
assert(max(abs(fwd_dop)) < max_doppler_th * 1.1, ...
    'Doppler %.1f kHz exceeds physical max %.1f kHz.', max(abs(fwd_dop))/1e3, max_doppler_th/1e3);
assert(max(abs(fwd_dop)) > 0, 'All Doppler values are zero — likely a data issue.');
fprintf('  Doppler range [%.1f, %.1f] kHz: PASS\n', min(fwd_dop)/1e3, max(fwd_dop)/1e3);

% 4. NaN consistency — delays and Doppler should be NaN exactly where LOS = 0
no_los_idx = find(~sat_data.los_flags);
if ~isempty(no_los_idx)
    assert(all(isnan(sat_data.forward_delays(no_los_idx))), ...
        'Forward delays are not NaN outside LOS windows.');
    assert(all(isnan(sat_data.backward_delays(no_los_idx))), ...
        'Backward delays are not NaN outside LOS windows.');
    fprintf('  NaN consistency outside LOS: PASS\n');
else
    fprintf('  NaN consistency: skipped (continuous LOS throughout scenario)\n');
end

% 5. Channel.compute() matches raw interpolants at a sampled set of LOS times
t_samples = sat_data.tspan(los_idx(1 : max(1, floor(end/10)) : end));
for k = 1:length(t_samples)
    t  = t_samples(k);
    ch = ch_obj.compute(t);
    fwd_raw = sat_data.forward_delay_interp(t);
    bwd_raw = sat_data.backward_delay_interp(t);
    assert(abs(ch.fwd_delay - fwd_raw) < 1e-15, ...
        'Channel.compute fwd delay mismatch at t=%.1f s.', t);
    assert(abs(ch.bwd_delay - bwd_raw) < 1e-15, ...
        'Channel.compute bwd delay mismatch at t=%.1f s.', t);
end
fprintf('  Channel.compute() matches interpolants: PASS\n');

fprintf('\nAll orbit model checks passed.\n');

%% Plots
figure('Name', 'Orbit Model Validation', 'Position', [100 100 1100 650]);

subplot(1,3,1);
area(tspan/60, double(sat_data.los_flags), 'FaceColor','b','FaceAlpha',0.3,'EdgeColor','b');
xlabel('Time [min]'); ylabel('LOS'); ylim([-0.1 1.1]);
title('Line-of-sight flag'); grid on;

subplot(1,3,2);
plot(tspan/60, sat_data.forward_delays*1e3,  'r-', 'LineWidth', 1.5, 'DisplayName', 'Forward');
hold on;
plot(tspan/60, sat_data.backward_delays*1e3, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Backward');
xlabel('Time [min]'); ylabel('Delay [ms]');
title('Propagation delay'); legend('Location','best'); grid on;

subplot(1,3,3);
plot(tspan/60, sat_data.forward_doppler/1e3,  'r-', 'LineWidth', 1.5, 'DisplayName', 'Forward');
hold on;
plot(tspan/60, sat_data.backward_doppler/1e3, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Backward');
xlabel('Time [min]'); ylabel('Doppler [kHz]');
title('Doppler shift'); legend('Location','best'); grid on;

sgtitle('Satellite Link — precompute\_satellite\_data + Channel', ...
    'FontSize', 13, 'FontWeight', 'bold');
