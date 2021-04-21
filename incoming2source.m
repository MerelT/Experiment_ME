% SCRIPT TO EXPORT DATA FROM INCOMING FILES TO SOURCE FILES
%
%Phase 1 (organize the recorded files)
% - Collect all files from all devices
% - Convert files in proprietary formats to open formats (oxy4->oxy3, mvn->mvnx)
% - Scan the paper lab notes and questionnaires into a pdf file
% - Rename all files following BIDS
% - Place all files in directory organization following BIDS:
% incoming2source.m
%
% ==> the source_standard data gets archived on the harddisk (Exp_ME), the
%     shared mbneufy3 folder and the donders repository
% the source_private get archived only on the harddisk (Exp_ME)
%
%?? Also for our experiment??
% Phase 2a (add the metadata files): source2raw.m
% - Extract the timing of the events from each individual recording file as trigger-events.tsv according to BIDS
% - Determine the relative timing of all recordings  to each other and store as scans.tsv according to BIDS
% - Determine the timing of the experimental runs/blocks/trials in each of the recordings
%
% Phase 2b (minimal pre-processing)
% - Annotate the video data (automaticity), add it to events.tsv
% - Determine optode positions from 3D structure sensor scans
% - Remove all files with identifying information (video, 3D scans)
%
% ==> this gets archived as the â€œraw BIDS dataâ€? and shared with collaborators
%
% Phase 3 (analyze)
% - Share the anonymous data with project collaborators
% - Analyze the data
% - Publish your results and the anonymous data
%



%% Set parameters
% adjust these for every subject!
clear all
root_dir = 'F:\Experiment_ME\Data';
sub='sub-06'; %indicate the subject ID
cd(root_dir)

rec_video=true;
rec_nirs=[1]; %how many recordings where made? check for the correct one
nirs_offline=true;
rec_motion=[1 1 1 1]; %all xsens data recorded? (footauto, footautodual, footnonauto, footnonautodual)
take_motion=[1:4]; %of all recordings
task_motion=  {'footautodual', 'footauto', 'footnonauto', 'footnonautodual'}; %the order depends on the randomization 
rec_stim=[1]; %how many recording where made? check for the correct one

%% create source directory structure
% source_standard
mkdir(fullfile(root_dir, 'source_standard'), sub)
subdir={'nirs', 'motion', 'stim', 'labnotes'};
for i=1:length(subdir)
    mkdir(fullfile(root_dir, 'source_standard', sub), subdir{i})
end

% source_private
mkdir(fullfile(root_dir, 'source_private'), sub)
subdir={'video', 'structuresensor'};
for i=1:length(subdir)
    mkdir(fullfile(root_dir, 'source_private', sub), subdir{i})
end

%% video folder
if rec_video
video_incom=fullfile(root_dir, 'incoming', sub, 'video');
video_outgo= fullfile(root_dir, 'source_private', sub, 'video');
files=dir(fullfile(video_incom,'*.MP4'));
    for j=1:length(files)
        filename_n=sprintf('%s_task-automaticity_rec-%.2d_video.mp4', sub, j);
        [success, message]=movefile(fullfile(files(j).folder, files(j).name),fullfile(video_outgo, filename_n));
        if success
            fprintf('File successfully moved to source directory: %s \n', filename_n);
        end
    end

% all files moved to source directory?
files=dir(video_incom);
if length(files)>2 %contains directory ., .., acq-mobile, acq-end, acq-begin
    warning('Remaining files in incoming directory')
else
    fprintf('No remaining files in incoming directory \n\n');
end
end

%% nirs folder
if rec_nirs
nirs_incom=fullfile(root_dir, 'incoming', sub, 'nirs');
nirs_outgo=fullfile(root_dir, 'source_standard', sub, 'nirs');
% ext={'oxy3', 'oxy4'};
ext={'oxy4'};

% move rec-prep nirs file to source directory
filename_o=sprintf('%s_rec-prep_nirs.oxy4', sub);
filename_n=sprintf('%s_rec-prep_nirs.oxy4', sub);
file=dir(fullfile(nirs_incom, filename_o));
if length(file)==1
  [success, message]=movefile(fullfile(file.folder, file.name), fullfile(nirs_outgo, filename_n));
  if success
    fprintf('File successfully moved to source directory: %s \n', filename_n);
  end
else
  warning(sprintf('No file named %s in incoming directory', filename_o));
end

% move nirs files to source directory
for i=1:length(rec_nirs)
    for e=1:length(ext)
        filename_o=sprintf('%s_rec-%.2d_nirs.%s', sub, rec_nirs(i), ext{e});
        filename_n=sprintf('%s_task-automaticity_acq-online_rec-%.2d_nirs.%s', sub, rec_nirs(i), ext{e});
        file=dir(fullfile(nirs_incom, filename_o));
        if length(file)==1
            [success, message]=movefile(fullfile(file.folder, file.name), fullfile(nirs_outgo, filename_n));
            if success
                fprintf('File successfully moved to source directory: %s \n', filename_n);
            end
        else
            warning(sprintf('No file named %s in incoming directory', filename_o));
        end
    end
