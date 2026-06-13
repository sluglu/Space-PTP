function cfg = exp_base()
% EXP_BASE  Template for writing a new experiment config.
%
% Naming convention: <PROTOCOL>_exp_<oscillators>_<scenario>.m
%   e.g. PTP_exp_perfect_inter_shell.m
%
% An experiment config composes scenario + oscillators + protocol into cfg:
%
%   cfg          = config_base();         % load simulation defaults
%   cfg.exp.name = mfilename();
%   cfg.scenario = sc_inter_shell();      % orbital geometry
%   cfg.nodes    = protocol_ptp( ...      % protocol + oscillators
%                      ox_perfect(), ox_ocxo());
%
% Optional overrides (see config_base for all fields):
%   cfg.sim.sim_duration = 2;            % hours
%   cfg.sim.dt_los       = 0.05;         % finer time step during LOS
%   cfg.channel_effects  = {@my_effect}; % add delay effects on top of geometric

error('exp_base is a template — copy and rename it for your experiment.');
end
