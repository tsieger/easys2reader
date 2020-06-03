fn='some_file.d'; % <<-- supply a path to a .d data file here

% read the .d file
[x,fs,channelNames,t,tags,opts]=readDFile(fn);

% size of data (channels by samples):
size(x)

% sampling frequency:
fs

% show channel names:
channelNames

% show tags
tags

% present the tags table in an user-friendly form:
tags.tabInfoFun()

% summarise tags occurence:
tags.occurInfoFun()

% plot the first three channels and a montage (the difference) of the 4th and 3rd channel,
% plot in a 2-column layout,
% annotate the signals with selected tags, and
% restrict to a specific time interval:
chns=[channelNames(1:3) [channelNames{4} '-' channelNames{3}]];
tgs=tags.tabAbr(50:60);
plotChannels(x,t,channelNames,tags,2,chns,t>46&t<70,tgs);

