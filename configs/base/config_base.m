function cfg = config_base()

cfg.sim = struct( ...
    'start_time',       datetime(2025,11,05,0,0,0,'TimeZone','UTC'), ...
    't0',               0, ...
    'dt_los',           0.1, ...         % simulation time step during LOS [s]
    'dt_orbital',       1, ...          % simulation time step outside LOS [s]
    'sim_duration',     0.6, ...        % total simulation duration [h]
    'min_los_duration', 1, ...          % ignore LOS intervals shorter than this [s]
    'min_msg_interval', 1e-6, ...       % minimum gap between queued messages [s]
    'orbit_propagator', 'two-body-keplerian', ...
    'carrier_frequency', 14e9);         % RF carrier for Doppler [Hz]

% cfg.nodes is set by each experiment config via a protocol_*.m function
% cfg.channel_effects is a cell array of effect functions added on top of geometric delay
cfg.channel_effects = {};

cfg.exp.root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results');
% cfg.exp.name is set by each experiment config

end
