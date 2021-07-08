clear all;
%% Make 3D scan with the structure sensor
% * place the cap on the subject's head and make sure that Cz is midway
% between nasion-inion and LPA-RPA
% * mark the fiducials (nasion, LPA, RPA, inion, Cz) with stickers
% * make a 3D scan of the subject while walking around him/her with the
% structure sensor (ask for help if necessary).
% * email to own email adress
% * save the "Model" folder on a place you specify below in root_dir and
% unzip
%% Specify where you saved the model folder
% root_dir='C:\Users\helen\Documents\PhD\pilots\200306_Renée';
root_dir='C:\Users\mtabo\Documents\Data_Internship';
obj_file=fullfile(root_dir, 'Model', 'Model.obj');
%obj_file=fullfile(root_dir, 'structuresensor', 'sub-01_structuresensor.obj');
cd(root_dir) % or other folder where you want to save your data

% you also need to specify your path to fieldtrip for a later step
[ftver, ftpath] = ft_version;

%% Load the 3D-model
head_surface = ft_read_headshape(obj_file);

% Convert the units to mm
head_surface = ft_convert_units(head_surface, 'mm');

% Visualize the mesh surface
ft_plot_mesh(head_surface)

%% Specify the fiducials + optodes
% Note that I also call Cz a fiducial, which is in fact not a fiducial, but
% which we will use in a later stage to for coregistration.
cfg = [];
cfg.channel={};
cfg.channel{1} = 'Nz';
cfg.channel{2} = 'LPA';
cfg.channel{3} = 'RPA';
cfg.channel{4}= 'Iz';
cfg.channel{5} = 'Cz';
tnames = {'Tx1', 'Tx2', 'Tx3', 'Tx4', 'Tx5', 'Tx6', 'Tx7', 'Tx8', 'Tx9', 'Tx10', 'Tx11', 'Tx12', 'Tx13', 'Tx14', 'Tx15', 'Rx1', 'Rx2', 'Rx3', 'Rx4', 'Rx5', 'Rx6', 'Rx7', 'Rx8', 'Rx9', 'Rx10', 'Rx11', 'Rx12'};
%tnames = {'Tx1a', 'Tx1b', 'Tx1c', 'Tx1d', 'Tx6a', 'Tx6b', 'Tx6c', 'Tx6d', 'Tx11a', 'Tx11b', 'Tx11c', 'Tx11d'};
%channels = {'Rx1-Tx2', 'Rx1-Tx3', 'Rx2-Tx3', 'Rx2-Tx4', 'Rx3-Tx2', 'Rx3-Tx3', 'Rx3-Tx5', 'Rx4-Tx3', 'Rx4-Tx4', 'Rx4-Tx5', 'Rx5-Tx7', 'Rx5-Tx8', 'Rx7-Tx7', 'Rx7-Tx8', 'Rx6-Tx9', 'Rx8-Tx9', 'Rx8-Tx10', 'Rx9-Tx12', 'Rx9-Tx13', 'Rx11-Tx12', 'Rx11-Tx13', 'Rx10-Tx14', 'Rx12-Tx14', 'Rx12-Tx15'};
for i =6:21
    cfg.channel{i}=sprintf('%s', tnames{i-5}); % change this according to the number of transmitters your layout has
end
for i =22:34
    cfg.channel{i}=sprintf('Rx%d', i-21); % change this according to the number of receivers your layout has
