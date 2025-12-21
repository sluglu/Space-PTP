function cfg = exp_perfect_cross_plane()

    cfg = config_base();
    
    cfg.exp.name = "perfect_cross_plane";
    cfg.scenario = sc_cross_plane();
    
    cfg.master_ox = ox_perfect();
    cfg.slave_ox  = ox_perfect();

end
