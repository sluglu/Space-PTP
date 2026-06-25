function scfg = sc_base()
% SC_BASE  Template for a new scenario config.
%
% Self-contained — owns start_time, sim_duration, dt_orbital, orbit_propagator.
% Returns a struct you can visualise or pass to an experiment config:
%
%   scfg = sc_same_plane();
%   scfg.sc.show()
%
% Returned fields:
%   scfg.sc    – satelliteScenario handle (nodes inferred by precompute_satellite_data)
%   scfg.name  – label used in plot titles
%
% Node inference rules in precompute_satellite_data:
%   ≥2 satellites         → node1 = Satellites(1), node2 = Satellites(2)
%   1 satellite + GS      → node1 = Satellites(1), node2 = GroundStations(1)
%
% Pattern:
%
%   function scfg = sc_myname(options)
%       arguments
%           options.sim_duration_h (1,1) double = 0.6
%           options.dt_orbital     (1,1) double = 1
%       end
%       start_time = datetime(2025,11,05,0,0,0,'TimeZone','UTC');
%       sc = satelliteScenario(start_time, start_time + hours(options.sim_duration_h), options.dt_orbital);
%       satellite(sc, a,e,i,RAAN,argp,nu,'OrbitPropagator','two-body-keplerian','Name','Node1');
%       satellite(sc, ...);   % or groundStation(sc, lat, lon, 'Name', 'Node2')
%       scfg = struct('sc', sc, 'name', "My Scenario");
%   end

error('sc_base is a template — copy and rename it for your scenario.');
end
