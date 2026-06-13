classdef ProgressTracker < handle
% PROGRESSTRACKER  Simple fprintf-based progress reporter.
% Works in serial loops, parfor workers (via DataQueue), and headless runs.
%
% Usage (serial):
%   p = ProgressTracker(N, 'My task');
%   p.start();
%   for i = 1:N
%       ... work ...
%       p.update();
%   end
%   p.finish();
%
% Usage (parfor) — call p.update() from the main thread via DataQueue:
%   p  = ProgressTracker(N, 'My task'); p.start();
%   dq = parallel.pool.DataQueue;
%   afterEach(dq, @(~) p.update());
%   parfor i = 1:N; ...; send(dq, i); end
%   p.finish();

    properties (Access = private)
        total
        count  = 0
        t_start
        label
        print_every   % print every this many updates
    end

    methods
        function obj = ProgressTracker(N, label)
            obj.total = N;
            if nargin > 1; obj.label = label; else; obj.label = 'Progress'; end
            obj.print_every = max(1, floor(N / 20));   % ~20 prints total
        end

        function start(obj)
            obj.t_start = tic;
            obj.count   = 0;
            fprintf('[%s] Starting (%d steps)...\n', obj.label, obj.total);
        end

        function update(obj)
            obj.count = obj.count + 1;
            pct = min(100, 100 * obj.count / obj.total);
            if mod(obj.count, obj.print_every) == 0 || obj.count == obj.total
                elapsed = toc(obj.t_start);
                remaining = elapsed / obj.count * max(0, obj.total - obj.count);
                fprintf('  [%s] %d/%d (%.0f%%) — %.1f s elapsed, ~%.0f s remaining\n', ...
                    obj.label, obj.count, obj.total, pct, elapsed, remaining);
            end
        end

        function finish(obj)
            fprintf('[%s] Done in %.2f s.\n', obj.label, toc(obj.t_start));
        end
    end
end
