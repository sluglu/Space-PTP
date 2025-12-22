classdef SlaveFSM < PTPFSM
    properties
        t1  % master sends SYNC (from FOLLOW_UP)
        t2  % slave receives SYNC
        t3  % slave sends DELAY_REQ
        t4  % master replies with DELAY_RESP

        waiting_followup
        waiting_delay_resp
        synced
        just_synced  % Flag to indicate fresh sync completion

        last_offset
        last_delay
        last_rt_delay
    end

    methods
        function obj = SlaveFSM(verbose)
            if nargin > 0
                obj.verbose = verbose;
            else
                obj.verbose = false;
            end
            obj.synced = false;
            obj.just_synced = false;
            obj.waiting_followup = false;
            obj.waiting_delay_resp = false;
            obj.last_offset = NaN;
            obj.last_delay = NaN;
            obj.last_rt_delay = NaN;
        end

        function [obj, msgs] = step(obj, ts)
            msgs = {};
            remaining_msgs = {};
            obj.just_synced = false;  % Reset flag each step

            for i = 1:length(obj.msg_queue)
                msg = obj.msg_queue{i}.msg;
                msg_ts = obj.msg_queue{i}.ts;

                switch msg.type
                    case 'SYNC'
                        obj.t2 = msg_ts;
                        obj.waiting_followup = true;

                    case 'FOLLOW_UP'
                        obj.t1 = msg.t1;
                        obj.waiting_followup = false;

                        % Send DELAY_REQ
                        obj.t3 = ts;
                        delay_req = struct( ...
                            'type', 'DELAY_REQ' ...
                        );
                        msgs{end+1} = delay_req;
                        obj.waiting_delay_resp = true;

                    case 'DELAY_RESP'
                        if obj.waiting_delay_resp
                            obj.t4 = msg.t4;
                            obj.waiting_delay_resp = false;
                            obj.synced = true;
                            obj.just_synced = true;  % Mark fresh sync

                            % Compute offset and delay
                            obj.last_rt_delay = (obj.t2 - obj.t1) + (obj.t4 - obj.t3);
                            obj.last_delay = obj.last_rt_delay / 2;
                            obj.last_offset = ((obj.t2 - obj.t1) - (obj.t4 - obj.t3)) / 2;

                            if obj.verbose
                                fprintf("t1 = %.9e | t2 = %.9e | t3 = %.9e | t4 = %.9e\n", obj.t1, obj.t2, obj.t3, obj.t4);
                                fprintf("Offset = %.9e | Delay = %.9e\n", obj.last_offset, obj.last_delay);
                            end
                        end

                    otherwise
                        % Keep unrecognized messages
                        remaining_msgs{end+1} = obj.msg_queue{i};
                end
            end

            obj.msg_queue = remaining_msgs;
        end
    end
end


