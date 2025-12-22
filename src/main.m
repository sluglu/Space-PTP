clear; clc;

cfg = exp_perfect_inter_shell();
results = run_experiment(cfg);
plot_experiment(cfg)

% Orbital scenario viewer
show(results.master_sc)
show(results.slave_sc)

% % List of experiments to run in parallel
% configs = { ...
%     'exp_rb_ocxo_same_plane', ...
%     'exp_rb_ocxo_cross_plane', ...
%     'exp_rb_ocxo_inter_shell'};
% 
% run_all_experiments(configs);
% plot_all_experiments(configs);



%% Utillity
function run_all_experiments(config_list)
    parfor i = 1:numel(config_list)
        cfg = feval(config_list{i});
        run_experiment(cfg);
    end
end

function plot_all_experiments(config_list)
    for i = 1:numel(config_list)
        cfg = feval(config_list{i});
        plot_experiment(cfg);
    end
end



