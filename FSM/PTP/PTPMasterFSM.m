classdef PTPMasterFSM < NodeFSM
    properties
        last_offset = NaN
        last_delay  = NaN
        sync_interval
        next_sync_time = 0
        slave_id
        msg_queue = {}
        verbose   = false
    end

    methods
        function obj = PTPMasterFSM(slave_id, options)
        % PTPMasterFSM  IEEE 1588 master node state machine.
        %
        %   PTPMasterFSM(slave_id)
        %   PTPMasterFSM(slave_id, Name, Value, ...)
        %
        % Optional name-value overrides:
        %   sync_interval   SYNC period [s]                (1)
        %   verbose         Print FSM state transitions    (false)
            arguments
                slave_id (1,:) char
                options.sync_interval (1,1) double  = 1
                options.verbose       (1,1) logical = false
            end
            obj.slave_id      = slave_id;
            obj.sync_interval = options.sync_interval;
            obj.verbose       = options.verbose;
        end

        function obj = receive(obj, msg, ts)
            obj.msg_queue{end+1} = struct('msg', msg, 'ts', ts);
            if obj.verbose
                fprintf('[PTPMasterFSM] Received %s at ts=%.9e\n', msg.type, ts);
            end
        end

        function [obj, msgs] = step(obj, ts)
            msgs = {};

            if ts >= obj.next_sync_time
                msgs{end+1} = struct('type', 'SYNC',      'to', obj.slave_id);
                msgs{end+1} = struct('type', 'FOLLOW_UP', 'to', obj.slave_id, 't1', ts);
                obj.next_sync_time = ts + obj.sync_interval;
            end

            remaining = {};
            for k = 1:length(obj.msg_queue)
                msg = obj.msg_queue{k}.msg;
                if strcmp(msg.type, 'DELAY_REQ')
                    msgs{end+1} = struct('type', 'DELAY_RESP', 'to', msg.from, 't4', obj.msg_queue{k}.ts);
                else
                    remaining{end+1} = obj.msg_queue{k};
                end
            end
            obj.msg_queue = remaining;
        end

        function obj = reset(obj)
            obj.msg_queue = {};
        end
    end
end
