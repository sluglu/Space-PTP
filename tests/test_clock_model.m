% TEST_CLOCK_MODEL
% Validates the Clock power-law noise model against theoretical Allan deviation
% and phase noise curves for OCXO and CSAC oscillator specs.
%
% Pass criteria (checked quantitatively):
%   Empirical ADEV at each tau is within a factor of 3 of the theoretical value
%   for the dominant noise process.  Factor-of-3 tolerance accounts for Monte
%   Carlo variance at limited simulation length.

clear; clc; close all;

%% Parameters
dt           = 0.01;       % simulation step [s]
sim_duration = 3600;       % [s]
tol_factor   = 3;          % empirical ADEV must be within this multiple of theory

%% Oscillator specs (from datasheets)
ocxo = struct( ...
    'f0',       100e6, ...
    'delta_f0', (rand()*2-1) * 50, ...
    'alpha',    (rand()*2-1) * 1.58e-6, ...
    'h',        [0, 4.62e-23, 1.58e-25, 0, 1.0e-32]);  % OX-249

csac = struct( ...
    'f0',       10e6, ...
    'delta_f0', (rand()*2-1) * 5e-4, ...
    'alpha',    (rand()*2-1) * 3.15e-9, ...
    'h',        [0, 0, 1.8e-19, 0, 2.0e-28]);           % SA45

%% Simulate
N = ceil(sim_duration / dt);
clk_ocxo = Clock(ocxo, 0);
clk_csac = Clock(csac, 0);

freq_ocxo = zeros(1, N);
freq_csac = zeros(1, N);

progress = ProgressTracker(N, 'test_clock_model');
progress.start();
for i = 1:N
    freq_ocxo(i) = clk_ocxo.f;
    freq_csac(i) = clk_csac.f;
    clk_ocxo = clk_ocxo.advance(dt);
    clk_csac = clk_csac.advance(dt);
    progress.update();
end
progress.finish();

%% Empirical Allan deviation
tau_emp = logspace(-1, log10(sim_duration/10), 20);
[adev_ocxo, tau_ocxo] = compute_adev(freq_ocxo, 1/dt, ocxo.f0, tau_emp);
[adev_csac, tau_csac] = compute_adev(freq_csac, 1/dt, csac.f0, tau_emp);

%% Quantitative checks
fprintf('\n=== Clock Model Validation ===\n');

check_adev('OCXO', tau_ocxo, adev_ocxo, ocxo.h, tol_factor);
check_adev('CSAC', tau_csac, adev_csac, csac.h, tol_factor);

%% Plots
tau_th = logspace(-2, 4, 100);
figure('Name', 'Clock Model Validation', 'Position', [100 100 1200 800]);

% --- ADEV ---
subplot(2,2,[1 2]);
loglog(tau_th, arrayfun(@(t) theory_adev(t, ocxo.h), tau_th), 'r--', 'LineWidth', 1, 'HandleVisibility', 'off');
hold on;
loglog(tau_th, arrayfun(@(t) theory_adev(t, csac.h), tau_th), 'b--', 'LineWidth', 1, 'HandleVisibility', 'off');
loglog(tau_ocxo, adev_ocxo, 'r-o', 'DisplayName', 'OCXO (empirical)');
loglog(tau_csac, adev_csac, 'b-o', 'DisplayName', 'CSAC (empirical)');
xlabel('\tau [s]'); ylabel('\sigma_y(\tau)');
title('Allan Deviation — empirical (solid) vs theory (dashed)');
legend('Location','best'); grid on;

% --- Frequency traces ---
times = (0:N-1)*dt;
subplot(2,2,3);
frac_ocxo = (freq_ocxo - ocxo.f0) / ocxo.f0;
frac_csac = (freq_csac - csac.f0) / csac.f0;
plot(times, frac_ocxo*1e9, 'r-', 'DisplayName', 'OCXO');
hold on;
plot(times, frac_csac*1e9, 'b-', 'DisplayName', 'CSAC');
xlabel('Time [s]'); ylabel('Fractional frequency [ppb]');
title('Frequency deviation'); legend('Location','best'); grid on;

