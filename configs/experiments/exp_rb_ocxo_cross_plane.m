function cfg = exp_rb_ocxo_cross_plane()

    cfg = config_base();
    
    cfg.exp.name = "CSAC_OCXO_cross_plane";
    cfg.scenario = sc_cross_plane();
    
    cfg.master_ox = ox_csac();
    cfg.slave_ox  = ox_ocxo();

end
