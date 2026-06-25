classdef Clock
% CLOCK  Oscillator model with power-law frequency noise.
%
% Do not construct directly — use an oscillator config:
%   clk = ox_ocxo();   clk = ox_perfect();   clk = ox_csac();
%
% Power-law noise: IEEE Std 1139-2008; Kasdin & Walter (1992).
% Value class — always assign the return value: clk = clk.advance(dt).
%   h_{-1} (Flicker FM) and h_{+1} (Flicker PM) use the Kasdin-Walter FIR method.

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

        % Fractional frequency correction applied by external servo [dimensionless, y = df/f0]
        % Set by the FSM each step; enters advance() as servo_y * f0 [Hz].
        servo_y = 0
    end

    properties
        % Kasdin-Walter FIR lengths — increase for long-tau simulations.
        % Rule of thumb: kw_n_neg1 * dt > 2 * tau_max for valid flicker FM.
        kw_n_neg1 = 64   % taps for h_{-1} flicker FM  (default covers tau up to ~32*dt)
        kw_n_pos1 = 32   % taps for h_{+1} flicker PM
    end

    properties (Access = private)
        rw_state      % scalar accumulator for h_{-2} random walk FM

        kw_buf_neg1   % noise history buffer for h_{-1} (flicker FM)
        kw_c_neg1     % Kasdin-Walter FIR coefficients for h_{-1}

        kw_buf_pos1   % noise history buffer for h_{+1} (flicker PM)
        kw_c_pos1     % Kasdin-Walter FIR coefficients for h_{+1}
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
            obj.kw_n_neg1            = getfield_default(ox, 'kw_n_neg1', 64);
            obj.kw_n_pos1            = getfield_default(ox, 'kw_n_pos1', 32);

            obj = obj.init_filters();
            obj.phi = 0;
            obj.f   = obj.f0 + obj.delta_f0;
            if t0 ~= 0
                obj.phi = 2*pi * obj.f * t0;
            end
        end

        function obj = advance(obj, dt)
            if dt <= 0; return; end
            obj.t_accum = obj.t_accum + dt;
            f_old       = obj.f;
            [dy, obj]   = obj.generate_noise(dt);
            df    = obj.delta_f0 + obj.servo_y * obj.f0 + obj.alpha * obj.t_accum + dy * obj.f0;
            obj.f = obj.f0 + df;
            % Trapezoid integration avoids bias from drift
            obj.phi = obj.phi + 2*pi * ((f_old + obj.f) / 2) * dt;
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
            obj.t_accum  = 0;
            obj.phi      = 0;
            obj.f        = obj.f0 + obj.delta_f0;
            obj.servo_y = 0;
            if nargin > 1 && t0 ~= 0
                obj.phi = 2*pi * obj.f * t0;
            end
        end
    end

    % ------------------------------------------------------------------
    methods (Access = private)

        function obj = init_filters(obj)
            obj.rw_state = 0;

            % Kasdin-Walter FIR for h_{-1} (flicker FM, 1/f PSD)
            % Coefficients: d_0=1, d_k = d_{k-1}*(k-1.5)/(k-1)  [half-order integrator]
            N = obj.kw_n_neg1;
            c = ones(N, 1);
            for k = 2:N
                c(k) = c(k-1) * (k - 1.5) / (k - 1);
            end
            obj.kw_c_neg1   = c;
            obj.kw_buf_neg1 = zeros(N, 1);

            % Kasdin-Walter FIR for h_{+1} (flicker PM, f PSD)
            % Coefficients: d_0=1, d_k = d_{k-1}*(k-2.5)/(k-1)  [half-order differentiator]
            M = obj.kw_n_pos1;
            c = ones(M, 1);
            for k = 2:M
                c(k) = c(k-1) * (k - 2.5) / (k - 1);
            end
            obj.kw_c_pos1   = c;
            obj.kw_buf_pos1 = zeros(M, 1);
        end

        function [dy, obj] = generate_noise(obj, dt)
            dy = 0;
            h  = obj.h;

            if dt <= 1e-12
                return;
            end

            % h_{-2}: Random Walk FM — accumulated white noise
            if h(1) > 0
                obj.rw_state = obj.rw_state + randn * sqrt(h(1) / dt);
                dy = dy + obj.rw_state;
            end

            % h_{-1}: Flicker FM — Kasdin-Walter FIR (half-order integration)
            if h(2) > 0
                w = randn * sqrt(h(2) * 2*log(2) / dt);
                obj.kw_buf_neg1 = [w; obj.kw_buf_neg1(1:end-1)];
                dy = dy + obj.kw_c_neg1' * obj.kw_buf_neg1;
            end

            % h_{0}: White FM
            if h(3) > 0
                dy = dy + randn * sqrt(h(3) / (2*dt));
            end

            % h_{+1}: Flicker PM — Kasdin-Walter FIR (half-order differentiation)
            if h(4) > 0
                w = randn * sqrt(h(4) * 2*log(2) / dt);
                obj.kw_buf_pos1 = [w; obj.kw_buf_pos1(1:end-1)];
                dy = dy + obj.kw_c_pos1' * obj.kw_buf_pos1;
            end

            % h_{+2}: White PM
            if h(5) > 0
                dy = dy + randn * sqrt(h(5) / (2*dt^3));
            end

            if ~isfinite(dy)
                warning('Clock:nonFiniteNoise', 'Non-finite noise at t_accum=%.3f; clamping to 0.', obj.t_accum);
                dy = 0;
            end
        end
    end
end
