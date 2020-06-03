% Get data from a single channel or a channel montage, usually channels
% read from a D file.
%
% Arguments:
%  x - KxN matrix of signals (recorded in individual channels); signals
%       come in K rows, samples in N columns
%  t - a vector of size N of times corresponding to individual samples
%       (defaults to 1:N). If tags get used, t must be the one read
%       from a .D file in order to make tags fit with the signal
%       (because tags are sample-based, not time-based)
%  channelNames - names of channels (signals) (can be empty)
%  channel - index or name of channel to get; channel montage
%       is supported, see examples
%  cnd - condition specifying which samples to plot, usually created
%       by putting a condition on the 't' vector. If omitted or empty, the
%       whole time range gets plotted.
%
% Returns:
%   - (row) data vector
%
% Typical usage:
%
%  % read a D file
%  [x,fs,channelNames,t,tags]=readDFile(fileName);
%
%  % get a single channel:
%  c=getChannel(x,t,channelNames,'UE1');
%
%  % get a montage of two channels:
%  c=getChannel(x,t,channelNames,'UE1+UE1d');
%
%  % get a more complex montage:
%  c=getChannel(x,t,channelNames,'UE2d+ME2-(UE1d+ME1)');
%
%
% Author: T.Sieger, 2017-10-24
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or (at
% your option) any later version.
%
function c=getChannel(x,t,channelNames,channel,cnd)
    if nargin<5
        cnd=repmat(true,1,length(t));
    end
    DBG=0;

    function showStr(s,i)
        fprintf(1,'%s\n',s);
        fprintf(1,'%s^\n',repmat(' ',1,i-1));
    end

    % Read channel name in the prefix of 's'.
    function nm=readChannelNamePrefix(s)
        ii=1;
        nn=length(s);
        while ii<=nn && (s(ii)~='(' && s(ii)~=')' && s(ii)~='+' && s(ii)~='-' && s(ii)~='/')
            ii=ii+1;
        end
        nm=s(1:(ii-1));
    end

    % Returns:
    %   - (row) data vector
    %   - (internal) length of the 'channel' string expression
    function [c,len]=getChannelImpl(x,t,channelNames,channel,cnd,nesting)
        i=1;
        n=length(channel);
        c=repmat(0,1,sum(cnd));
        op=1;
        opPlusMinusSeen=false;
        parenthesisSeen=0;
        while i<=n
            if DBG
                fprintf(1,'\n');
                showStr(channel,i);
            end
            if channel(i)=='('
                if DBG, fprintf(1,'  seen "(", diving in\n'); end
                parenthesisSeen=1;
                i=i+1;
                i2=i;
                parenthesesCount=1;
                closingParenthesisIdx=[];
                while i2<=n
                    if channel(i2)=='('
                        parenthesesCount=parenthesesCount+1;
                    elseif channel(i2)==')'
                        parenthesesCount=parenthesesCount-1;
                        if parenthesesCount==0
                            closingParenthesisIdx=i2;
                            break
                        end
                    end
                    i2=i2+1;
                end
                if isempty(closingParenthesisIdx)
                    error(['malformed expression "' channel '", missing ")"']);
                end
                [c2,len]=getChannelImpl(x,t,channelNames,channel(i:(closingParenthesisIdx-1)),cnd,nesting+1);
                c=c+op*c2;
                i=i+len+1;
                if DBG, fprintf(1,'  got back\n'); end
            elseif channel(i)==')'
                if ~parenthesisSeen
                    error(['malformed expression "' channel '", extra ")"']);
                end
                if nesting==0 && i<n
                    error(['malformed expression "' channel '", extra ")"']);
                end
                len=i;
                if DBG, fprintf(1,'  getting back\n'); end
                return
            elseif channel(i)=='+'
                if DBG, fprintf(1,'  seen "+"\n'); end
                i=i+1;
                op=1;
                opPlusMinusSeen=true;
            elseif channel(i)=='-'
                if DBG, fprintf(1,'  seen "-"\n'); end
                i=i+1;
                op=-1;
                opPlusMinusSeen=true;
            elseif channel(i)=='/'
                if DBG, fprintf(1,'  seen "/"\n'); end
                i=i+1;
                [c2,~,~,len]=sscanf(channel(i:end),'%d');
                if isempty(c2)
                    error(['malformed expression "' channel '", invalid number after "/"']);
                end
                if DBG, fprintf(1,'  dividing by %d\n',c2); end
                i=i+len-1;
                if opPlusMinusSeen
                    error('Sorry, can''t parse combined "+-" with "/", please wrap the division in parentheses.');
                end
                c=c/c2;
            else
                nm=readChannelNamePrefix(channel(i:end));
                i=i+length(nm);
                if DBG, fprintf(1,'  seen "%s"\n',nm); end
                idx=channelName2Idx(nm,channelNames);
                if idx==0
                    error(['channel "' nm '" not found ']);
                end
                if DBG, fprintf(1,'  idx %d\n',idx); end
                c=c+op*x(idx,cnd);
            end
        end
        len=n;
    end

    c=getChannelImpl(x,t,channelNames,channel,cnd,0);
end
