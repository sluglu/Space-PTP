classdef (Abstract) NodeFSM
% NODEFSM  Common interface for all node state machines.
%
% Subclass this to implement any synchronization protocol.
% Place implementations under fsm/<ProtocolName>/.
%
% The run_experiment loop calls step(), receive(), and reset() on every node,
% reads last_offset / last_delay, and copies servo_y to the node's Clock after
% each step().  Outgoing messages must include a 'to' field with the recipient id.
%
% Servo convention:
%   Set servo_y (inherited, default 0) to the desired frequency correction [Hz]
%   whenever your protocol computes a new estimate.  The loop applies it to
%   Clock.servo_y, which is added to delta_f0 in Clock.advance().
%   Protocols without a servo simply leave servo_y at 0.

    properties (Abstract)
        last_offset   % most recent offset estimate [s]  (NaN if unavailable)
        last_delay    % most recent one-way delay estimate [s] (NaN if unavailable)
    end

    properties
        % Fractional frequency correction computed by servo [dimensionless, y = df/f0].
        % run_experiment copies this to Clock.servo_y after every step().
        servo_y = 0
    end

    methods (Abstract)
        % step    Advance FSM by one tick at local clock time ts.
        %         msgs is a cell array of structs, each with a 'to' field.
        [obj, msgs] = step(obj, ts)

        % receive  Deliver an incoming message that arrived at local time ts.
        obj = receive(obj, msg, ts)

        % reset   Called when LOS is lost; clear in-flight state.
        obj = reset(obj)
    end
end
