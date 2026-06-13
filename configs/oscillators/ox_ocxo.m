function ox = ox_ocxo()
% High-performance OCXO — OX-249, 100 MHz.
% h coefficients for S_y(f): [h_-2, h_-1, h_0, h_1, h_2]
    ox = struct( ...
        'f0',                   100e6, ...
        'delta_f0',             (rand()*2 - 1) * 50, ...         % ±50 Hz
        'alpha',                (rand()*2 - 1) * 1.58e-6, ...    % ±1.58e-6 Hz/s
        'h',                    [0, 4.62e-23, 1.58e-25, 0, 1.0e-32], ...
        'timestamp_resolution', 0);
end
