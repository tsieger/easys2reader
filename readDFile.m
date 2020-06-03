% Very basic reading of a .D file (used e.g. by Easys2 SW).
%
% TODO: add sanity checks (for file type etc.)
%
% Arguments:
%  fn - file name
%  verbose - logical flag controlling verbosity (if true, 
%
% Returns: data (channels in rows, samples in columns),
% sampling frequency, channel names, corresponding time scale,
% tags, and a structure holding additional information read
% from the D file header.
%
% tags: structure of
%   defCount - number of tags defined
%   occurCount - number of tags recorded
%   pos - position of individual tags (in samples)
%   class - classes of individual tags (0-based)
%   flag - flags of individual tags
%   tabAbr - tag definition table: tag abbreviations
%   tabDef - tag definition table: tag descriptions
%   tabOccur - number of occurences of individual tags
% WARNING: classes are 0-based, while matlab uses 1-based indexing, so
%  one has to use "tags.tabAbr(class+1)" to get info for tag class 'class'.
%
% opts: structure of
%   fileName
%   dval
%   unit
%   zero
%   tm = time of record start, to convert it to datenum, one can use
%       'datenum(1970,1,1) + opts.recordStartTime/86400' and to get a readable form,
%       'datestr(datenum(1970,1,1) + opts.recordStartTime/86400)'
%
% See also: plotChannels for plotting the read data, possibly parallel channels
%
% Author: T.Sieger, 2016-09-21
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or (at
% your option) any later version.
%
function [x,fs,channelNames,t,tags,opts]=readDFile(fn,fixChannelNames,verbose)
    if nargin<2
        fixChannelNames=false;
    end
    if nargin<3
        verbose=false;
    end

    f=fopen(fn,'r');
    if f==-1
        error(['Can''t open file ' fn '.']);
    end

    % # of channels
    fseek(f,16,-1);
    nChannel=fread(f,1,'uint8');
    if verbose
        fprintf(1,'channel count: %d\n',nChannel);
    end

    % sampling freq
    fseek(f,18,-1);
    fs=fread(f,1,'uint16');
    if verbose
        fprintf(1,'sampling freq: %d\n',fs);
    end

    % # of samples per channel
    fseek(f,20,-1);
    nSample=fread(f,1,'uint32');
    if verbose
        fprintf(1,'# of samples per channel: %d\n',nSample);
    end
    t=(0:(nSample-1))/fs;

    % dval
    fseek(f,24,-1);
    dval=fread(f,1,'uint8');
    if verbose
        fprintf(1,'dval: 0x%02x\n',dval);
    end

    % unit
    fseek(f,25,-1);
    unit=fread(f,1,'uint8');
    if verbose
        fprintf(1,'unit: %d\n',unit);
    end

    % zero
    fseek(f,26,-1);
    zero=fread(f,1,'uint16');
    if verbose
        fprintf(1,'zero: %d\n',zero);
    end

    % start of data
    fseek(f,28,-1);
    dataStart=fread(f,1,'uint16')*16;
    if verbose
        fprintf(1,'data start: %d (0x%x)\n',dataStart,dataStart);
    end

    % start of extended header
    fseek(f,30,-1);
    xhdrStart=fread(f,1,'uint16')*16;
    if verbose
        fprintf(1,'xhdr start: %d (0x%x)\n',xhdrStart,xhdrStart);
    end

    % read channel names
    channelNames=cell(1,nChannel);
    fseek(f,xhdrStart,-1);
    while 1
        id=fread(f,2,'uchar')';
        if all(id==[0 0])
            break
        end
        id=char(id);
        len=fread(f,1,'uint16');
        if id=='CN' % channel names
            for i=1:nChannel
                cn=fread(f,4,'uchar')';
                channelNames{i}=char(cn(cn>0));
            end
        elseif id=='PJ' % project name
            projectName=fread(f,12,'uchar')';
            if verbose
                fprintf(1,'project name: "%s"\n',projectName);
            end
        %elseif id=='ID' % patient's ID
        elseif id=='DI' % data desc
            dataDesc=fread(f,len,'uchar')';
            if verbose
                fprintf(1,'data desc: "%s"\n',dataDesc);
            end
        elseif id=='TT' % tag table
            tagDefLen=fread(f,1,'uint16')';
            tagLen=fread(f,1,'uint16')';
            tagDefStart=fread(f,1,'uint32')';
            tagStart=fread(f,1,'uint32')';
            if verbose
                fprintf(1,' tag def start 0x%x\n',tagDefStart);
                fprintf(1,' tag table start 0x%x\n',tagStart);
            end
        elseif id=='TI' % time info
            tm=fread(f,1,'uint32')';
        else
            if verbose
                fprintf(1,' skipping xhdr record %s\n',id);
            end
            fseek(f,len,0);
        end
    end

    if fixChannelNames
        channelNames=fixDFileChannelNames(channelNames);
    end

    % read tag definitions
    if verbose
        fprintf(1,'\ntag table:\n');
    end
    fseek(f,tagDefStart,-1);
    tagDefAbr=[];
    tagDefDesc=[];
    tagDefInfo='cnt id code info\n';
    tagOccur=[];
    for i=1:(tagDefLen/8)
        fseek(f,tagDefStart+(i-1)*8,-1);
        abr=char(fread(f,2,'uchar')');
        cnt=fread(f,1,'uint16');
        if bitand(cnt,2^15)>0
            break
        end
        cnt=bitand(cnt,(2^15)-1);
        txtlen=fread(f,1,'uint16');
        txtoff=fread(f,1,'uint16');
        fseek(f,tagDefStart+txtoff,-1);
        txt=char(fread(f,txtlen,'char')');
        info=sprintf('%3d %3d %s %s',cnt,i-1,abr,txt);
        if isempty(tagDefAbr)
            tagDefAbr={abr};
            tagDefDesc={txt};
            % can't simply do "tagDefAbr=[tagDefAbr {abr}]"
            % as in matlab it results in "{abr}",
            % while in octave it results in "{ [] 1}"
        else
            tagDefAbr=[tagDefAbr {abr}];
            tagDefDesc=[tagDefDesc {txt}];
        end
        tagOccur=[tagOccur cnt];
        tagDefInfo=[tagDefInfo info '\n'];
        if verbose
            fprintf(1,'tag class %d (0x%02x) "%s": "%s", %d occurence(s)\n',i-1,i-1,abr,txt,cnt);
        end
    end

    % read tags
    tagOccurInfo='     time flag id id code\n';
    if verbose
        fprintf(1,'\ntags:\n');
    end
    tagsPos=repmat(NaN,1,tagLen/4);
    tagsClass=repmat(NaN,1,tagLen/4);
    tagsFlag=repmat(NaN,1,tagLen/4);
    fseek(f,tagStart,-1);
    for i=1:(tagLen/4)
        x=fread(f,1,'uint32');
        pos=bitand(x,(2^24)-1);
        cls=bitand(bitshift(x,-3*8),(2^8)-1);
        flg=bitand(cls,2^7)>0;
        cls=bitand(cls,(2^7)-1);
        tagsPos(i)=pos;
        tagsClass(i)=cls;
        tagsFlags(i)=flg;
        if verbose
            fprintf(1,'tag %d (0x%02x) at pos 0x%x, flag %d\n',cls,cls,pos,flg);
        end
        info=sprintf('%9.4f %4d %d %s %s %s',t(pos),flg,cls,tagDefAbr{cls+1},tagDefDesc{cls+1});
        tagOccurInfo=[tagOccurInfo info '\n'];
    end
    tags=struct(...
        'defCount',length(tagDefAbr),'occurCount',length(tagsPos),...
        'pos',{tagsPos},'class',{tagsClass},'flag',{tagsFlag},...
        'tabAbr',{tagDefAbr},'tabDef',{tagDefDesc},'tabOccur',{tagOccur},...
        'tabInfo',{tagDefInfo},'tabInfoFun',@()fprintf(1,tagDefInfo),...
        'occurInfoFun',@()fprintf(1,tagOccurInfo));
    opts=struct('fileName',fn,'dval',dval,'unit',unit,'zero',zero,'recordStartTime',tm);

    % read data
    fseek(f,dataStart,-1);
    x=fread(f,nSample*nChannel,'int32');
    x=reshape(x,nChannel,nSample);
    x=x-zero;
    if unit~=0
        x=x*(1/unit);
    end

    fclose(f);
end
