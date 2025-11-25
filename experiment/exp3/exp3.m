%% Setup
clear; clc; close all;

% Constants
deg = pi/180;
rE = 6371e3;

% Simulation Parameters
dt_ptp = 0.1;              % PTP simulation time step [s]
dt_orbital = 1;            % Orbital position update interval [s]
sim_duration = 2;          % Total simulation duration [hours]
min_los_duration = 1;      % Minimum LOS duration to simulate PTP [s]
orbit_propagator = 'sgp4'; % Orbit propagator type

% PTP Parameters
sync_interval = 1;         % PTP sync interval [s]
t0 = 0;
initial_time_offset = 0;
min_msg_interval = 1e-6;   % Minimum time between messages processed in same cycle [s]
verbose = false;

% Noise Profiles Parameters
% High-Performance OCXO (100MHz OX-249)
ocxo_params1 = struct(...
    'delta_f0', (rand() * 2 * 50) - 50, ...
    'alpha', (rand() * 2 * 1.58e-6) - 1.58e-6, ...
    'power_law_coeffs', [0, 4.62e-23, 1.58e-25, 0, 1.0e-32], ...
    'timestamp_resolution', 0);
ocxo_params2 = struct(...
    'delta_f0', (rand() * 2 * 50) - 50, ...
    'alpha', (rand() * 2 * 1.58e-6) - 1.58e-6, ...
    'power_law_coeffs', [0, 4.62e-23, 1.58e-25, 0, 1.0e-32], ...
    'timestamp_resolution', 0);

% Rubidium Atomic Clock (10 MHz CSAC-SA45)
rubidium_params = struct( ...
    'delta_f0', (rand() * 2 * 5e-4) - 5e-4, ...
    'alpha', (rand() * 2 * 3.15e-9) - 3.15e-9, ...
    'power_law_coeffs', [0, 0, 1.8e-19, 0, 2.0e-28], ...
    'timestamp_resolution', 0);

master_f0 = 10e6;  
master_noise_profile = NoiseProfile();
slave_f0 = 100e6;
slave_noise_profile = NoiseProfile();

% Scenario Parameters (orbital elements)
% Format: [name, a1, e1, i1, raan1, argp1, ta1, a2, e2, i2, raan2, argp2, ta2]
scenarios = {
    "Starlink Gen 2 (Same-Plane)",  6901e3, 0.001, 53,  0,   0,   10,    6901e3, 0.001, 53,  0,   0,   26.4;
    "Starlink Gen 2 (Cross-Plane)", 6901e3, 0.001, 53,  0,   0,   10,    6901e3, 0.001, 53,  18,  0,   20;       
    "Starlink Gen 2 (Inter-Shell)", 6906e3, 0.001, 53,  15,   0,   20,    6901e3, 0.001, 53,  17,  0,   35;
};

% Packing parameters
sim_params = struct('dt_ptp', dt_ptp, 'dt_orbital', dt_orbital, 'sim_duration', sim_duration, ...
                   'min_los_duration', min_los_duration, 'orbit_propagator', orbit_propagator);

ptp_params = struct('master_f0', master_f0, 'slave_f0', slave_f0, 'sync_interval', sync_interval, ...
                   'min_msg_interval', min_msg_interval, 'verbose', verbose, ...
                   'master_noise_profile', master_noise_profile, 'slave_noise_profile', slave_noise_profile, ... 
                   't0', t0, 'initial_time_offset', initial_time_offset);

params = {scenarios, sim_params, ptp_params};

%% Simulation
scenario_idx = 3; % Select scenario to simulate
exp_name = "Perfect Hardware";
%exp_name = "Rb OCXO perfect timestamp";
%exp_name = "two OCXO perfect timestamp";

run_sim(scenario_idx, exp_name, params)
%run_all_sim(exp_name, params)

%% Plot Results
scenario_idx = 3; % Select scenario to plot
exp_name = "Perfect Hardware";
%exp_name = "Rb OCXO perfect timestamp";
%exp_name = "two OCXO perfect timestamp";

plot_result(scenario_idx, exp_name, params)

%% Helper Functions
function run_sim(scenario_idx, exp_name, params)
    ptp_params = params{3};
    sim_params = params{2};
    scenarios = params{1};
    scenario = scenarios(scenario_idx, :);
    save_filename = sprintf('experiment/exp3/results/%s/exp3_PTP_orbital_sim_%s_%s.mat', ...
                           strrep(exp_name, ' ', '_'), strrep(scenario{1}, ' ', '_'), strrep(exp_name, ' ', '_'));
    fprintf('Simulating scenario: %s\n', scenario{1});
    results = simulate_ptp_orbital_satcom(sim_params, ptp_params, scenario);
    folder_name = sprintf("experiment/exp3/results/%s/", strrep(exp_name, ' ', '_'));
    mkdir(folder_name);
    save(save_filename, "-fromstruct", results);
    fprintf('\nResults saved to %s\n', save_filename); 
end

function run_all_sim(exp_name, params)
    scenarios = params{1};
    parfor i = 1:size(scenarios, 1)
        run_sim(i, exp_name, params)
    end
end

function plot_result(scenario_idx, exp_name, params)
    scenarios = params{1};
    scenario = scenarios(scenario_idx, :);
    save_filename = sprintf('experiment/exp3/results/%s/exp3_PTP_orbital_sim_%s_%s.mat', ...
                           strrep(exp_name, ' ', '_'), strrep(scenario{1}, ' ', '_'), strrep(exp_name, ' ', '_'));
    results = load(save_filename);
    plot_PTP_orbital_scenario_satcom(results);
end