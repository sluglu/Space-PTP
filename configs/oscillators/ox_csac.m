function ox = ox_csac()
% Rubidium CSAC — SA45, 10 MHz.
% h coefficients for S_y(f): [h_-2, h_-1, h_0, h_1, h_2]
    ox = struct( ...
        'f0',                   10e6, ...
        'delta_f0',             (rand()*2 - 1) * 5e-4, ...       % ±5e-4 Hz
        'alpha',                (rand()*2 - 1) * 3.15e-9, ...    % ±3.15e-9 Hz/s
        'h',                    [0, 0, 1.8e-19, 0, 2.0e-28], ...
        'timestamp_resolution', 0);
end
