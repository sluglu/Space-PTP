classdef NoiseProfile
    properties
        delta_f0;     % Constant frequency offset [Hz]
        alpha;        % Linear drift [Hz/s]
        timestamp_resolution; % number of cycles of resolution for timestamps
        power_law_coeffs;  % [h_{-2}, h_{-1}, h_0, h_1, h_2] for the Power Spectral Density of fractional frequency noise, S_y(f).
        filter_states; % Filter states for power law noise generation
    end

    methods
        function obj = NoiseProfile(params)
            if nargin == 0
                params = struct();
            end
            obj.delta_f0 = getfield_default(params, 'delta_f0', 0);
            obj.alpha = getfield_default(params, 'alpha', 0);
            obj.timestamp_resolution = getfield_default(params, 'timestamp_resolution', 0);
            obj.power_law_coeffs = getfield_default(params, 'power_law_coeffs', [0 0 0 0 0]);
            obj = obj.initialize_power_law_filters();
        end

        function obj = initialize_power_law_filters(obj)
            % Initialize filter states for power law noise generation
            % Based on Kasdin & Walter (1992) approach
            
            % Number of filter states needed for each noise process
            n_states = 20; % Adjustable for accuracy vs. speed tradeoff
            
            obj.filter_states = struct();
            
            % h_{-2}: Random walk FM (f^{-2} PSD)
            if length(obj.power_law_coeffs) >= 1 && obj.power_law_coeffs(1) > 0
                obj.filter_states.h_neg2 = zeros(n_states, 1);
            end
            
            % h_{-1}: Flicker walk FM (f^{-1} PSD) 
            if length(obj.power_law_coeffs) >= 2 && obj.power_law_coeffs(2) > 0
                obj.filter_states.h_neg1 = zeros(n_states, 1);
            end
            
            % h_0: White FM (f^0 PSD) - no filter needed
            % h_1: Flicker PM (f^1 PSD)
            if length(obj.power_law_coeffs) >= 4 && obj.power_law_coeffs(4) > 0
                obj.filter_states.h_1 = zeros(n_states, 1);
            end
            
            % h_2: White PM (f^2 PSD) - no filter needed
        end
        
        function [dy, obj] = generatePowerLawNoise(obj, dt)
            % Generate power law noise based on h coefficients
            % Following IEEE Std 1139-2008 definitions
            
            dy = 0;
            tau = dt; % Measurement interval
            
            % Ensure tau is not zero or negative
            if tau <= 1e-12
                dy = 0;
                return;
            end
            
            % h_{-2}: Random Walk Frequency Modulation (RWFM)
            if obj.power_law_coeffs(1) > 0 && isfield(obj.filter_states, 'h_neg2') && ~isempty(obj.filter_states.h_neg2)
                % Random walk FM - integrated white noise
                white_noise = randn * sqrt(obj.power_law_coeffs(1) * tau);
                obj.filter_states.h_neg2(2:end) = obj.filter_states.h_neg2(1:end-1);
                obj.filter_states.h_neg2(1) = obj.filter_states.h_neg2(1) + white_noise;
                rwfm_contribution = obj.filter_states.h_neg2(1);
                dy = dy + rwfm_contribution;
            end
            
            % h_{-1}: Flicker Walk Frequency Modulation (FWFM)  
            if obj.power_law_coeffs(2) > 0 && isfield(obj.filter_states, 'h_neg1') && ~isempty(obj.filter_states.h_neg1)
                % Flicker walk FM - use first-order approximation
                white_noise = randn * sqrt(obj.power_law_coeffs(2) * 2 * log(2));
                obj.filter_states.h_neg1(2:end) = obj.filter_states.h_neg1(1:end-1);
                obj.filter_states.h_neg1(1) = white_noise;
                
                % Simple moving average with 1/sqrt(k) weights
                n_terms = min(10, length(obj.filter_states.h_neg1)); % Limit for stability
                weights = 1 ./ sqrt(1:n_terms);
                fwfm_contribution = sum(obj.filter_states.h_neg1(1:n_terms) .* weights') / sqrt(tau);
                dy = dy + fwfm_contribution;
            end
            
            % h_0: White Frequency Modulation (WFM)
            if obj.power_law_coeffs(3) > 0
                wfm_contribution = randn * sqrt(obj.power_law_coeffs(3) / tau);
                dy = dy + wfm_contribution;
            end
            
            % h_1: Flicker Phase Modulation (FPM) 
            if obj.power_law_coeffs(4) > 0 && isfield(obj.filter_states, 'h_1') && ~isempty(obj.filter_states.h_1)
                % Flicker PM - differentiating flicker phase noise
                white_noise = randn * sqrt(obj.power_law_coeffs(4) * 2 * log(2) / tau);
                obj.filter_states.h_1(2:end) = obj.filter_states.h_1(1:end-1);
                obj.filter_states.h_1(1) = white_noise;
                
                % Weighted sum for flicker process, then differentiate
                n_terms = min(5, length(obj.filter_states.h_1));
                weights = 1 ./ sqrt(1:n_terms);
                fpm_contribution = sum(obj.filter_states.h_1(1:n_terms) .* weights');
                dy = dy + fpm_contribution;
            end
            
            % h_2: White Phase Modulation (WPM)
            if obj.power_law_coeffs(5) > 0
                % White PM - second derivative of white phase
                wpm_contribution = randn * sqrt(3 * obj.power_law_coeffs(5) / tau^3);
                dy = dy + wpm_contribution;
            end
            
            % Sanity check - ensure dy is finite
            if ~isfinite(dy)
                warning('Non-finite frequency noise detected, setting to zero');
                dy = 0;
            end
        end

        function obj = reset(obj)
            obj = obj.initialize_power_law_filters();
        end
        
        function obj = set_power_law_params(obj, h_coeffs)
            % Convenience method to set power law parameters
            % h_coeffs = [h_{-2}, h_{-1}, h_0, h_1, h_2] for the Power Spectral Density
            % of fractional frequency noise, S_y(f).
            
            obj.power_law_coeffs = h_coeffs;
            obj = obj.initialize_power_law_filters();
        end
    end
end

