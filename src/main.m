clear; clc;

cfg = exp_perfect_inter_shell();

results = run_experiment(cfg);
save_results(results, cfg);
plot_experiment(results);

% To view the orbital scenario:
%   sc = satelliteScenario(...);  % re-create from cfg.scenario if needed
%   show(sc)

% Run multiple experiments:
% configs = {'exp_rb_ocxo_same_plane', 'exp_rb_ocxo_cross_plane', 'exp_rb_ocxo_inter_shell'};
% parfor i = 1:numel(configs)
%     c = feval(configs{i});
%     save_results(run_experiment(c), c);
% end
% for i = 1:numel(configs)
%     plot_experiment(feval(configs{i}));
% end
