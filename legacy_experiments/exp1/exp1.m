clear; clc;

%% Parameters main sim
verbose = false;
asym_delay_std = logspace(-12, -2, 100); % Use fewer points but logarithmic spacing

%% Main simulation setup

off_error_mean = nan(length(asym_delay_std), 1);
length_asym_delay_std = length(asym_delay_std);

% Create progress tracker object
progress = ProgressTracker(length_asym_delay_std);

% Create DataQueue and bind to tracker
dq = parallel.pool.DataQueue;
afterEach(dq, @(~) progress.update());

% Start waitbar
progress.start();

fprintf('Starting simulation with %d asymetric delay standard deviation values...\n', length(asym_delay_std));



%% Simulation loop with progress tracking
tic; % Start timing
parfor i = 1:length(asym_delay_std)
    try
        off_error = simulate_ptp_gaussian(asym_delay_std(i), verbose);
        if ~isempty(off_error)
            off_error_mean(i) = abs(mean(off_error));
        end
        fprintf("Completed simulation %d/%d \n", i, length_asym_delay_std);
    catch ME
        fprintf("Error in simulation %d: %s\n", i, ME.message);
        off_error_mean(i) = NaN;
    end
    send(dq, i); 
end

% Clean up
progress.finish();

elapsed_time = toc;
fprintf('Simulation completed in %.2f seconds\n', elapsed_time);

%% Plotting
figure('Position', [100 100 1200 800]);

% Main plot
%subplot(2,1,1);
valid_indices = ~isnan(off_error_mean);
loglog(asym_delay_std(valid_indices), off_error_mean(valid_indices), 'b-', 'LineWidth', 2);
hold on;
grid on;
xlabel('Asymetric Delay Standard Deviation (s)');
ylabel('Mean Absolute Offset Error (s)');
title('PTP Offset Error vs Asymetric Delay Standard Deviation');

% Add trend line if possible
if sum(valid_indices) > 10
    % Fit a line in log space
    log_delay = log10(asym_delay_std(valid_indices));
    log_error = log10(off_error_mean(valid_indices));
    p = polyfit(log_delay, log_error, 1);
    trend_line = 10.^(polyval(p, log_delay));
    plot(asym_delay_std(valid_indices), trend_line, 'r--', 'LineWidth', 1.5);
    legend('Simulation Data', sprintf('Trend (slope = %.2f)', p(1)), 'Location', 'best');
end

% Sample index table
num_samples = 10;
sample_indices = round(linspace(1, length(asym_delay_std), num_samples));
sampled_std   = asym_delay_std(sample_indices(:));
sampled_error = off_error_mean(sample_indices(:));
sampled_log_time = log10(sampled_std(:));
T_sample = table(sample_indices(:), sampled_std(:), sampled_error(:), ...
    'VariableNames', {'Index', 'AsymDelayStd (s)', 'MeanOffsetError (s)'});

f = figure('Name', 'Sampled Offset Error Table', 'NumberTitle', 'off', ...
           'Position', [100, 100, 700, 250]);

uitable(f, ...
    'Data', T_sample{:,:}, ...
    'ColumnName', T_sample.Properties.VariableNames, ...
    'Units', 'normalized', ...
    'Position', [0 0 1 1], ...
    'FontSize', 12);

% Display summary statistics
fprintf('\nSummary Statistics:\n');
fprintf('Min offset error: %.3e s\n', min(off_error_mean(valid_indices)));
fprintf('Max offset error: %.3e s\n', max(off_error_mean(valid_indices)));
fprintf('Median offset error: %.3e s\n', median(off_error_mean(valid_indices)));
fprintf('Mean offset error: %.3e s\n', mean(off_error_mean(valid_indices)));

%% Save results
save('experiment/exp1/results/exp1_PTP_offset_error_vs_asym_delay_STD.mat', 'asym_delay_std', 'off_error_mean', 'elapsed_time');
fprintf('Results saved to experiment/exp1/results/exp1_PTP_offset_error_vs_asym_delay_STD.mat\n');