classdef Clock
% CLOCK  Oscillator model with power-law frequency noise.
%
% Created from an oscillator params struct (see ox_perfect, ox_ocxo, ox_csac):
%   ox.f0                   – nominal frequency [Hz]
%   ox.delta_f0             – constant offset [Hz]
%   ox.alpha                – linear drift [Hz/s]
%   ox.h                    – [h_-2, h_-1, h_0, h_1, h_2] PSD coefficients
%   ox.timestamp_resolution – 0 = infinite precision, >0 = cycles of resolution
%
% Power-law noise references:
%   IEEE Std 1139-2008; Kasdin & Walter (1992).
%   NOTE: h_-1 (Flicker FM) and h_1 (Flicker PM) use a moving-average
%   approximation.  A proper Kasdin-Walter FIR implementation would be
%   more accurate for those two processes.

    properties
        f0      % Nominal frequency [Hz]
        f       % Current frequency [Hz]
        phi     % Current phase [rad]
        t_accum = 0

        % Oscillator parameters
        delta_f0             = 0
        alpha                = 0
        h                    = zeros(1,5)
        timestamp_resolution = 0
    end

    properties (Access = private)
        % IIR filter states for colored noise (h_-2, h_-1, h_1)
        fs_neg2
        fs_neg1
        fs_pos1
    end

    methods
        function obj = Clock(ox, t0)
            if nargin == 0; ox = struct(); t0 = 0; end
            if nargin == 1; t0 = 0; end

            obj.f0                   = getfield_default(ox, 'f0',    125e6);
            obj.delta_f0             = getfield_default(ox, 'delta_f0', 0);
            obj.alpha                = getfield_default(ox, 'alpha',    0);
            obj.h                    = getfield_default(ox, 'h',   zeros(1,5));
            obj.timestamp_resolution = getfield_default(ox, 'timestamp_resolution', 0);

            obj = obj.init_filters();
            obj.phi = 0;
            obj.f   = obj.f0 + obj.delta_f0;
            if t0 ~= 0
                obj = obj.advance(t0);
            end
        end

        function obj = advance(obj, dt)
            if dt <= 0; return; end
            obj.t_accum = obj.t_accum + dt;
            [dy, obj]   = obj.generate_noise(dt);
            df    = obj.delta_f0 + obj.alpha * obj.t_accum + dy * obj.f0;
            obj.f = obj.f0 + df;
            obj.phi = obj.phi + 2*pi*obj.f*dt;
        end

        function ts = get_time(obj)
            ts = obj.phi / (2*pi*obj.f0);
        end

        function ts = get_timestamp(obj)
            ts = obj.get_time();
            if obj.timestamp_resolution == 0; return; end
            quant_step = (1/obj.f) / obj.timestamp_resolution;
            ts = round(ts / quant_step) * quant_step;
        end

        function obj = reset(obj, t0)
            obj = obj.init_filters();
            obj.t_accum = 0;
            obj.phi     = 0;
            obj.f       = obj.f0 + obj.delta_f0;
            if nargin > 1 && t0 ~= 0
                obj = obj.advance(t0);
            end
        end
    end

    % ------------------------------------------------------------------
    methods (Access = private)

        function obj = init_filters(obj)
            n = 20;
            obj.fs_neg2 = zeros(n, 1);
            obj.fs_neg1 = zeros(n, 1);
            obj.fs_pos1 = zeros(n, 1);
        end

        function [dy, obj] = generate_noise(obj, dt)
            dy = 0;
            h  = obj.h;

            if dt <= 1e-12
                return;
            end

            % h_-2: Random Walk FM  (integrated white noise → frequency random walk)
            if h(1) > 0
                w = randn * sqrt(h(1) / dt);
                obj.fs_neg2(2:end) = obj.fs_neg2(1:end-1);
                obj.fs_neg2(1)     = obj.fs_neg2(1) + w;
                dy = dy + obj.fs_neg2(1);
            end

            % h_-1: Flicker FM  (approximate moving-average; see class note)
            if h(2) > 0
                w = randn * sqrt(h(2) * 2*log(2));
                obj.fs_neg1(2:end) = obj.fs_neg1(1:end-1);
                obj.fs_neg1(1)     = w;
                n  = min(10, length(obj.fs_neg1));
                wt = 1 ./ sqrt(1:n);
                dy = dy + sum(obj.fs_neg1(1:n) .* wt') / sqrt(dt);
            end

            % h_0: White FM
            % σ_y(τ) = sqrt(h_0 / (2τ))  [IEEE 1139-2008]
            if h(3) > 0
                dy = dy + randn * sqrt(h(3) / (2*dt));
            end

            % h_1: Flicker PM  (approximate; see class note)
            if h(4) > 0
                w = randn * sqrt(h(4) * 2*log(2) / dt);
                obj.fs_pos1(2:end) = obj.fs_pos1(1:end-1);
                obj.fs_pos1(1)     = w;
                n  = min(5, length(obj.fs_pos1));
                wt = 1 ./ sqrt(1:n);
                dy = dy + sum(obj.fs_pos1(1:n) .* wt');
            end

            % h_2: White PM  (second-differenced white phase noise)
            % σ_y contribution ∝ sqrt(h_2 / (2τ³))
            if h(5) > 0
                dy = dy + randn * sqrt(h(5) / (2*dt^3));
            end

            if ~isfinite(dy); dy = 0; end
        end
    end
end
