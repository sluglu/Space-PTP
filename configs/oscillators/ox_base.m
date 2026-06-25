function clk = ox_base(t0, overrides)
% OX_BASE  Template for a new oscillator config.
%
% Returns a ready Clock object.  Never construct Clock directly — call an
% oscillator config instead:
%
%   clk = ox_ocxo();
%   clk = ox_ocxo(t0);
%   clk = ox_ocxo(t0, struct('alpha', 0, 'kw_n_neg1', 4096));
%
% Spec fields (set before calling Clock):
%
%   f0                   – nominal frequency [Hz]
%   delta_f0             – initial frequency offset [Hz]
%   alpha                – linear frequency drift [Hz/s]
%   h                    – [h_-2, h_-1, h_0, h_1, h_2]  IEEE 1139-2008 S_y(f)
%   timestamp_resolution – quantisation step [s]  (0 = infinite precision)
%   kw_n_neg1            – Kasdin-Walter taps for h_{-1}; flicker FM valid up to
%                          tau ≈ kw_n_neg1·dt/2.  Default 64.
%
% Pattern:
%
%   function clk = ox_myosc(t0, overrides)
%       if nargin < 1; t0 = 0; end
%       spec = struct('f0',...,'delta_f0',...,'alpha',...,'h',[...],'timestamp_resolution',0);
%       if nargin > 1 && ~isempty(overrides)
%           for fn = fieldnames(overrides)'; spec.(fn{1}) = overrides.(fn{1}); end
%       end
%       clk = Clock(spec, t0);
%   end

error('ox_base is a template — copy and rename it for your oscillator.');
end
