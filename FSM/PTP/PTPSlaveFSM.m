classdef PTPSlaveFSM < NodeFSM
    properties
        last_offset   = NaN
        last_delay    = NaN
        last_rt_delay = NaN

        t1; t2; t3; t4
        master_id

        waiting_followup   = false
        waiting_delay_resp = false
        synced             = false

        msg_queue = {}
        verbose   = false

        % PI servo --------------------------------------------------------
        servo_enabled  = true
        servo_kp       = 0.1    % proportional gain [s^{-1}]: Hz correction per Hz of f0 per second of offset
        servo_ki       = 0.01   % integral gain [s^{-2}]
        servo_integral = 0      % accumulated offset integral [s]
        sync_interval  = 1      % used to accumulate integral between measurements [s]
    end

    methods
        function obj = PTPSlaveFSM(master_id, servo, verbose)
            if nargin > 0; obj.master_id = master_id; end
            if nargin > 1 && ~isempty(servo)
                obj.servo_enabled = getfield_default(servo, 'enabled', true);
                obj.servo_kp      = getfield_default(servo, 'kp',      0.1);
                obj.servo_ki      = getfield_default(servo, 'ki',      0.01);
                obj.sync_interval = getfield_default(servo, 'sync_interval', 1);
            end
            if nargin > 2; obj.verbose = verbose; end
        end

        function obj = receive(obj, msg, ts)
            obj.msg_queue{end+1} = struct('msg', msg, 'ts', ts);
            if obj.verbose
                fprintf('[PTPSlaveFSM] Received %s at ts=%.9e\n', msg.type, ts);
            end
        end

        function [obj, msgs] = step(obj, ts)
            msgs      = {};
            remaining = {};

            for k = 1:length(obj.msg_queue)
                msg    = obj.msg_queue{k}.msg;
                msg_ts = obj.msg_queue{k}.ts;

                switch msg.type
                    case 'SYNC'
                        % Don't restart a cycle if a DELAY_RESP is still in flight
                        if ~obj.waiting_delay_resp
                            obj.t2 = msg_ts;
                            obj.waiting_followup = true;
                        end

                    case 'FOLLOW_UP'
                        if obj.waiting_followup
                            obj.t1 = msg.t1;
                            obj.waiting_followup = false;
                            obj.t3 = ts;
                            msgs{end+1} = struct('type', 'DELAY_REQ', 'to', obj.master_id);
                            obj.waiting_delay_resp = true;
                        end

                    case 'DELAY_RESP'
                        if obj.waiting_delay_resp
                            obj.t4 = msg.t4;
                            obj.waiting_delay_resp = false;
                            obj.synced = true;

                            obj.last_rt_delay = (obj.t2 - obj.t1) + (obj.t4 - obj.t3);
                            obj.last_delay    = obj.last_rt_delay / 2;
                            obj.last_offset   = ((obj.t2 - obj.t1) - (obj.t4 - obj.t3)) / 2;

                            obj = obj.update_servo();

                            if obj.verbose
                                fprintf('[PTPSlaveFSM] t1=%.9e t2=%.9e t3=%.9e t4=%.9e\n', obj.t1, obj.t2, obj.t3, obj.t4);
                                fprintf('[PTPSlaveFSM] offset=%.9e  delay=%.9e  servo_y=%.6e\n', ...
                                    obj.last_offset, obj.last_delay, obj.servo_y);
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
            obj.synced             = false;
            obj.waiting_followup   = false;
            obj.waiting_delay_resp = false;
            obj.msg_queue          = {};
            obj.servo_integral     = 0;
            % servo_y intentionally kept so the clock keeps running at
            % last correction during the outage; reset to 0 if unwanted.
        end
    end

    % ------------------------------------------------------------------
    methods (Access = private)
        function obj = update_servo(obj)
            if ~obj.servo_enabled; return; end

            % PI update: integral trapezoidal accumulation over sync_interval
            obj.servo_integral = obj.servo_integral + obj.last_offset * obj.sync_interval;

            % Correction in Hz applied to the slave clock
            % Positive offset means slave is ahead → reduce frequency
            obj.servo_y = -(obj.servo_kp * obj.last_offset + ...
                              obj.servo_ki * obj.servo_integral);
        end
    end
end
