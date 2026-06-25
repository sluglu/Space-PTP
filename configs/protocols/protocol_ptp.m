function nodes = protocol_ptp(clk1, clk2, options)
% PROTOCOL_PTP  Two-node IEEE 1588 PTP (master + slave).
% Returns a 1x2 cell array of node structs {master, slave}.
%
%   protocol_ptp(ox_perfect(), ox_ocxo())
%   protocol_ptp(clk1, clk2, Name, Value, ...)
%
% Optional name-value overrides:
%   sync_interval         SYNC period [s]                  (1)
%   initial_time_offset   Slave clock offset at t=0 [s]    (0)
%   verbose               Print FSM state transitions      (false)
%   servo_enabled         PI servo on/off                  (true)
%   servo_kp              Proportional gain                (0.1)
%   servo_ki              Integral gain                    (0.01)
    arguments
        clk1 (1,1) Clock
        clk2 (1,1) Clock
        options.sync_interval       (1,1) double  = 1
        options.initial_time_offset (1,1) double  = 0
        options.verbose             (1,1) logical = false
        options.servo_enabled       (1,1) logical = true
        options.servo_kp            (1,1) double  = 0.1
        options.servo_ki            (1,1) double  = 0.01
    end

    nodes = { ...
        struct('id', 'master', 'clock', clk1, 'time_offset', 0, ...
               'fsm', PTPMasterFSM('slave', 'sync_interval', options.sync_interval, 'verbose', options.verbose)), ...
        struct('id', 'slave',  'clock', clk2, 'time_offset', options.initial_time_offset, ...
               'fsm', PTPSlaveFSM('master', 'sync_interval', options.sync_interval, 'verbose', options.verbose, ...
                                  'servo_enabled', options.servo_enabled, 'servo_kp', options.servo_kp, 'servo_ki', options.servo_ki)) ...
    };
end