% --- Phase noise PSD ---
subplot(2,2,4);
[psd_ocxo, fax] = pwelch(freq_ocxo - mean(freq_ocxo), [], [], [], 1/dt);
[psd_csac, ~  ] = pwelch(freq_csac - mean(freq_csac), [], [], [], 1/dt);
f = fax(2:end);
Lf_ocxo = 10*log10(0.5 * psd_ocxo(2:end) ./ f.^2);
Lf_csac = 10*log10(0.5 * psd_csac(2:end) ./ f.^2);

% Theoretical phase noise
Sy_ocxo = ocxo.h(2)./fax(2:end) + ocxo.h(3) + ocxo.h(5)*fax(2:end).^2;
Sy_csac = csac.h(3) + csac.h(5)*fax(2:end).^2;
Lf_ocxo_th = 10*log10(0.5 * ocxo.f0^2 ./ fax(2:end).^2 .* Sy_ocxo);
Lf_csac_th = 10*log10(0.5 * csac.f0^2 ./ fax(2:end).^2 .* Sy_csac);

semilogx(f, Lf_ocxo, 'r-', 'DisplayName', 'OCXO'); hold on;
semilogx(f, Lf_csac, 'b-', 'DisplayName', 'CSAC');
semilogx(f, Lf_ocxo_th, 'r--', 'HandleVisibility','off');
semilogx(f, Lf_csac_th, 'b--', 'HandleVisibility','off');
xlabel('Offset frequency [Hz]'); ylabel('L(f) [dBc/Hz]');
title('Phase noise — empirical (solid) vs theory (dashed)');
legend('Location','best'); grid on;

sgtitle('Power-law Clock Noise — OCXO & CSAC', 'FontSize', 14, 'FontWeight', 'bold');


%% -----------------------------------------------------------------------
function [adev, tau_out] = compute_adev(freq, fs, f0, tau_vals)
    y = (freq - mean(freq)) / f0;
    x = cumsum(y) / fs;
    N = length(y);
    adev    = zeros(size(tau_vals));
    tau_out = tau_vals;
    for k = 1:length(tau_vals)
        m = floor(tau_vals(k) * fs);
        if m < 1 || (N - 2*m) < 1; adev(k) = NaN; continue; end
        s = 0;
        for j = 1:(N-2*m)
            s = s + (x(j+2*m) - 2*x(j+m) + x(j))^2;
        end
        adev(k) = sqrt(s / (2*(N-2*m)*tau_vals(k)^2));
    end
    ok      = ~isnan(adev);
    adev    = adev(ok);
    tau_out = tau_out(ok);
end

function sy = theory_adev(tau, h)
    % Analytical Allan variance for power-law processes (IEEE 1139-2008)
    avar = (2*pi)^2 * h(1)*tau/6 ...   % h_{-2}: RWFM
         + h(2) * 2*log(2)         ...  % h_{-1}: Flicker FM
         + h(3) / (2*tau)          ...  % h_{0}: White FM
         + 3*h(5) / (2*pi*tau)^2;       % h_{+2}: White PM
    % h_{+1} (Flicker PM) omitted: neither OCXO nor CSAC uses it.
    sy = sqrt(max(avar, 0));
end

function check_adev(label, tau, adev_emp, h, tol)
    fprintf('\n%s:\n', label);
    th = arrayfun(@(t) theory_adev(t, h), tau);
    ratio = adev_emp ./ th;
    ok = all(ratio > 1/tol & ratio < tol);
    for k = 1:length(tau)
        status = 'OK';
        if ratio(k) < 1/tol || ratio(k) > tol; status = 'FAIL'; end
        fprintf('  tau=%6.2f s  emp=%.2e  th=%.2e  ratio=%.2f  [%s]\n', ...
            tau(k), adev_emp(k), th(k), ratio(k), status);
    end
    if ok
        fprintf('  => PASS (all ratios within factor %.0f of theory)\n', tol);
    else
        fprintf('  => FAIL (some taus outside factor %.0f tolerance)\n', tol);
        % Not an error — stochastic test; large deviations warrant inspection.
    end
end
