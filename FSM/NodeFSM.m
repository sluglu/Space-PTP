classdef (Abstract) NodeFSM
% NODEFSM  Common interface for all PTP-family state machines.
%
% Any FSM placed under ptp/<Protocol>/ must subclass NodeFSM and
% implement step() and receive().  The run_experiment loop only calls
% these two methods, so any compliant FSM can be dropped in.

    methods (Abstract)
        % step   Advance the FSM by one tick at local clock time ts.
        %        Returns outgoing messages as a cell array of structs.
        [obj, msgs] = step(obj, ts)

        % receive  Deliver an incoming message that arrived at local time ts.
        obj = receive(obj, msg, ts)
    end
end
