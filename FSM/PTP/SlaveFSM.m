classdef SlaveFSM < NodeFSM
    properties
        t1; t2; t3; t4

        waiting_followup   = false
        waiting_delay_resp = false
        synced             = false
        just_synced        = false

        last_offset   = NaN
        last_delay    = NaN
        last_rt_delay = NaN

        msg_queue = {}
        verbose   = false
    end

    methods
        function obj = SlaveFSM(verbose)
            if nargin > 0; obj.verbose = verbose; end
        end

        function obj = receive(obj, msg, ts)
            obj.msg_queue{end+1} = struct('msg', msg, 'ts', ts);
            if obj.verbose
                fprintf('[SlaveFSM] Received %s at ts=%.9e\n', msg.type, ts);
            end
        end

        function [obj, msgs] = step(obj, ts)
            msgs      = {};
            remaining = {};
            obj.just_synced = false;

            for k = 1:length(obj.msg_queue)
                msg    = obj.msg_queue{k}.msg;
                msg_ts = obj.msg_queue{k}.ts;

                switch msg.type
                    case 'SYNC'
                        obj.t2 = msg_ts;
                        obj.waiting_followup = true;

                    case 'FOLLOW_UP'
                        obj.t1 = msg.t1;
                        obj.waiting_followup = false;
                        obj.t3 = ts;
                        msgs{end+1} = struct('type', 'DELAY_REQ');
                        obj.waiting_delay_resp = true;

                    case 'DELAY_RESP'
                        if obj.waiting_delay_resp
                            obj.t4 = msg.t4;
                            obj.waiting_delay_resp = false;
                            obj.synced      = true;
                            obj.just_synced = true;

                            obj.last_rt_delay = (obj.t2 - obj.t1) + (obj.t4 - obj.t3);
                            obj.last_delay    = obj.last_rt_delay / 2;
                            obj.last_offset   = ((obj.t2 - obj.t1) - (obj.t4 - obj.t3)) / 2;

                            if obj.verbose
                                fprintf('[SlaveFSM] t1=%.9e t2=%.9e t3=%.9e t4=%.9e\n', obj.t1, obj.t2, obj.t3, obj.t4);
                                fprintf('[SlaveFSM] offset=%.9e  delay=%.9e\n', obj.last_offset, obj.last_delay);
                            end
                        end

                    otherwise
                        remaining{end+1} = obj.msg_queue{k};
                end
            end
            obj.msg_queue = remaining;
        end

        function obj = reset(obj)
            obj.last_offset        = NaN;
            obj.last_delay         = NaN;
            obj.last_rt_delay      = NaN;
            obj.just_synced        = false;
            obj.synced             = false;
            obj.waiting_followup   = false;
            obj.waiting_delay_resp = false;
            obj.msg_queue          = {};
        end
    end
end
