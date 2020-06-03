% Determine the index of a channel in channels (usually channels read from a D file).
%
% Arguments:
%  channel - index or name of channel to get
%  channelNames - names of channels (signals)
%
% Returns:
%   - index (or 0 if not found)
%
% Author: T.Sieger, 2020-06-01
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or (at
% your option) any later version.
%
function idx=channelName2Idx(channel,channelNames)
    idx=0;
    for ii=1:length(channelNames)
        if strcmp(channelNames{ii},channel)
            idx=ii;
        end
    end
end
