function clk = ox_csac(t0, options)
% Rubidium CSAC — SA45s, 10 MHz.
% Returns a ready Clock object.
%
%   ox_csac()
%   ox_csac(t0)
%   ox_csac(t0, Name, Value, ...)
%
% Optional name-value overrides:
%   f0                   Nominal frequency [Hz]               (10e6)
%   delta_f0             Initial frequency offset [Hz]        (±5e-4 Hz random)
%   alpha                Frequency drift [Hz/s]               (±3.15e-9 random)
%   h                    Power-law noise coefficients [1x5]   ([0, 0, 1.8e-19, 0, 2e-28])
%   timestamp_resolution Timestamp quantization steps         (0 = infinite precision)
%   kw_n_neg1            Flicker FM FIR length                (64)
    arguments
        t0 (1,1) double = 0
        options.f0                   (1,1) double = 10e6
        options.delta_f0             (1,1) double = (rand()*2 - 1) * 5e-4
        options.alpha                (1,1) double = (rand()*2 - 1) * 3.15e-9
        options.h                    (1,5) double = [0, 0, 1.8e-19, 0, 2.0e-28]
        options.timestamp_resolution (1,1) double = 0
        options.kw_n_neg1            (1,1) double = 64
    end
    clk = Clock(options, t0);
end
