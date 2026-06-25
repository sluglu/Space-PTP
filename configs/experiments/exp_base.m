function cfg = exp_base()
% EXP_BASE  Template for a new experiment config.
%
% Naming: <PROTOCOL>_exp_<oscillators>_<scenario>.m
%
%   function cfg = PTP_exp_ocxo_same_plane()
%       cfg          = sim_base();       % loop parameters
%       cfg.exp.name = mfilename();
%       cfg.scenario = sc_same_plane();  % satellite geometry
%       cfg.nodes    = protocol_ptp(ox_perfect(), ox_ocxo());  % clocks + FSMs
%   end
%
%   cfg.scenario.sc.show()                           % visualise before running
%   cfg = sim_base('dt_los', 0.05);                  % override any sim_base field
%   cfg.channel_effects = {@my_effect};              % extra delay on top of geometry

error('exp_base is a template — copy and rename it for your experiment.');
end