end
cfg.method = 'headshape';
opto = ft_electrodeplacement(cfg, head_surface);
save(['opto.mat'], 'opto')
% Do you want to change the anatomical labels for the axes [Y, n]? --> n
% Use "Rotate 3D" to rotate the 3D model.
% Click/unclick "Colors" to toggle the colors on and off: best is to use the color
% view for the fiducials, but the structure view for the optodes
% Use the mouse to click on fiducials/optodes and subsequently on the corresponding
% label to assign the markers. (Make sure you're not in "Rotate 3D" mode anymore!)
% If an error was made: double click on the label to remove this marker
% If ready --> press Q

%% Allign the axes of the coordinate system with the fiducial positions (ctf coordinates)
% for the mesh
clf;
cfg = [];
cfg.method        = 'fiducial';
cfg.coordsys      = 'ctf';
cfg.fiducial.nas  = opto.elecpos(1,:); %position of Nz
cfg.fiducial.lpa  = opto.elecpos(2,:); %position of LPA
cfg.fiducial.rpa  = opto.elecpos(3,:); %position of RPA
head_surface_aligned = ft_meshrealign(cfg, head_surface);

ft_plot_axes(head_surface_aligned)
ft_plot_mesh(head_surface_aligned)

% for the optodes
fid.chanpos       = [110 0 0; 0 90 0; 0 -90 0];       % CTF coordinates of the fiducials
fid.elecpos       = [110 0 0; 0 90 0; 0 -90 0];       % just like electrode positions
fid.label         = {'Nz','LPA','RPA'};    % same labels as in elec
fid.unit          = 'mm';                  % same units as mri

cfg               = [];
cfg.method        = 'fiducial';
cfg.coordsys = 'ctf';
cfg.target     = fid;                   % see above
cfg.elec          = opto;
cfg.fiducial      = {'Nz', 'LPA', 'RPA'};  % labels of fiducials in fid and in elec
opto_aligned      = ft_electroderealign(cfg);

% Visualize the optodes on the alligned head surface
% Notice that the colorview is not that clean as the the structure view
figure;
ft_plot_mesh(head_surface_aligned)
ft_plot_sens(opto_aligned, 'elecsize', 10, 'style', 'b')

% to have the same visualization without the colors
figure;
ft_plot_mesh(removefields(head_surface_aligned, 'color'), 'tag', 'headshape', 'facecolor', 'skin', 'material', 'dull', 'edgecolor', 'none', 'facealpha', 1);
lighting gouraud
l = lightangle(0, 90);  set(l, 'Color', [1 1 1]/2)
l = lightangle(  0, 0); set(l, 'Color', [1 1 1]/3)
l = lightangle( 90, 0); set(l, 'Color', [1 1 1]/3)
l = lightangle(180, 0); set(l, 'Color', [1 1 1]/3)
l = lightangle(270, 0); set(l, 'Color', [1 1 1]/3)
alpha 0.9
ft_plot_sens(opto_aligned, 'elecsize', 10, 'style', 'b')

save(['opto_aligned.mat'], 'opto_aligned')

%% Move optode inward
cfg = [];
cfg.method     = 'moveinward';
cfg.moveinward = 5; % determine distance to skin
cfg.channel = 2:length(opto_aligned.label); % do not move the nasion inward
cfg.keepchannel = true;
cfg.elec       = opto_aligned;
opto_inw = ft_electroderealign(cfg);

% visualize
figure;
ft_plot_mesh(removefields(head_surface_aligned, 'color'), 'tag', 'headshape', 'facecolor', 'skin', 'material', 'dull', 'edgecolor', 'none', 'facealpha', 1);
lighting gouraud
l = lightangle(0, 90);  set(l, 'Color', [1 1 1]/2)
l = lightangle(  0, 0); set(l, 'Color', [1 1 1]/3)
l = lightangle( 90, 0); set(l, 'Color', [1 1 1]/3)
l = lightangle(180, 0); set(l, 'Color', [1 1 1]/3)
l = lightangle(270, 0); set(l, 'Color', [1 1 1]/3)
alpha 0.7
ft_plot_sens(opto_inw, 'elecsize', 10, 'style', 'b')

save(['opto_inw.mat'], 'opto_inw')

%% Coregister optodes to MNI atlas 
% or event better: to an anatomical scan of your subject if you have one.
% In that case, you will first need to segment the skin from your
% anatomical MRI scan. For more information see: http://www.fieldtriptoolbox.org/tutorial/headmodel_eeg_bem/

% load skin surface of standard atlas
skin_template=fullfile(ftpath, 'template', 'headmodel', 'skin', 'standard_skin_14038.vol');
skin=ft_read_headshape(skin_template);
% visualize
figure;ft_plot_mesh(skin, 'edgecolor', 'none', 'facecolor', 'skin'); camlight

% visualization with optodes
hold on; ft_plot_sens(opto_inw);
% you should notice that your optodes, which are represented in the ctf
% coordinate system, are rotated with 90 degrees compared to the head model
% which is represented in the MNI coordinate system. For more information
% see: http://www.fieldtriptoolbox.org/faq/how_are_the_different_head_and_mri_coordinate_systems_defined/

% We will use the MNI coordinates of the fiducials, which can be found in
% the standard_1020.elc file of the fieldtrip template folder,
% to guide the coregistration 
elec1020=ft_read_sens(fullfile(ftpath, 'template', 'electrode', 'standard_1020.elc'));
% select rpa, lpa, nasion, inion and cz from elec1020
cfg=[];
cfg.method='moveinward'; % this is just a hack to select the right channels
cfg.moveinward=0;
% cfg.channel={'Nz'; 'RPA'; 'LPA'; 'Iz'; 'Cz'};
cfg.channel={'Nz'; 'RPA'; 'LPA'; 'Cz'};
electarg=ft_electroderealign(cfg, elec1020);

% There are two ways to coregister the optodes to the MNI space: (1)
% interactively/manually or (2) automatically based on the fiducials we
% specified here above

% (1) interactively 
% So first a 90 degree turn to go from ctf to mni coordinate system
cfg=[];
cfg.method='interactive';
cfg.headshape=skin;
cfg.target=electarg; % you can use the fiducials to guide your coregistration
opto_MNI=ft_electroderealign(cfg, opto_inw);
% You might notice that this is quite time consuming and needs some
% practice. Therefore, I prefer to do it automatically, but this is only
% possible if you have enough fiducials/marker points.

% (2) automatically 
cfg=[];
cfg.method='template';
cfg.warp= 'globalrescale';
% cfg.channel={'LPA', 'RPA', 'Nz', 'Cz', 'Iz'};
cfg.channel={'LPA', 'RPA', 'Nz', 'Cz'};
cfg.target=electarg;
opto_MNI=ft_electroderealign(cfg, opto_inw);

save('opto_MNI.mat', 'opto_MNI')

% plot together
figure;ft_plot_mesh(skin, 'edgecolor', 'none', 'facecolor', 'skin'); camlight
hold on; ft_plot_sens(opto_MNI, 'elecsize', 20,'facecolor', 'k', 'label', 'label');
hold on; ft_plot_sens(electarg, 'elecsize', 20, 'facecolor', 'b');

%% Calculate channel locations based on optode positions (in this case in MNI space)
% use optode namings instead of eeg namings
% define here the channels you want to create:
channels = {'Rx1-Tx2', 'Rx1-Tx3', 'Rx2-Tx3', 'Rx2-Tx4', 'Rx3-Tx2', 'Rx3-Tx3', 'Rx3-Tx5', 'Rx4-Tx3', 'Rx4-Tx4', 'Rx4-Tx5', 'Rx5-Tx7', 'Rx5-Tx8', 'Rx7-Tx7', 'Rx7-Tx8', 'Rx6-Tx9', 'Rx8-Tx9', 'Rx8-Tx10', 'Rx9-Tx12', 'Rx9-Tx13', 'Rx11-Tx12', 'Rx11-Tx13', 'Rx10-Tx14', 'Rx12-Tx14', 'Rx12-Tx15'};
%channels = {'Rx1-Tx1b', 'Rx2-Tx1a', 'Rx3-Tx1d', 'Rx4-Tx1c', 'Rx5-Tx6b', 'Rx6-Tx6a', 'Rx7-Tx6d', 'Rx8-Tx6c', 'Rx9-Tx11a', 'Rx10-Tx11b', 'Rx11-Tx11c', 'Rx12-Tx11d'};
[rxnames, rem] = strtok(channels, {'-', ' '});
[txnames, rem] = strtok(rem,   {'-', ' '});

% change the naming
opto_def=opto_MNI;
opto_def.optopos=opto_MNI.chanpos;
opto_def.chantype=cell(length(opto_MNI.chantype),1);
opto_def.chantype(:)={'nirs'};
opto_def.optolabel=opto_MNI.label;
opto_def.label=channels;
opto_def.tra=zeros(length(channels),length(opto_def.optolabel));
for i=1:length(channels)
    opto_def.tra(i,:)=strcmp(rxnames{i},opto_def.optolabel)+strcmp(txnames{i}, opto_def.optolabel);
end
opto_def=rmfield(opto_def, {'chanpos', 'chantype', 'chanunit', 'elecpos'});

% calculate the channel positions
opto_chan = ft_datatype_sens(opto_def)

% visualize
figure; ft_plot_mesh(skin,'edgecolor','none','facealpha',0.8,'facecolor',[0.6 0.6 0.8]);
hold on; ft_plot_sens(opto_chan, 'opto', true, 'optosize', 10,'facecolor', 'k', 'label', 'label')


%% Determine anatomical laber for the channels
% documentation: http://www.fieldtriptoolbox.org/faq/how_can_i_determine_the_anatomical_label_of_a_source/
% load atlas (AAL atlas), but you can also load another atlas, see: http://www.fieldtriptoolbox.org/template/atlas/
atlas = ft_read_atlas([ftpath filesep 'template/atlas/aal/ROI_MNI_V4.nii']);

channels = {'Rx1-Tx2', 'Rx1-Tx3', 'Rx2-Tx3', 'Rx2-Tx4', 'Rx3-Tx2', 'Rx3-Tx3', 'Rx3-Tx5', 'Rx4-Tx3', 'Rx4-Tx4', 'Rx4-Tx5', 'Rx5-Tx7', 'Rx5-Tx8', 'Rx7-Tx7', 'Rx7-Tx8', 'Rx6-Tx9', 'Rx8-Tx9', 'Rx8-Tx10', 'Rx9-Tx12', 'Rx9-Tx13', 'Rx11-Tx12', 'Rx11-Tx13', 'Rx10-Tx14', 'Rx12-Tx14', 'Rx12-Tx15'};
%channels = {'Rx1-Tx1b', 'Rx2-Tx1a', 'Rx3-Tx1d', 'Rx4-Tx1c', 'Rx5-Tx6b', 'Rx6-Tx6a', 'Rx7-Tx6d', 'Rx8-Tx6c', 'Rx9-Tx11a', 'Rx10-Tx11b', 'Rx11-Tx11c', 'Rx12-Tx11d'};

% Look up the corresponding anatomical label
cfg            = [];
cfg.roi        = opto_chan.chanpos(match_str(opto_chan.label,channels),:);
cfg.atlas      = atlas;
cfg.output     = 'multiple';
cfg.minqueryrange =1;
cfg.maxqueryrange=25; %if no label was found, increase the queryrange
labels = ft_volumelookup(cfg, atlas);

% Select the anatomical label with the highest probability
for i=1:length(channels)
    [~, indx] = max(labels(i).count);
    label{i}=char(labels(i).name(indx));
end

% show results in table

roi_table=table(channels', label', 'VariableNames', {'channel', 'label'});
save('roi_table.mat', 'roi_table')

%% Create layout based on 3D positions
cfg=[];
cfg.opto=opto_chan;
cfg.rotate=0;
layout=ft_prepare_layout(cfg);

% plot layout
cfg = [];
cfg.layout= layout;
ft_layoutplot(cfg);

% create outline and mask based on image
image=fullfile(root_dir, '10-20_EEG_v2.png');
cfg=[];
cfg.image=image;
bg=ft_prepare_layout(cfg);
% 1. specify electrode locations --> only select Cz as electrode (we need
% it as the middlepoint to allign the layout with the mask & outline) --> press q
% 2. create mask: this area will be used when making a topoplot; you can
% skip this step for now and make this in a later step when you know better
% the channel locations --> press q
% 3. create outline: this are the lines that will be shown in the layout
% (e.g. head shape, sulci) (see info
% on command window how to create the polygon)--> press q

% scale according to layout and place Cz in the middle
% bg.mask={[bg.mask{1}]-bg.pos(1,:)};
% bg.mask={[bg.mask{1}/250]};
for i=1:length(bg.outline)
    bg.outline{i}=[bg.outline{i}]-bg.pos(1,:); % center around Cz
    bg.outline{i}=[bg.outline{i}]/250; % scale
end
bg.pos=bg.pos-bg.pos(1,:);
bg.pos=bg.pos/250;

% combine into one layout
% layout.mask=bg.mask;
layout.outline=bg.outline;
% visualize
figure; ft_plot_layout(layout);

save('layout.mat', 'layout');

% change the mask based on the layout with outline you've just created
saveas(gcf, 'layout.png')
image='layout.png';
cfg=[];
cfg.image=image;
bg=ft_prepare_layout(cfg);
% this time select Cz and the mask

% again center around Cz + rescale
for i=1:length(bg.mask)
    bg.mask{i}=[bg.mask{i}]-bg.pos(1,:); % center around Cz
    bg.mask{i}=[bg.mask{i}]*(1.1/150); % scale
end

load('layout.mat')
layout.mask=bg.mask;
figure; ft_plot_layout(layout)

save('layout.mat', 'layout')

