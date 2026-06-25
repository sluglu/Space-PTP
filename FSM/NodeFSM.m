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
%   Set servo_y (fractional, dimensionless) whenever the protocol has a new
%   frequency estimate.  The loop writes it to clock.servo_y each tick, which
%   applies it as servo_y × f0 Hz.  Leave at 0 if no servo.

    properties (Abstract)
        last_offset   % most recent offset estimate [s]  (NaN if unavailable)
        last_delay    % most recent one-way delay estimate [s] (NaN if unavailable)
    end

    properties
        % Fractional frequency correction computed by servo [dimensionless, y = df/f0].
        % run_experiment copies this to Clock.servo_y after every step().
        % The FSM is responsible for keeping this at 0 until a valid estimate
        % is available; the simulation loop applies it unconditionally.
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
