function cfg = PTP_exp_rb_ocxo_inter_shell()
    cfg          = sim_base();
    cfg.exp.name = mfilename();
    cfg.scenario = sc_inter_shell();
    cfg.nodes    = protocol_ptp(ox_csac(), ox_ocxo());
end
