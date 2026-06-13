function cfg = config_base()

cfg.sim = struct( ...
    'start_time',      datetime(2025,11,05,0,0,0,'TimeZone','UTC'), ...
    't0',              0, ...
    'dt_ptp',          0.1, ...        % PTP simulation time step [s]
    'dt_orbital',      1, ...          % Orbital propagation time step [s]
    'sim_duration',    0.6, ...        % Total simulation duration [h]
    'min_los_duration',1, ...          % Ignore LOS intervals shorter than this [s]
    'orbit_propagator','two-body-keplerian', ...
    'carrier_frequency',14e9);         % RF carrier for Doppler [Hz]

cfg.ptp = struct( ...
    'sync_interval',       1, ...      % SYNC message interval [s]
    'initial_time_offset', 0, ...      % Slave initial time offset [s]
    'min_msg_interval',    1e-6, ...   % Min gap between burst messages [s]
    'verbose',             false);

cfg.exp.root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results');
% cfg.exp.name is set by each experiment config

end
