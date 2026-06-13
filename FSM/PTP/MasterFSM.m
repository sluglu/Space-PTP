classdef MasterFSM < NodeFSM
    properties
        sync_interval
        next_sync_time = 0
        msg_queue = {}
        verbose   = false
    end

    methods
        function obj = MasterFSM(sync_interval, verbose)
            if nargin > 0; obj.sync_interval = sync_interval; else; obj.sync_interval = 1; end
            if nargin > 1; obj.verbose = verbose; end
        end

        function obj = receive(obj, msg, ts)
            obj.msg_queue{end+1} = struct('msg', msg, 'ts', ts);
            if obj.verbose
                fprintf('[MasterFSM] Received %s at ts=%.9e\n', msg.type, ts);
            end
        end

        function [obj, msgs] = step(obj, ts)
            msgs = {};

            % Send SYNC + FOLLOW_UP at each sync interval
            if ts >= obj.next_sync_time
                msgs{end+1} = struct('type', 'SYNC');
                msgs{end+1} = struct('type', 'FOLLOW_UP', 't1', ts);
                obj.next_sync_time = ts + obj.sync_interval;
            end

            % Respond to queued DELAY_REQ messages
            remaining = {};
            for k = 1:length(obj.msg_queue)
                msg = obj.msg_queue{k}.msg;
                if strcmp(msg.type, 'DELAY_REQ')
                    msgs{end+1} = struct('type', 'DELAY_RESP', 't4', obj.msg_queue{k}.ts);
                else
                    remaining{end+1} = obj.msg_queue{k};
                end
            end
            obj.msg_queue = remaining;
        end
    end
end
