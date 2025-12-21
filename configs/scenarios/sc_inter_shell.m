function scenario = sc_inter_shell()
    scenario.name = "Starlink Gen 2 (Inter-Shell)";
    % Format: {a, e, i, raan, argp, ta}
    scenario.sat1 = { ...
        6906e3, 0.001, 53, 15, 0, 20 };
    scenario.sat2 = { ...
        6901e3, 0.001, 53, 17, 0, 35 };

end
