function cfg = PTP_exp_rb_ocxo_cross_plane()
    cfg          = config_base();
    cfg.exp.name = mfilename();
    cfg.scenario = sc_cross_plane();
    cfg.nodes    = protocol_ptp(ox_csac(), ox_ocxo());
end
