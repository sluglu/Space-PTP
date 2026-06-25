function scfg = sc_cross_plane(options)
% Starlink Gen 2 — two satellites in adjacent orbital planes.
% Returns a struct with fields: sc, name.
%
%   sc_cross_plane()
%   sc_cross_plane(Name, Value, ...)
%
% Optional name-value overrides:
%   sim_duration_h   Simulation duration [h]         (0.6)
%   dt_orbital       Orbital precompute step [s]      (1)
    arguments
        options.sim_duration_h (1,1) double = 0.6
        options.dt_orbital     (1,1) double = 1
    end
    start_time = datetime(2025,11,05,0,0,0,'TimeZone','UTC');
    propagator = 'two-body-keplerian';

    sc = satelliteScenario(start_time, start_time + hours(options.sim_duration_h), options.dt_orbital);
    satellite(sc, 6901e3, 0.001, 53,  0, 0, 10, 'OrbitPropagator', propagator, 'Name', 'Node1');
    satellite(sc, 6901e3, 0.001, 53, 18, 0, 20, 'OrbitPropagator', propagator, 'Name', 'Node2');
    scfg = struct('sc', sc, 'name', "Starlink Gen 2 (Cross-Plane)");
end
