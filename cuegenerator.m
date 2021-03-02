% % % CUE GENERATOR  % % %
clc, clear all, close all

%% Settings
% This needs to be set

f_sound = 350;                      % Pitch of the sound
f_cues  = 1.5;                        % Frequency of the cues
Dur_end = 0.1;                       % Duration of the cue
seconds = 120;                      % Duration of the sound file
file    = ['Metronome' num2str(seconds) '.wav']; % Name of the sound file

%% Create Matrix for Sound

fs      = 2^13;                     % Sample frequency
t_end   = 1/f_cues;                 

t       = 0:1/fs:t_end;             % Total time axis for cue
Cues    = zeros(length(t),2);       % Matrix for cue to be saved in

%% Generate Sound

Dur     = 0:1/fs:Dur_end;           % Time axis with duration of cue

Sound   = sin(2.*pi.*f_sound.*Dur); 
Sound   = [sum(Sound,1); sum(Sound,1)]';

%% Fades

Fade_length = Dur_end/20;           % Length of the fade
Fade_samps  = round(Fade_length.*fs);

Fade_in     = 0:1/Fade_samps:1;     % Fade in
Fade_out    = fliplr(Fade_in);      % Fade out

Fade        = ones(length(Dur),2);  % Size of fade
Fade(1:length(Fade_in),:)                   = repmat(Fade_in',1,2);
Fade(length(Fade)-length(Fade_out)+1:end,:) = repmat(Fade_out',1,2);

%% Generate Cue
% One cue gets generated

Cues(1:length(Sound),:) = Sound.*Fade;

%% Repeat
% Repeat said cue until seconds runs out

Repetitions = round(seconds/t_end);
CuesComp    = repmat(Cues,Repetitions,1);

%% Save
% type 'y' or 'n' if you want to save or not

prompt      = 'Do you want to save? y/n ';
saving      = input(prompt);

switch saving
    case 'y'
        audiowrite(file,CuesComp,fs)
    case 'n'
end