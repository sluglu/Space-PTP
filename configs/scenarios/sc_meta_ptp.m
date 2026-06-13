function scenario = sc_meta_ptp()
    scenario.name  = "Meta-PTP cubesat";
    rE = 6371e3;
    scenario.node1 = { 400e3 + rE, 0.001, 45, -63, 0, 0 };
    scenario.node2 = { 45.505, -73.614 };   % ground station {lat, lon}
end
