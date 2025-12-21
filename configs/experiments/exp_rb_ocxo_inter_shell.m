function cfg = exp_rb_ocxo_inter_shell()

    cfg = config_base();
    
    cfg.exp.name = "CSAC_OCXO_inter_shell";
    cfg.scenario = sc_inter_shell();
    
    cfg.master_ox = ox_csac();
    cfg.slave_ox  = ox_ocxo();

end
