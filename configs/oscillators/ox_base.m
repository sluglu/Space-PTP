function ox = ox_base()
% OX_BASE  Template for writing a new oscillator config.
%
% An oscillator config returns a plain struct with these fields:
%
%   f0                   – nominal frequency [Hz]
%   delta_f0             – initial frequency offset [Hz]  (0 = none)
%   alpha                – linear frequency drift [Hz/s]  (0 = none)
%   h                    – power-law noise coefficients [h_-2, h_-1, h_0, h_1, h_2]
%                          Set unused terms to 0. Units follow IEEE 1139-2008 S_y(f).
%   timestamp_resolution – quantisation step for timestamps [s]  (0 = infinite precision)
%
% Noise process summary:
%   h(1) h_-2  Random Walk FM  — integrate white FM noise
%   h(2) h_-1  Flicker FM      — 1/f frequency noise (approx.)
%   h(3) h_0   White FM        — flat frequency noise
%   h(4) h_1   Flicker PM      — 1/f phase noise     (approx.)
%   h(5) h_2   White PM        — flat phase noise

error('ox_base is a template — copy and rename it for your oscillator.');
end
