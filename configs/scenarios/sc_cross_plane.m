function scenario = sc_cross_plane()
    scenario.name = "Starlink Gen 2 (Cross-Plane)";
    % Format: {a, e, i, raan, argp, ta}
    rE = 6371e3;
    scenario.master = { ...
        6901e3, 0.001, 53, 0, 0, 10 };
    scenario.slave = { ...
        6901e3, 0.001, 53, 18, 0, 20 };

end