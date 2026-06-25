function clk = ox_ocxo(t0, options)
% High-performance OCXO — OX-249, 100 MHz.
% Returns a ready Clock object.
%
%   ox_ocxo()
%   ox_ocxo(t0)
%   ox_ocxo(t0, Name, Value, ...)
%
% Optional name-value overrides:
%   f0                   Nominal frequency [Hz]               (100e6)
%   delta_f0             Initial frequency offset [Hz]        (±50 Hz random)
%   alpha                Frequency drift [Hz/s]               (±1.58e-6 random)
%   h                    Power-law noise coefficients [1x5]   ([0, 4.62e-23, 1.58e-25, 0, 1e-32])
%   timestamp_resolution Timestamp quantization steps         (0 = infinite precision)
%   kw_n_neg1            Flicker FM FIR length                (64)
    arguments
        t0 (1,1) double = 0
        options.f0                   (1,1) double = 100e6
        options.delta_f0             (1,1) double = (rand()*2 - 1) * 50
        options.alpha                (1,1) double = (rand()*2 - 1) * 1.58e-6
        options.h                    (1,5) double = [0, 4.62e-23, 1.58e-25, 0, 1.0e-32]
        options.timestamp_resolution (1,1) double = 0
        options.kw_n_neg1            (1,1) double = 64
    end
    clk = Clock(options, t0);
end
