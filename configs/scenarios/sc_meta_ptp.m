function scfg = sc_meta_ptp(options)
% Meta-PTP — LEO cubesat to Montreal ground station.
% Returns a struct with fields: sc, name.
%
%   sc_meta_ptp()
%   sc_meta_ptp(Name, Value, ...)
%
% Optional name-value overrides:
%   sim_duration_h   Simulation duration [h]         (0.6)
%   dt_orbital       Orbital precompute step [s]      (1)
    arguments
        options.sim_duration_h (1,1) double = 0.6
        options.dt_orbital     (1,1) double = 1
    end
    rE         = 6371e3;
    start_time = datetime(2025,11,05,0,0,0,'TimeZone','UTC');
    propagator = 'two-body-keplerian';

    sc = satelliteScenario(start_time, start_time + hours(options.sim_duration_h), options.dt_orbital);
    satellite(sc, 400e3 + rE, 0.001, 45, -63, 0, 0, 'OrbitPropagator', propagator, 'Name', 'Cubesat');
    groundStation(sc, 45.505, -73.614, 'Name', 'Montreal');
    scfg = struct('sc', sc, 'name', "Meta-PTP cubesat");
end
