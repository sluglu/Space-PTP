function cfg = PTP_exp_perfect_same_plane()
    cfg          = sim_base();
    cfg.exp.name = mfilename();
    cfg.scenario = sc_same_plane();
    cfg.nodes    = protocol_ptp(ox_perfect(), ox_perfect());
end
