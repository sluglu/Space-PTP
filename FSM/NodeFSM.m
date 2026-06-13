classdef (Abstract) NodeFSM
% NODEFSM  Common interface for all node state machines.
%
% Subclass this to implement any synchronization protocol.
% Place implementations under fsm/<ProtocolName>/.
%
% The run_experiment loop only calls step(), receive(), and reset(),
% and reads last_offset / last_delay from each node's FSM.
% Outgoing messages must include a 'to' field with the recipient node id.

    properties (Abstract)
        last_offset   % most recent offset estimate [s]  (NaN if unavailable)
        last_delay    % most recent one-way delay estimate [s] (NaN if unavailable)
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
