clear; clc; close all;

%% Simulation Parameters
dt = 0.01;
sim_duration = 3600;

%% Oscillator Parameters
% 1. OCXO (100 MHz OX-249)
slave_f0 = 100e6;
ocxo_params = struct(...
    'delta_f0', (rand() * 2 * 50) - 50, ...
    'alpha', (rand() * 2 * 1.58e-6) - 1.58e-6, ...
    'power_law_coeffs', [0, 4.62e-23, 1.58e-25, 0, 1.0e-32] ...
);

% 2. Rubidium Atomic Clock (10 MHz CSAC-SA45)
master_f0 = 10e6;
rubidium_params = struct( ...
    'delta_f0', (rand() * 2 * 5e-4) - 5e-4, ...
    'alpha', (rand() * 2 * 3.17e-9) - 3.17e-9, ...
    'power_law_coeffs', [0, 0, 1.8e-19, 0, 2.0e-28] ...
);

%% Create Clocks with Power Law Noise
master_noise_profile = NoiseProfile(rubidium_params);
master_clock = WRClock(master_f0, 0, master_noise_profile);

slave_noise_profile = NoiseProfile(ocxo_params);
slave_clock = WRClock(slave_f0, 0, slave_noise_profile);

% Pre-allocate arrays
N = ceil(sim_duration / dt);
times = (0:N-1) * dt;
master_freq = zeros(1, N);
slave_freq = zeros(1, N);

%% Run Simulation

% Create progress tracker object
progress = ProgressTracker(100);

% Start waitbar
progress.start();

fprintf('Simulating %d samples over %.1f hours...\n', N, sim_duration/3600);

for i = 1:N
    master_freq(i) = master_clock.f;
    slave_freq(i) = slave_clock.f;
    master_clock = master_clock.advance(dt);
    slave_clock = slave_clock.advance(dt);
    
    if mod(i, ceil(N/100)) == 0
        progress.update()
    end
end

% Clean up
progress.finish();

elapsed_time = toc;
fprintf('Simulation completed in %.2f seconds\n', elapsed_time);

%% Analysis and Plotting
figure('Position', [100, 100, 1200, 800]); % Adjusted for 3x2 layout

% Calculate fractional frequencies for normalized comparisons
master_frac_freq = (master_freq - master_f0) / master_f0;
slave_frac_freq = (slave_freq - slave_f0) / slave_f0;

% --- PLOT 1: FRACTIONAL FREQUENCY EVOLUTION ---
subplot(3,2,1);
plot(times, master_frac_freq * 1e9, 'b-'); % Plot in ppb
hold on;
plot(times, slave_frac_freq * 1e9, 'r-');
xlabel('Time [s]');
ylabel('Fractional Frequency [ppb]');
title('Clock Frequency Evolution');
legend('Master (CSAC)', 'Slave (OCXO)', 'Location', 'best');
grid on;

% --- PLOT 2: FRACTIONAL FREQUENCY DIFFERENCE ---
subplot(3,2,2);
plot(times, (slave_frac_freq - master_frac_freq) * 1e9, 'g-'); % Plot in ppb
xlabel('Time [s]');
ylabel('Fractional Freq Diff [ppb]');
title('Fractional Frequency Difference (Slave - Master)');
grid on;

% --- PLOT 3: ALLAN DEVIATION (EMPIRICAL VS THEORETICAL) ---
subplot(3,2,3);
% Calculate theoretical ADEV for background plotting
tau_values_th = logspace(-4, 4, 50);
allan_dev_master_th = arrayfun(@(t) allan_deviation_estimate(t, master_noise_profile.power_law_coeffs), tau_values_th);
allan_dev_slave_th = arrayfun(@(t) allan_deviation_estimate(t, slave_noise_profile.power_law_coeffs), tau_values_th);

% Calculate empirical ADEV from simulation data
tau_values_for_emp = logspace(-2, log10(sim_duration/10), 20);
[adev_master_emp, tau_master_actual] = calculate_allan_deviation(master_freq, 1/dt, master_f0, tau_values_for_emp);
[adev_slave_emp, tau_slave_actual] = calculate_allan_deviation(slave_freq, 1/dt, slave_f0, tau_values_for_emp);

% Plot theoretical curves lightly in the background
loglog(tau_values_th, allan_dev_master_th, 'b--', 'LineWidth', 1, 'HandleVisibility', 'off');
hold on;
loglog(tau_values_th, allan_dev_slave_th, 'r--', 'LineWidth', 1, 'HandleVisibility', 'off');

% Plot empirical data markers on top
loglog(tau_master_actual, adev_master_emp, 'bo', 'MarkerFaceColor', 'b', 'DisplayName', 'Master (CSAC)');
loglog(tau_slave_actual, adev_slave_emp, 'rx', 'MarkerSize', 8, 'LineWidth', 1.5, 'DisplayName', 'Slave (OCXO)');
xlabel('Averaging Time τ [s]');
ylabel('Allan Deviation σ_y(τ)');
title('Allan Deviation (Empirical vs. Theoretical)');
legend('Location', 'best');
grid on;

