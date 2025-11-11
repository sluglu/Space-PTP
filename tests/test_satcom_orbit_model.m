clear; clc; close all;

%% Sim parameters
dt = 10; %in seconds
dt_plot = 60; %in seconds
sim_duration = 4; %in hours
orbit_propagator = 'sgp4';

%% Scenario definitions

startTime = datetime(2025,11,05,0,0,0,'TimeZone','UTC');
stopTime  = startTime + hours(sim_duration);

% Define scenario
sc = satelliteScenario(startTime, stopTime, dt_plot);
 
% Add two satellites (replace with your orbital params)
a1 = 7000e3;  e1 = 0.001;  i1 = 98;  raan1 = 0;  argp1 = 0;  ta1 = 0;
a2 = 7050e3;  e2 = 0.001;  i2 = 98;  raan2 = 10; argp2 = 0;  ta2 = 10;

sat1 = satellite(sc, a1, e1, i1, raan1, argp1, ta1, ...
                     'OrbitPropagator',orbit_propagator,'Name','Sat1');
sat2 = satellite(sc, a2, e2, i2, raan2, argp2, ta2, ...
                     'OrbitPropagator',orbit_propagator,'Name','Sat2');




%% Sim setup
tspan = 0:dt:sim_duration*3600;
N = length(tspan);

forward_delays = NaN(1, N);
backward_delays = NaN(1, N);
forward_doppler = NaN(1, N);
backward_doppler = NaN(1, N);
los_flags = NaN(1, N);


%% Simulate propagation delays, doppler and LOS

% Create progress tracker object
progress = ProgressTracker(100);

% Start waitbar
progress.start();

for k = 1:N
    t = tspan(k);
    t_abs  = startTime + seconds(t);
    forward_delays(k) = latency(sat1, sat2, t_abs);
    backward_delays(k) = latency(sat2, sat1, t_abs);
    forward_doppler(k) = dopplershift(sat1, sat2, t_abs);
    backward_doppler(k) = dopplershift(sat2, sat1, t_abs);
    if ~isnan(forward_delays(k))
        los_flags(k) = 1;
    end
    if mod(k, ceil(N/100)) == 0
        progress.update()
    end
end

% Clean up
progress.finish();

elapsed_time = toc;
fprintf('Simulation completed in %.2f seconds\n', elapsed_time);


%% Plot
figure;

% LOS over time
subplot(1,3,1);
area(tspan/60, los_flags, 'FaceColor', 'b', 'FaceAlpha', 0.3, 'EdgeColor', 'b');
xlim([0, sim_duration*60]);
ylim([-0.1, 1.1]);
xlabel('Time [min]'); 
ylabel('LOS');
title('LOS over Time');
grid on;

% Delay over time
subplot(1,3,2);
plot(tspan/60, forward_delays, 'Color', 'r', 'LineWidth', 1.5, 'DisplayName', 'forward'); hold on;
plot(tspan/60, backward_delays, 'Color', 'b', 'LineWidth', 1.5, 'DisplayName', 'backward');
xlim([0, sim_duration*60]);
xlabel('Time [min]'); 
ylabel('Delay [s]');
title('Propagation Delay [s]'); 
legend;
grid on;

% Doppler over time
subplot(1,3,3);
plot(tspan/60, forward_doppler, 'Color', 'r', 'LineWidth', 1.5, 'DisplayName', 'forward'); hold on;
plot(tspan/60, backward_doppler, 'Color', 'b', 'LineWidth', 1.5, 'DisplayName', 'backward');
xlim([0, sim_duration*60]);
xlabel('Time [min]'); 
ylabel('Delay [s]');
title('Doppler Shift [Hz]'); 
legend;
grid on;

% Orbital scenario viewer
show(sat1)
show(sat2)