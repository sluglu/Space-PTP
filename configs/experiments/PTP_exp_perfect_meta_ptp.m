function cfg = PTP_exp_perfect_meta_ptp()
    cfg          = config_base();
    cfg.exp.name = mfilename();
    cfg.scenario = sc_meta_ptp();
    cfg.nodes    = protocol_ptp(ox_perfect(), ox_perfect());
end
