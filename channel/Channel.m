classdef Channel
% CHANNEL  Computes propagation delays and Doppler between two platforms.
%
% By default only the geometric delay (from precomputed sat_data) is active.
% Add physical effects with add_effect():
%
%   ch = Channel(sat_data);
%   ch = ch.add_effect(@shapiro_delay);   % example future effect
%
% An effect function has the signature:
%   delta = fn(state)
% where state is a struct with fields:
%   state.t             – simulation time [s]
%   state.fwd_geometric – geometric master→slave delay [s]
%   state.bwd_geometric – geometric slave→master delay [s]
%   state.fwd_doppler   – master→slave fractional Doppler [df/f₀]
%   state.bwd_doppler   – slave→master fractional Doppler [df/f₀]
%   state.pos_master    – ECI position of master [3×1, m]
%   state.vel_master    – ECI velocity of master [3×1, m/s]
%   state.pos_slave     – ECI position of slave  [3×1, m]
%   state.vel_slave     – ECI velocity of slave  [3×1, m/s]
%
% and delta = struct('fwd', fwd_delay_s, 'bwd', bwd_delay_s).
%
% Example — Shapiro delay (GR gravitational path lengthening):
%   function d = shapiro_delay(state)
%       GM = 3.986004418e14; c = 299792458;
%       r_m  = norm(state.pos_master);
%       r_s  = norm(state.pos_slave);
%       r_ms = norm(state.pos_slave - state.pos_master);
%       dt   = (2*GM/c^3) * log((r_m + r_s + r_ms) / (r_m + r_s - r_ms));
%       d    = struct('fwd', dt, 'bwd', dt);
%   end

    properties
        sat_data   % precomputed interpolants and raw satellite data
        effects    % cell array of effect functions: delta = fn(state)
    end

    methods
        function obj = Channel(sat_data)
            obj.sat_data = sat_data;
            obj.effects  = {@Channel.geometric};
        end

        function obj = add_effect(obj, fn)
            obj.effects{end+1} = fn;
        end

        function ch = compute(obj, t)
            state = obj.build_state(t);

            ch.fwd_delay   = 0;
            ch.bwd_delay   = 0;
            ch.fwd_doppler = state.fwd_doppler;
            ch.bwd_doppler = state.bwd_doppler;

            for k = 1:length(obj.effects)
                d = obj.effects{k}(state);
                ch.fwd_delay = ch.fwd_delay + d.fwd;
                ch.bwd_delay = ch.bwd_delay + d.bwd;
            end
        end
    end

    % ------------------------------------------------------------------
    methods (Access = private)
        function state = build_state(obj, t)
            sd = obj.sat_data;

            state.t             = t;
            state.fwd_geometric = sd.forward_delay_interp(t);
            state.bwd_geometric = sd.backward_delay_interp(t);
            state.fwd_doppler   = sd.forward_doppler_interp(t);
            state.bwd_doppler   = sd.backward_doppler_interp(t);

            % Position/velocity — available if precomputed, NaN otherwise
            if isfield(sd, 'pos_master')
                ts = sd.tspan;
                state.pos_master = interp1(ts, sd.pos_master', t, 'linear', NaN)';
                state.vel_master = interp1(ts, sd.vel_master', t, 'linear', NaN)';
                state.pos_slave  = interp1(ts, sd.pos_slave',  t, 'linear', NaN)';
                state.vel_slave  = interp1(ts, sd.vel_slave',  t, 'linear', NaN)';
            else
                state.pos_master = NaN(3,1);
                state.vel_master = NaN(3,1);
                state.pos_slave  = NaN(3,1);
                state.vel_slave  = NaN(3,1);
            end
        end
    end

    % ------------------------------------------------------------------
    methods (Static)
        function d = geometric(state)
            d = struct('fwd', state.fwd_geometric, 'bwd', state.bwd_geometric);
        end
    end
end