end

% move nirs offline files to source directory
if nirs_offline
  acq={'acq-24065', 'acq-24068'};
  for a=1:2
      files=dir(fullfile(nirs_incom, acq{a}, '*.oxy3'));
    if length(rec_nirs)~=length(files)
      error('Not the same number of offline files as expected')
    end
    for i=1:length(rec_nirs)
      %         filename_o=sprintf('%s_%s_rec-%.2d_nirs.oxy3', sub, acq{a}, rec_nirs(i));
      filename_n=sprintf('%s_task-automaticity_%s_rec-%.2d_nirs.oxy3', sub, acq{a}, rec_nirs(i));
      [success, message]=movefile(fullfile(files(i).folder, files(i).name), fullfile(nirs_outgo, filename_n));
      if success
        fprintf('File successfully moved to source directory: %s \n', filename_n);
      end
    end
  end
end

% move DAQ screenshots to source folder
[success, message]=movefile(fullfile(nirs_incom, 'DAQ'), fullfile(nirs_outgo, 'DAQ'));
files=dir(fullfile(nirs_outgo, 'DAQ'));
if success
    fprintf('File successfully moved to source directory: %s consisting of %d screenshots \n', 'DAQ', length(files)-2);
    if length(files)-2~=6
      warning('not all 6 screenshots were captured')
    end
end


% all files moved to source directory?
files=dir(fullfile(nirs_incom, '**/*.*'));
if length(files)>8 %contains directory . and .. (x3); and acq-24065, acq-24068
    warning(sprintf('Remaining files in incoming directory'))
else
    fprintf('No remaining files in incoming directory \n\n');
end
end

%% motion folder
if rec_motion
ext={'mvn', 'mvnx'};

% move bodydimensions to source directory
motion_incom=fullfile(root_dir, 'incoming', sub, 'motion');
motion_outgo= fullfile(root_dir, 'source_standard', sub, 'motion');
files=dir(fullfile(motion_incom, '*bodydimensions.mvna'));
if length(files)==1
    [success, message]=movefile(fullfile(files(1).folder, files(1).name),fullfile(motion_outgo, files(1).name));
    if success
        fprintf('File successfully moved to source directory: %s \n', files(1).name);
    end
else
    warning('No file named *.bodydimensions.mvna or multiple files named like that');
end

% move motion files to source directory
for i=1:length(rec_motion)
    for e=1:length(ext)
        filename_o=sprintf('%s_rec-%.2d_take-%.3d.%s',sub, rec_motion(i), take_motion(i), ext{e});
        filename_n=sprintf('%s_task-%s_motion.%s', sub, task_motion{i}, ext{e});
        file=dir(fullfile(motion_incom, filename_o));
        if length(file)==1
            [success, message]=movefile(fullfile(file.folder, file.name),fullfile(motion_outgo,filename_n));
            if success
                fprintf('File successfully moved to source directory: %s \n', filename_n);
            end
        else
            warning('No file named %s in incoming directory',  filename_o);
        end
    end
end

% all files moved to source directory?
files=dir(motion_incom);
if length(files)>2 %contains directory . and ..
    warning('Remaining files in incoming directory')
else
    fprintf('No remaining files in incoming directory \n\n');
end
end

%% stim
if rec_stim
stim_incom=fullfile(root_dir, 'incoming', sub, 'stim');
stim_outgo= fullfile(root_dir, 'source_standard', sub, 'stim');
ext={'triggers.log', 'triggerslabrecorder.xdf'};

% move AutomaticityTest script
m_scripttest=dir(fullfile(stim_incom, sprintf('%s_AutomaticityTest_ME_v4.m', sub)));
if length(m_scripttest)==1
    [success, message]=movefile(fullfile(m_scripttest(1).folder, m_scripttest(1).name),fullfile(stim_outgo, m_scripttest(1).name));
    if success
        fprintf('File successfully moved to source directory: %s \n', m_scripttest(1).name);
    end
else
    warning('No file named *%s_AutomaticityTest_ME_v4.m* in incoming directory or multiple files named like that');
end

% move Experiment script
m_scriptexp=dir(fullfile(stim_incom, sprintf('%s_ExperimentScript_ME_v5.m', sub)));
if length(m_scriptexp)==1
    [success, message]=movefile(fullfile(m_scriptexp(1).folder, m_scriptexp(1).name),fullfile(stim_outgo, m_scriptexp(1).name));
    if success
        fprintf('File successfully moved to source directory: %s \n', m_scriptexp(1).name);
    end
