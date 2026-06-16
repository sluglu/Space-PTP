function nodes = protocol_ptp(ox1, ox2, params)
% PROTOCOL_PTP  Two-node IEEE 1588 PTP (master + slave).
%
%   nodes = protocol_ptp(ox1, ox2)          — use default params
%   nodes = protocol_ptp(ox1, ox2, params)  — override any field
%
%   params fields (all optional):
%     sync_interval       [s]    — SYNC message period              (default 1)
%     initial_time_offset [s]    — slave clock offset at t=0        (default 0)
%     verbose             bool   — print FSM state transitions       (default false)
%     servo.enabled       bool   — enable PI frequency servo         (default true)
%     servo.kp            [s^-1] — proportional gain                 (default 0.1)
%     servo.ki            [s^-2] — integral gain                     (default 0.01)

    if nargin < 3; params = struct(); end

    sync_interval = getfield_default(params, 'sync_interval',       1);
    servo_default = struct('enabled', true, 'kp', 0.1, 'ki', 0.01, ...
                           'sync_interval', sync_interval);
    servo_in      = getfield_default(params, 'servo', struct());

    % Merge user overrides into defaults
    servo = servo_default;
    for fn = fieldnames(servo_in)'
        servo.(fn{1}) = servo_in.(fn{1});
    end
    servo.sync_interval = sync_interval;  % always keep consistent

    p = struct( ...
        'sync_interval',       sync_interval, ...
        'initial_time_offset', getfield_default(params, 'initial_time_offset', 0), ...
        'verbose',             getfield_default(params, 'verbose',             false));

    nodes = { ...
        struct('id', 'master', 'ox', ox1, 'time_offset', 0, ...
               'fsm', PTPMasterFSM('slave',  p.sync_interval, p.verbose)), ...
        struct('id', 'slave',  'ox', ox2, 'time_offset', p.initial_time_offset, ...
               'fsm', PTPSlaveFSM('master', servo, p.verbose)) ...
    };
end
