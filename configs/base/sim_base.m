function cfg = sim_base(options)
% SIM_BASE  Simulation loop parameters — starting point for every experiment.
%
%   sim_base()
%   sim_base(Name, Value, ...)
%
% Optional name-value overrides:
%   t0                Simulation clock start [s]                    (0)
%   dt_los            Time step during LOS [s]                      (0.1)
%   min_los_duration  Ignore LOS windows shorter than [s]           (1)
%   min_msg_interval  Minimum gap between queued messages [s]       (1e-6)
%
% Timing (start_time, sim_duration, dt_orbital) lives in each sc_* config.
    arguments
        options.t0               (1,1) double = 0
        options.dt_los           (1,1) double = 0.1
        options.min_los_duration (1,1) double = 1
        options.min_msg_interval (1,1) double = 1e-6
    end

    cfg.sim = options;
    cfg.channel_effects = {};
    cfg.exp.root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results');
end