else
    warning('No file named *%s_ExperimentScript_ME_v5.m* in incoming directory or multiple files named like that');
end

% move events
events={'events_footauto.mat', 'events_footautodual.mat', 'events_footnonauto.mat', 'events_footnonautodual.mat', 'events_handauto.mat', 'events_handautodual.mat', 'events_handnonauto.mat', 'events_handnonautodual.mat'};
task={'footauto', 'footautodual', 'footnonauto', 'footnonautodual', 'handauto', 'handautodual', 'handnonauto', 'handnonautodual'};
for i=1:8
files=dir(fullfile(stim_incom, events{i}));
filename_o=(events{i});
filename_n=sprintf('%s_task-%s_events.mat', sub, task{i});
  if length(files)==1
    [success, message]=movefile(fullfile(files.folder, files.name), fullfile(stim_outgo, filename_n));
    if success
      fprintf('File successfully moved to source directory: %s \n', filename_n);
    end
  else
    warning('No file named %s in incoming directory', filename_o);
  end
end
end

% move stim files to source directory
for i=1:length(rec_stim)
    for e=1:length(ext)
        filename_o=sprintf('%s_rec-%.3d_%s', sub, rec_stim(i), ext{e});
        filename_n=sprintf('%s_task-automaticity_rec-%.2d_%s', sub, rec_stim(i), ext{e});
        file=dir(fullfile(stim_incom,filename_o));
        if length(file)==1
            [success, message]=movefile(fullfile(file.folder, file.name), fullfile(stim_outgo, filename_n));
            if success
                fprintf('File successfully moved to source directory: %s \n', filename_n);
            end
        else
            warning('No file named %s in incoming directory', filename_o);
        end
    end
end

% all files moved to source directory?
files=dir(stim_incom);
if length(files)>2 %contains directory . and ..
    warning('Remaining files in incoming directory')
else
    fprintf('No remaining files in incoming directory \n\n');
end

%% structure sensor
ss_incom=fullfile(root_dir, 'incoming', sub, 'structuresensor');
ss_outgo= fullfile(root_dir, 'source_private', sub, 'structuresensor');
ext={'jpg', 'mtl', 'obj'};

% move model files to source directory
for e=1:length(ext)
    file=dir(fullfile(ss_incom, 'Model', sprintf('Model.%s', ext{e})));
    filename_n= sprintf('%s_structuresensor.%s', sub, ext{e});
    if length(file)==1
        [success, message]=movefile(fullfile(file.folder, file.name), fullfile(ss_outgo,file.name));
        if success
            fprintf('File successfully moved to source directory: %s \n',file.name);
        end
    else
        warning('No file named %s in incoming directory \n',  sprintf('Model.%s', ext{e}));
    end
end

% all files moved to source directory?
files=dir(fullfile(ss_incom, 'Model'));
if length(files)>2 %contains directory . and ..
    warning('Remaining files in incoming directory')
else
    fprintf('No remaining files in incoming directory \n\n');
end

%% labnotes
labn_incom=fullfile(root_dir, 'incoming', sub, 'labnotes');
labn_outgo= fullfile(root_dir, 'source_standard', sub, 'labnotes');
% if contains(sub, 'PD')
% ext={'labnotes.pdf', 'inclusion.pdf', 'UPDRSIII.pdf', 'general.pdf', 'history.pfd', 'NFOGQ.pdf', 'MOCA.pdf','TMT.pdf', 'HADS.pdf', 'anxiety.pdf', 'feedback.pdf'};
% elseif contains(sub, 'HC')
%   ext={'labnotes.pdf','inclusion.pdf', 'general.pdf', 'MOCA.pdf','TMT.pdf', 'HADS.pdf', 'anxiety.pdf', 'feedback.pdf'};
% end
ext={'labnotes.pdf'};

for e=1:length(ext)
    file=dir(fullfile(labn_incom, sprintf('%s_%s', sub, ext{e})));
    filename_n=sprintf('%s_%s', sub, ext{e});
    if length(file)==1
        [success, message]=movefile(fullfile(file.folder, file.name), fullfile(labn_outgo, filename_n));
        if success
            fprintf('File successfully moved to source directory: %s \n', filename_n);
        end
    else
        warning('No file named %s in incoming directory',  sprintf('%s_%s', sub, ext{e}));
    end
end

% all files moved to source directory?
files=dir(fullfile(labn_incom));
if length(files)>2 %contains directory . and ..
    warning('Remaining files in incoming directory')
else
    fprintf('No remaining files in incoming directory \n\n');
end


%% save script
mkdir(fullfile(root_dir, 'scripts', sub))
script=mfilename('fullpath');
script_name=mfilename;
copyfile(sprintf('%s.m', script), fullfile(root_dir, 'scripts', sub, sprintf('%s_%s.m', sub, script_name)))