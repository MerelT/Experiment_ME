% FAMILIARIZATION SCRIPT
% Presenting the studied sequence on the screen for 4 minutes total(add the
% right sequence in line 110 and 123!!!), while also a metronome sound of 90bpm
% (1.5Hz) is playing. 2 min practicing for each limb, for the participant
% to get used to the experiment set up. 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%LSL SET UP
%LSL outlet sending events
%
% Create and load the lab streaming layer library
lib = lsl_loadlib();
%
% Make a new stream outlet.
% info = lsl_streaminfo([lib handle],[name],[type],[channelcount],[fs],[channelformat],[sourceid])
% > name = name of stream; describes device/product
% > type = content type of stream (EEG, Markers)
% > channelcount = nr of channels per sample
% > fs = samplking rate (Hz) as advertized by data source
% > channelformat = cf_float32, cf__double64, cf_string, cf_int32, cf_int16
% > sourceid = unique identifier for source or device, if available
info = lsl_streaminfo(lib,'AutovsNAuto','Markers',1,0.0,'cf_string','sdfwerr32432');
%
% Open an outlet for the data to run through.
outlet = lsl_outlet(info);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%INITIALISATION

%Open Phsychtoolbox.
PsychDefaultSetup(2);

%Skip screen synchronization to prevent Pyshtoolbox for freezing
Screen('Preference', 'SkipSyncTests', 1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%LOAD METRONOME SOUNDS (PsychToolbox)
audio_dir='C:\Users\Helena\Documents\Experiment_ME\metronomesounds';
cd(audio_dir)
[WAVMetronome120.wave,WAVMetronome120.fs]       = audioread('Metronome120.wav');

% change rows<>columns
WAVMetronome120.wave = WAVMetronome120.wave';         WAVMetronome120.nrChan=2;

% CREATE AND FILL AUDIO BUFFER
% Initialize Sounddriver
% This routine loads the PsychPortAudio sound driver for high precision, low latency,
% multichannel sound playback and recording
% Call it at the beginning of your experiment script, optionally providing the
% 'reallyneedlowlatency'-flag set to 1 to push really hard for low latency
InitializePsychSound(1);

priority = 0;                       % 0 = better quality, increased latency; 1 = minimum latency
duration = 1;                       % number of repetitions of the wav-file
PsychPortAudio('Verbosity',1);      % verbosity = "wordiness" -> 1= print errors

% Get audio device
h_device = PsychPortAudio ('GetDevices');

% Open handle
h_Metronome120   = PsychPortAudio('Open', [], [], priority, WAVMetronome120.fs, WAVMetronome120.nrChan);

% Fill buffer
PsychPortAudio('FillBuffer', h_Metronome120, WAVMetronome120.wave);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SCREEN PREPARATION

% Get the screen numbers.
screens = Screen('Screens');

% Select the external screen if it is present, else revert to the native
% screen
screenNumber = max(screens);

% Define black, white and grey
black = BlackIndex(screenNumber);
white = WhiteIndex(screenNumber);

% Open an on screen window and color it grey
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);

% Get the size of the on screen window in pixels
% For help see: Screen WindowSize?
[screenXpixels, screenYpixels] = Screen('WindowSize', window);

% Get the centre coordinate of the window in pixels
% For help see: help RectCenter
[xCenter, yCenter] = RectCenter(windowRect);

% Query the frame duration
ifi = Screen('GetFlipInterval', window);

% Set up alpha-blending for smooth (anti-aliased) lines
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% START FAMILIARIZATION

%Instruction familiarization
Screen('TextSize',window,25);
DrawFormattedText(window,'In the upcoming 4 minutes you have time to get familiarized with the experimental set up. \n You have 2 minutes to practice the finger tapping task. \n And also 2 minutes to practice the foot stomping task. \n The sequence will be shown on the screen. \n You will also hear a metronome sound, which is at the same speed as you studied at home. \n Press any key to start practicing the sequence for finger tapping.','center', 'center', white);
vbl = Screen('Flip', window);
KbStrokeWait; 

%Presenting the sequence to study on the screen (for hand 2 min)
Screen('TextSize', window, 50);
DrawFormattedText(window, '4 3 4 1 4 1 2 4 3 2 1 2', 'center', 'center', white);
vbl= Screen('Flip', window);
PsychPortAudio('Start', h_Metronome120, 1, [], []); %Play metronome sound file (10 minutes)
WaitSecs(120)

%End of finger tapping familiarization
Screen('TextSize',window,25);
DrawFormattedText(window,'The time to familiarize for the finger tapping task is over. \n Press any key to start practicing the seqeunce for the foot stomping task.','center', 'center', white);
vbl = Screen('Flip', window);
KbStrokeWait; 

%Presenting the sequence to study on the screen (for foot 2 min)
Screen('TextSize', window, 50);
DrawFormattedText(window, '4 3 4 1 4 1 2 4 3 2 1 2', 'center', 'center', white);
vbl= Screen('Flip', window);
PsychPortAudio('Start', h_Metronome120, 1, [], []); %Play metronome sound file (10 minutes)
WaitSecs(120)

Screen('TextSize', window, 25);
DrawFormattedText(window, 'The familiarization time is over. \n Press any key to end the program.', 'center', 'center', white);
vbl= Screen('Flip', window);
KbStrokeWait;
sca
