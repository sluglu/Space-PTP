function save_results(results, cfg)
% SAVE_RESULTS  Save experiment results to disk.
    out_dir  = cfg.exp.root;
    mkdir(out_dir);
    filepath = fullfile(out_dir, sprintf('%s.mat', cfg.exp.name));
    save(filepath, '-fromstruct', results);
    fprintf('Saved → %s\n', filepath);
end
