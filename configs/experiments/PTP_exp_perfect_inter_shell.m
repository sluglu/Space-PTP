function cfg = PTP_exp_perfect_inter_shell()
    cfg          = sim_base();
    cfg.exp.name = mfilename();
    cfg.scenario = sc_inter_shell();
    cfg.nodes    = protocol_ptp(ox_perfect(), ox_perfect());
end
