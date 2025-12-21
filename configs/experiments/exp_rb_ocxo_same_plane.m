function cfg = exp_rb_ocxo_same_plane()

    cfg = config_base();
    
    cfg.exp.name = "CSAC_OCXO_same_plane";
    cfg.scenario = sc_same_plane();
    
    cfg.master_ox = ox_csac();
    cfg.slave_ox  = ox_ocxo();

end
