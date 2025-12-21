function cfg = exp_perfect_inter_shell()

    cfg = config_base();
    
    cfg.exp.name = "perfect_inter_shell";
    cfg.scenario = sc_inter_shell();
    
    cfg.master_ox = ox_perfect();
    cfg.slave_ox  = ox_perfect();

end
