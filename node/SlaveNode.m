classdef SlaveNode < PTPNode
    properties
        clock
        fsm
    end
    methods
        function obj = SlaveNode(clock, fsm)
            if nargin >= 2
                % Validate that fsm is actually a SlaveFSM
                if ~isa(fsm, 'SlaveFSM')
                    error('SlaveNode requires a SlaveFSM object, got %s', class(fsm));
                end
                obj.clock = clock;
                obj.fsm = fsm;
            else
                obj.clock = SlaveClock();
                obj.fsm = SlaveFSM();
            end
        end
        
        function obj = syntonize(obj, rx_freq)
            obj.clock = obj.clock.syntonize(rx_freq);
        end

        function obj = offset_correction(obj)
            if obj.just_synced()
                obj.clock = obj.clock.correct_offset(obj.fsm.last_offset);
            end
        end

        function [last_offset, last_delay] = get_ptp_estimate(obj)
            last_offset = obj.fsm.last_offset;
            last_delay = obj.fsm.last_delay;
        end

        function last_rt_delay = get_ptp_rt_delay(obj)
            last_rt_delay = obj.fsm.last_rt_delay;
        end

        function just_synced = just_synced(obj)
            just_synced = obj.fsm.just_synced;
        end

        function obj = reset_ptp_estimate(obj)
            obj.fsm.last_offset = NaN;
            obj.fsm.last_delay = NaN;
        end
    end
end

