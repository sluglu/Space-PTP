function scenario = sc_inter_shell()
    scenario.name = "Starlink Gen 2 (Inter-Shell)";
    % Format: {a, e, i, raan, argp, ta}
    rE = 6371e3;
    scenario.master = { ...
        6906e3, 0.001, 53, 15, 0, 20 };
    scenario.slave = { ...
        6901e3, 0.001, 53, 17, 0, 35 };

end
