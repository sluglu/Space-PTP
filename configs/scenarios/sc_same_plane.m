function scenario = sc_same_plane()
    scenario.name = "Starlink Gen 2 (Same-Plane)";
    % Format: {a, e, i, raan, argp, ta}
    rE = 6371e3;
    scenario.master = { ...
        6901e3, 0.001, 53, 0, 0, 10 };
    scenario.slave = { ...
        6901e3, 0.001, 53, 0, 0, 26.4 };

end