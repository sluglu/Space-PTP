function cfg = exp_perfect_same_plane()

    cfg = config_base();
    
    cfg.exp.name = "perfect_same_plane";
    cfg.scenario = sc_same_plane();
    
    cfg.master_ox = ox_perfect();
    cfg.slave_ox  = ox_perfect();

end
