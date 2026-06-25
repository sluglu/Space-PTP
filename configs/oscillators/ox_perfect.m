function clk = ox_perfect(t0, options)
% Perfect oscillator — no noise, no drift, infinite timestamp precision.
% Returns a ready Clock object.
%
%   ox_perfect()
%   ox_perfect(t0)
%   ox_perfect(t0, Name, Value, ...)
%
% Optional name-value overrides:
%   f0                   Nominal frequency [Hz]               (100e6)
%   delta_f0             Initial frequency offset [Hz]        (0)
%   alpha                Frequency drift [Hz/s]               (0)
%   h                    Power-law noise coefficients [1x5]   (zeros)
%   timestamp_resolution Timestamp quantization steps         (0 = infinite precision)
    arguments
        t0 (1,1) double = 0
        options.f0                   (1,1) double = 100e6
        options.delta_f0             (1,1) double = 0
        options.alpha                (1,1) double = 0
        options.h                    (1,5) double = zeros(1,5)
        options.timestamp_resolution (1,1) double = 0
    end
    clk = Clock(options, t0);
end
