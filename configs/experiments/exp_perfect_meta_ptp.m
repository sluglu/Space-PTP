function cfg = exp_perfect_meta_ptp()

    cfg = config_base();
    
    cfg.exp.name = "perfect_meta_ptp";
    cfg.scenario = sc_meta_ptp();
    
    cfg.master_ox = ox_perfect();
    cfg.slave_ox  = ox_perfect();

end
