function nodes = protocol_base(clk1, clk2, params)
% PROTOCOL_BASE  Template for a new protocol config.
%
% Takes two Clock objects (from ox_*) and returns a nodes cell array:
%
%   nodes = protocol_ptp(ox_perfect(), ox_ocxo());
%
% Each node struct must have:
%   id          – string, unique per node
%   clock       – Clock object from ox_*
%   time_offset – initial clock offset at t=0 [s]  (usually 0)
%   fsm         – NodeFSM subclass instance
%
% Pattern:
%
%   function nodes = protocol_myproto(clk1, clk2, params)
%       if nargin < 3; params = struct(); end
%       nodes = {
%           struct('id','A','clock',clk1,'time_offset',0,'fsm',MyFSM('B',params)),
%           struct('id','B','clock',clk2,'time_offset',0,'fsm',MyFSM('A',params))
%       };
%   end

error('protocol_base is a template — copy and rename it for your protocol.');
end
