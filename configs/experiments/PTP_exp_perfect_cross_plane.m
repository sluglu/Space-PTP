function cfg = PTP_exp_perfect_cross_plane()
    cfg          = config_base();
    cfg.exp.name = mfilename();
    cfg.scenario = sc_cross_plane();
    cfg.nodes    = protocol_ptp(ox_perfect(), ox_perfect());
end
