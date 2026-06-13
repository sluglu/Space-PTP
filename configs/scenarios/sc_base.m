function scenario = sc_base()
% SC_BASE  Template for writing a new orbital scenario.
%
% A scenario config defines the two platforms (satellites or ground stations)
% for the simulation. Fields:
%
%   scenario.name   – human-readable label (used in plot titles)
%   scenario.node1  – platform definition (see formats below)
%   scenario.node2  – platform definition
%
% Platform format — satellite (6 Keplerian elements):
%   { a [m], e, i [deg], RAAN [deg], argp [deg], true_anomaly [deg] }
%
% Platform format — ground station (2 geodetic coordinates):
%   { latitude [deg], longitude [deg] }
%
% run_experiment distinguishes them by length: length < 3 → ground station.

error('sc_base is a template — copy and rename it for your scenario.');
end
