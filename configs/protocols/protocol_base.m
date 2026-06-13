function nodes = protocol_base(ox1, ox2, params)
% PROTOCOL_BASE  Template for writing a new protocol config.
%
% A protocol config builds the cfg.nodes cell array consumed by run_experiment.
% Each node must be a struct with these fields:
%
%   id           – string identifier used for message routing (unique per node)
%   ox           – oscillator struct (from ox_perfect, ox_ocxo, ox_csac, ...)
%   time_offset  – clock offset at t=0 relative to cfg.sim.t0 [s]
%   fsm          – a NodeFSM subclass instance
%
% FSM classes live under fsm/<ProtocolName>/. Subclass NodeFSM and implement
% step(), receive(), reset(), and expose last_offset / last_delay properties.
%
% Example — symmetric two-node protocol where both nodes use the same FSM:
%
%   if nargin < 3; params = struct(); end
%   nodes = {
%       struct('id', 'A', 'ox', ox1, 'time_offset', 0,
%              'fsm', MySymmetricFSM('B', params)),
%       struct('id', 'B', 'ox', ox2, 'time_offset', 0,
%              'fsm', MySymmetricFSM('A', params))
%   };

error('protocol_base is a template — copy and rename it for your protocol.');
end