% --- PLOT 4: PHASE NOISE (EMPIRICAL VS THEORETICAL) ---
subplot(3,2,4);
% Calculate theoretical Phase Noise for background plotting
f_axis_th = logspace(-4, 4, 200);
h_slave = slave_noise_profile.power_law_coeffs;
sy_f_slave = h_slave(1)*f_axis_th.^(-2) + h_slave(2)*f_axis_th.^(-1) + h_slave(3) + h_slave(4)*f_axis_th.^1 + h_slave(5)*f_axis_th.^2;
L_f_slave_th = 10*log10((slave_f0^2 ./ (2*f_axis_th.^2)) .* sy_f_slave);
h_master = master_noise_profile.power_law_coeffs;
sy_f_master = h_master(1)*f_axis_th.^(-2) + h_master(2)*f_axis_th.^(-1) + h_master(3) + h_master(4)*f_axis_th.^1 + h_master(5)*f_axis_th.^2;
L_f_master_th = 10*log10((master_f0^2 ./ (2*f_axis_th.^2)) .* sy_f_master);

% Calculate empirical Phase Noise from simulation data
[psd_f_master, freq_axis] = pwelch(master_freq - mean(master_freq), [], [], [], 1/dt);
[psd_f_slave, ~] = pwelch(slave_freq - mean(slave_freq), [], [], [], 1/dt);
valid_indices = 2:length(freq_axis);
f = freq_axis(valid_indices);
L_f_dB_master = 10 * log10(0.5 * (psd_f_master(valid_indices)) ./ (f.^2));
L_f_dB_slave = 10 * log10(0.5 * (psd_f_slave(valid_indices)) ./ (f.^2));

% Plot theoretical curves lightly in the background
semilogx(f_axis_th, L_f_master_th, 'b--', 'LineWidth', 1, 'HandleVisibility', 'off');
hold on;
semilogx(f_axis_th, L_f_slave_th, 'r--', 'LineWidth', 1, 'HandleVisibility', 'off');

% Plot empirical data on top
semilogx(f, L_f_dB_master, 'b-', 'DisplayName', 'Master (CSAC)');
semilogx(f, L_f_dB_slave, 'r-', 'DisplayName', 'Slave (OCXO)');
xlabel('Frequency Offset f [Hz]');
ylabel('Phase Noise L(f) [dBc/Hz]');
title('Phase Noise (Empirical vs. Theoretical)');
legend('Location', 'best');
grid on;

% --- PLOT 5: HISTOGRAM ---
subplot(3,2,5);
histogram(master_frac_freq * 1e9, 50, 'Normalization', 'probability', 'FaceAlpha', 0.7, 'FaceColor', 'blue');
hold on;
histogram(slave_frac_freq * 1e9, 50, 'Normalization', 'probability', 'FaceAlpha', 0.7, 'FaceColor', 'red');
xlabel('Fractional Frequency Deviation [ppb]');
ylabel('Probability');
title('Frequency Deviation Distribution');
legend('Master (CSAC)', 'Slave (OCXO)', 'Location', 'best');
grid on;

% --- PLOT 6: CUMULATIVE TIME DIFFERENCE ---
subplot(3,2,6);
master_phase_error = cumsum(master_frac_freq * dt);
slave_phase_error = cumsum(slave_frac_freq * dt);
time_error = slave_phase_error - master_phase_error;
plot(times, time_error * 1e9, 'm-', 'LineWidth', 1.5);
xlabel('Time [s]');
ylabel('Time Difference [ns]');
title('Cumulative Time Difference (Slave - Master)');
grid on;

sgtitle('Power Law Clock Noise Simulation: OCXO vs. CSAC', 'FontSize', 16, 'FontWeight', 'bold');

%% Helper and Estimation Functions

function [adev, tau_out] = calculate_allan_deviation(freq_data, fs, f0, tau_values)
    % Calculates Overlapping Allan Deviation from frequency data.
    y = (freq_data - mean(freq_data)) / f0;
    N = length(y);
    x = cumsum(y) / fs; % Phase error in seconds
    adev = zeros(size(tau_values));
    for i = 1:length(tau_values)
        tau = tau_values(i);
        m = floor(tau * fs);
        if m == 0; adev(i) = NaN; continue; end
        if (N - 2*m) < 1; adev(i:end) = NaN; break; end
        
        sum_sq_diff = 0;
        for j = 1:(N - 2*m)
            term = x(j + 2*m) - 2*x(j + m) + x(j);
            sum_sq_diff = sum_sq_diff + term^2;
        end
        
        avar = sum_sq_diff / (2 * (N - 2*m) * tau^2);
        adev(i) = sqrt(avar);
    end
    tau_out = tau_values;
    valid_indices = ~isnan(adev);
    adev = adev(valid_indices);
    tau_out = tau_out(valid_indices);
end

function sigma_y = allan_deviation_estimate(tau, h)
    % Estimates Allan deviation from power law coefficients h.
    sigma_y_squared = 0;
    % h_coeffs = [h_-2, h_-1, h_0, h_1, h_2]

    % Random Walk FM (h_-2)
    sigma_y_squared = sigma_y_squared + ( (2*pi)^2 * h(1) * tau / 6 );
    % Flicker FM (h_-1)
    sigma_y_squared = sigma_y_squared + ( h(2) * 2 * log(2) );
    % White FM (h_0)
    sigma_y_squared = sigma_y_squared + ( h(3) / (2 * tau) );
    % Flicker PM (h_1) - Approximation, requires bandwidth f_h
    % sigma_y_squared = sigma_y_squared + ( h(4) / (2 * (pi * tau)^2) * (1.038 + 3*log(2*pi*1e6*tau)) );
    % White PM (h_2)
    sigma_y_squared = sigma_y_squared + ( 3 * h(5) / ( (2*pi*tau)^2 ) );

    sigma_y = sqrt(sigma_y_squared);
end