% Plot parallel signals, usually those read from a D file.
%
% Arguments:
%  x - KxN matrix of signals (recorded in individual channels); signals
%       come in K rows, samples in N columns
%  t - a vector of size N of times corresponding to individual samples
%       (defaults to 1:N). If tags get used, t must be the one read
%       from a .D file in order to make tags fit with the signal
%       (because tags are sample-based, not time-based)
%  channelNames - names of channels (signals) (can be empty)
%  tags - tags read from a .D file (can be empty)
%  columns - subplots get arranged in 'columns' columns (defaults to 1)
%  channels - indices or names of channels to plot, or 'all'
%       to plot all channels. If omitted, all channels get plotted.
%       Limited channel montages are supported: the channel can be an
%       expression involving channel names. The following constructs
%       are supported:
%           addition and subtraction:
%               e.g. C1+C2-C3+C4...
%           parentheses:
%               e.g. C1+C2-(C3+C4)...
%           division by a discrete number:
%               e.g. (C1+C2+C3)/3,
%               note: the whole expression involving division must be
%                   wrapped in parentheses when located after addition
%                   or subtraction, e.g.
%                       C1+(C1+C2+C3)/3
%                   is not supported and must be wrapped as
%                       C1+((C1+C2+C3)/3)
%           supersposition of several channels:
%               e.g. C1:C2
%               - C2 gets plotted on top of C1
%  cnd - condition specifying which samples to plot, usually created
%       by putting a condition on the 't' vector. If omitted or empty, the
%       whole time range gets plotted.
%  tagsToPlot - name (or a cell array of names) of tags (their
%       2-character abbreviations) to plot. If omitted, all tags get
%       plotted. If empty, no tags get ploted. If non-empty, t must be
%       the one read from a .D file in order to make tags fit with the
%       signal.
%  lp - if nonzero, running mean computed from window of length "lp"
%       gets plotted on top of the signals
%
%
% Typical usage:
%
%  % read a D file
%  [x,fs,channelNames,t,tags]=readDFile(fileName);
%
%  % plot all channels in three columns, omitting tags:
%  plotChannels(x,t,channelNames,[],3);
%
%  % plot a time range of selected channels:
%  plotChannels(x,t,channelNames,tags,1,{'C1','C2','C3'},t>10&t<12);
%
%  % plot a time range of selected channels and selected tags only:
%  plotChannels(x,t,channelNames,tags,1,{'C1','C2'},t>46&t<70,{'T0','T1'});
%
%   
% Author: T.Sieger, 2016-11-24
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or (at
% your option) any later version.
%
function plotChannels(x,t,channelNames,tags,columns,channels,cnd,tagsToPlot,lp)

    if nargin<2
        t=1:size(x,2);
    end
    if nargin<3
        channelNames=cell(1,size(x,1));
        for i=1:size(x,1)
            channelNames{i}=num2str(i);
        end
    end
    if nargin<4
        tags=[];
    end
    if nargin<5
        columns=1;
    end
    if nargin<6 || ischar(channels) && strcmp(channels,'all')
        % take all channels
        channels=channelNames;
    elseif ~isnumeric(channels)
        if ischar(channels)
            channels={channels};
        end
    end
    n=length(channels);
    if nargin<7 || isempty(cnd)
        cnd=repmat(true,1,length(t));
    end
    if nargin<8
        plotAllTags=true;
    else
        plotAllTags=false;
    end
    if nargin<9
        lp=0;
    end

    clf();
    yrel=[.975 .875 .95 .85 .925 .825 .9 .8 .875 .775 .85 .75]-.005;
    yrelIdx=1;
    for i=1:n
        subplot(ceil(n/columns),columns,i);
        for s=strsplit(channels{i},':')
            c=getChannel(x,t,channelNames,s{1},cnd);
            plot(t(cnd),c);
            hold on
        end
        tmp=t(cnd);
        plot(tmp([1 end]),[0 0],'r');
        % takes ages: why?
        %xlim([min(t(cnd)) max(t(cnd))]);
        if lp>1
            tmp=filtfilt(boxcar(lp)/lp,1,c);
            plot(t(cnd),tmp,'r');
            %plot(t(cnd),100*[0 abs(diff(tmp))],'k');
        end
        if ~isempty(tags)
            for tpi=1:length(tags.pos)
                tp=tags.pos(tpi);
                if cnd(tp)
                    if plotAllTags || ~isempty(tagsToPlot) && ismember(tags.tabAbr{tags.class(tpi)+1},tagsToPlot)
                        plot(repmat(t(tp),1,2),ylim(),'r--','LineWidth',2);
                        tmp=ylim();
                        y=tmp(1)+diff(tmp)*yrel(yrelIdx);
                        yrelIdx=yrelIdx+1;
                        if yrelIdx>length(yrel)
                            yrelIdx=1;
                        end
                        text(t(tp),y,tags.tabAbr(tags.class(tpi)+1),'Color','k','HorizontalAlignment','center','FontSize',15);
                    end
                end
            end
        end
        if ~isempty(channelNames)
            title(channels{i});
        end
    end
end
