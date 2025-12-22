function scenario = sc_meta_ptp()
    scenario.name = "Meta-PTP cubesat";
    % Format: {a, e, i, raan, argp, ta}
    rE = 6371e3;
    scenario.master = { ...
        400e3 + rE, 0.001, 45, -63, 0, 0};
    scenario.slave = { ...
        45.505, -73.614};

end