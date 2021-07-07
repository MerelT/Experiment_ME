%% 1. Define parameters
clear all
root_dir = 'C:\Users\mtabo\Documents\Data_Internship';

%Indicate the subjects
subjects = {'sub-06', 'sub-95', 'sub-53', 'sub-43', 'sub-19', 'sub-31', 'sub-38', 'sub-63', 'sub-90', 'sub-21', 'sub-44', 'sub-74', 'sub-84', 'sub-77', 'sub-69', 'sub-67', 'sub-27', 'sub-88'};
%subjects = {'sub-06', 'sub-19'}

%Indicate and open layout
load(fullfile(root_dir, 'layout.mat')); % load layout
cfg = [];
cfg.layout= layout;
ft_layoutplot(cfg); 

%% 2. Store baseline and timelockanalysis data of all subjects into one cell array
clear data_all 
for s = 1:length(subjects)
    for task=1:4
        load(fullfile(root_dir, 'processedshort', subjects{s}, 'data_TL_blc'));
        data_all{task}{s}=data_TL_blc{task};
    end 
end

 for task=1:4
     data_all_new{task}=data_all{task}';
 end
 
%% 3. Average over all subjects -> for each condition seperately!
% task 1: finger auto, 2: finger nonauto, 3: foot auto, 4: foot nonauto
for task=1:4
cfg=[];
grandavg{task}= ft_timelockgrandaverage(cfg, data_all{task}{:});
end
save('grandavg.mat', 'grandavg');

%% 4. Plot the data

% d) Separate O2Hb and HHb channels
for task=1:4
    cfg=[];
    cfg.channel='* [O2Hb]';
    data_TL_O2Hb{task}=ft_selectdata(cfg, grandavg{task});
    % and rename labels such that they have the same name as HHb channels
    for i=1:length(data_TL_O2Hb{task}.label)
        tmp = strsplit(data_TL_O2Hb{task}.label{i});
        data_TL_O2Hb{task}.label{i}=tmp{1};
    end
    save('data_TL_O2Hb.mat','data_TL_O2Hb');
    
    % The same for HHb channels
    cfg=[];
    cfg.channel='* [HHb]';
    data_TL_HHb{task}=ft_preprocessing(cfg, grandavg{task});
    for i=1:length(data_TL_HHb{task}.label)
        tmp = strsplit(data_TL_HHb{task}.label{i});
        data_TL_HHb{task}.label{i}=tmp{1};
    end
    save('data_TL_HHb.mat','data_TL_HHb');
end

% f) Plot both on the lay-out
cfg                   = [];
cfg.showlabels        = 'yes';
cfg.layout            = layout;
cfg.interactive       = 'yes'; % this allows to select a subplot and interact with it
%cfg.linecolor        = 'rbrbmcmc'; % O2Hb is showed in red (finger) and magenta (foot), HHb in blue (finger) and cyan (foot)
cfg.linecolor        = 'rbmc';
%cfg.linestyle = {'--', '--', '-', '-', ':', ':', '-.', '-.'}; % fingerauto is dashed line, fingernonauto is solid line, footauto is dotted line and footnonauto is a dotted stars line
%cfg.comment = 'fingerauto is dashed line, fingernonauto is solid line, footauto is dotted line and footnonauto is a dashed dot line';
cfg.linestyle = {'-', '-', '--', '--'};
cfg.ylim = [-0.135 0.165];
figure;
%ft_multiplotER(cfg, data_TL_O2Hb{1}, data_TL_HHb{1}, data_TL_O2Hb{2}, data_TL_HHb{2}, data_TL_O2Hb{3}, data_TL_HHb{3}, data_TL_O2Hb{4}, data_TL_HHb{4});
ft_multiplotER(cfg, data_TL_O2Hb{1}, data_TL_HHb{1}, data_TL_O2Hb{3}, data_TL_HHb{3});

% g) Plot for each task seperately
taskname={'Finger Auto', 'Finger Nonauto', 'Foot Auto', 'Foot Nonauto'};
%taskshort={'complex', 'stroop'};
for task=1:4
    cfg                   = [];
    cfg.showlabels        = 'yes';
    cfg.layout            = layout;
    cfg.showoutline       = 'yes';
    cfg.interactive       = 'yes'; % this allows to select a subplot and interact with it
    cfg.linecolor         = 'rb';% O2Hb is showed in red, HHb in blue
    cfg.ylim = [-0.135 0.165];
%     cfg.colorgroups=contains(data_TL_blc{task}.label, '[O2Hb]')+2*contains(data_TL_blc{task}.label, '[HHb]');
    figure; 
    title(taskname{task}); 
    ft_multiplotER(cfg, data_TL_O2Hb{task}, data_TL_HHb{task})
%     saveas(gcf, [char(taskshort(task)) '_timelock.jpg']);
end


%%
% Plot for each task seperately
taskname={'Finger Auto', 'Finger Nonauto', 'Foot Auto', 'Foot Nonauto'};
%taskshort={'complex', 'stroop'};
for task=1:4
    cfg                   = [];
    cfg.showlabels        = 'yes';
    cfg.layout            = layout;
    cfg.showoutline       = 'yes';
    cfg.interactive       = 'yes'; % this allows to select a subplot and interact with it
    cfg.linecolor         = 'rb';% O2Hb is showed in red, HHb in blue
   % cfg.ylim = [-0.440 0.540];
%     cfg.colorgroups=contains(data_TL_blc{task}.label, '[O2Hb]')+2*contains(data_TL_blc{task}.label, '[HHb]');
    figure; 
    title(taskname{task}); 
    ft_multiplotER(cfg, data_lPPC_O2Hb{task}, data_lPPC_HHb{task})
%     saveas(gcf, [char(taskshort(task)) '_timelock.jpg']);
end


%% 5. Statistical testing
con_names={'finger auto',  'finger nonauto', 'foot auto', 'foot nonauto'};
for i=1:4 % loop over the 4 conditions
  [stat_O2Hb, stat_HHb] = statistics_withinsubjects(grandavg{i}, 'grandavg', layout, i, con_names{i});
end
%% 6. Statistical analysis (paired t-test) 

% T-TEST (determine p-value for single channels)
% define the parameters for the statistical comparison
cfg = [];
cfg.channel     = {'Rx2-Tx3 [O2Hb]', 'Rx2-Tx4 [O2Hb]', 'Rx4-Tx4 [O2Hb]', 'Rx4-Tx3 [O2Hb]'};
cfg.avgoverchan = 'yes';
cfg.latency     = [5 10];
cfg.avgovertime = 'yes';
cfg.parameter   = 'avg';
cfg.method      = 'analytic';
cfg.statistic   = 'ft_statfun_depsamplesT';
cfg.alpha       = 0.05;
cfg.correctm    = 'no';

Nsub = 18;
cfg.design(1,1:2*Nsub)  = [ones(1,Nsub) 2*ones(1,Nsub)];
cfg.design(2,1:2*Nsub)  = [1:Nsub 1:Nsub];
cfg.ivar                = 1; % the 1st row in cfg.design contains the independent variable
cfg.uvar                = 2; % the 2nd row in cfg.design contains the subject number

% make sure to indicate the right tasks for which you want to determine if
% the difference is significantly different
stat = ft_timelockstatistics(cfg, data_all_new{1}{:}, data_all_new{2}{:})   % don't forget the {:}!
stat_2 = ft_timelockstatistics(cfg, data_all_new{3}{:}, data_all_new{4}{:})









