% MATLAB SCRIPT FOR THE AUTOMATICITY TEST
% A dual-task paradigm in which we test whether a 12 digit prelearned
% sequence has become an automatic movement for a finger tapping and a foot
% stomping task. The script is randomized in such a way that it either
% starts with the finger tapping or the foot stomping task. After that the
% experiment will automatically proceed for the other limb.

%Before starting the automaticity test, clear the workspace.
clear all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% START ZMQ & LSL
% raspberry names
zmq_proxy='lsldert00.local';
lsl_hosts={'lsldert00', 'lsldert04'};

% add lsl streams
trigstr=cell(1);
nstr=0;
for ii=1:numel(lsl_hosts)
    host=lsl_hosts{ii};
    info_type=sprintf('type=''Digital Triggers @ %s''',host);
    info=lsl_resolver(info_type);
    desc=info.list();
    if isempty(desc)
        warning('lsl stream on host ''%s'' not found', host);
    else
        nstr=nstr+1;
        fprintf('%d: name: ''%s'' type: ''%s''\n',nstr,desc(1).name,desc(1).type);
        trigstr{nstr}=lsl_istream(info{1});
    end
    delete(info);
end
trig = lsldert_pubclient(zmq_proxy);
cleanupObj=onCleanup(@()cleanupFun);

% create session
ses=lsl_session();
for ii=1:nstr
    ses.add_stream(trigstr{ii});
end

% add listener
for ii=1:nstr
    addlistener(trigstr{ii}, 'DataAvailable', @triglistener);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%INITIALISATION
% start lsl session
ses.start();
trig.digitalout(0, 'TTL_init'); % ensures that the output is set to 0

%Open Phsychtoolbox.
PsychDefaultSetup(2);
KbName('UnifyKeyNames'); %Links the key presses to the key board names
% ListenChar; % option A
KbQueueCreate; % option B
KbQueueStart; % option B

%Skip screen synchronization to prevent Pyshtoolbox for freezing
Screen('Preference', 'SkipSyncTests', 1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%LOAD METRONOME SOUNDS (PsychToolbox)
audio_dir='C:\Users\mtabo\Documents\TryOutScript\metronomesounds';
cd(audio_dir)
[WAVMetronome8.wave,WAVMetronome8.fs]       = audioread('Metronome5.wav');

% change rows<>columns
WAVMetronome8.wave = WAVMetronome8.wave';         WAVMetronome8.nrChan=2;

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
h_Metronome8   = PsychPortAudio('Open', [], [], priority, WAVMetronome8.fs, WAVMetronome8.nrChan);

% Fill buffer
PsychPortAudio('FillBuffer', h_Metronome8, WAVMetronome8.wave);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%SAVE FILES IN FOLDER

fprintf('Select the project directory \n')
root_dir=uigetdir('C:\Users\mtabo\Documents\TryOutScript\', 'Select the project directory');

complete=0;
while complete==0
    sub_ID=input('What is the subject ID (2 digit number) \n', 's');
    sub=sprintf('sub-%s', sub_ID);
        rec_n=input('What is the number of the recording? \n');
        rec=sprintf('rec-%.2d', rec_n);
     
    inf=fprintf('\n root_dir = %s \n sub = %s \n rec = %s \n', root_dir, sub, rec);
    correct=input('Is the above information correct? (y/n) \n', 's');
    if strcmp(correct, 'y')
        complete=1;
    else
        continue
    end
end

% go to subject folder
sub_dir=fullfile(root_dir, sub);
if ~exist(sub_dir)
    mkdir(sub_dir)
end
cd(sub_dir)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%SET UP PARAMETERS

sequenceA = '4 3 4 1 4 1 2 4 3 2 1 2';
sequenceB = '2 1 2 3 2 1 3 2 4 2 4 1';

%Parameters for the resting period in between the trials
t1 = 20; %Resting period in seconds
t2 = 5;  %Random interval around the resting period time

%Amount of letters presented during test for automaticity for one trial.
%Should be adjusted when letter presenting speed is changed!
N_letters=8; % 8 letters presented during a trial
N_trials=11; % number of trials performed for each limb 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RANDOMIZATION

sequenceauto = sequenceA;

%Create a vector to represent the two different options (1=finger tapping
%test, 2= foot stomping test).
order_autodual=[1,2];
%Save the order of the automaticity test experiment
save('order_autodual.mat', 'order_autodual');

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

% preparations for the fixation cross so we only need to do this once
fixCrossDimPix = 40; % Here we set the size of the arms of our fixation cross
xCoords = [-fixCrossDimPix fixCrossDimPix 0 0]; % Set the coordinates (these are all relative to zero we will let the drawing routine center the cross in the center of our monitor for us)
yCoords = [0 0 -fixCrossDimPix fixCrossDimPix];
allCoords = [xCoords; yCoords];
lineWidthPix = 4;% Set the line width for the fixation cross

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%START TEST FOR AUTOMATICITY

%Empty structure for key presses -> use later again so it saves the key
%presses within this structure -> save at the end
presses_handautodual=struct([]);
letters_handautodual=struct([]); % same for the presented letters of the hand + the answer
letters_footautodual=struct([]); % same for the presented letters of the foot + the answer

%Instruction automaticity test
Screen('TextSize',window,25);
DrawFormattedText(window,'You will now start with the automaticity test. \n You will either start with the finger tapping or foot stomping task. \n Instructions will be given at the start of each task. \n Press any key to continue.','center', 'center', white);
vbl = Screen('Flip', window);
KbStrokeWait; %wait for response to terminate instructions

%Start the randomization loop
for i=order_autodual %Either [1,2] or [2,1] -> determines the order of the tasks
  
  % Finger tapping test -> 10 trials, presents letters upon randomized speed
  if i==1
    %Instruction automaticity task finger tapping
    trig.beep(400, 0.1, 'instructions');
    Screen('TextSize',window,25);
    DrawFormattedText(window, fprintf('You will now perform the pre-learned sequence for the FINGER tapping task. \n %s \n\n  Letters will be shown on the screen (A,G,O,L) while you perform the task. \n The goal is to perform the sequence tapping while counting how many times G is presented. \n After each time you tapped the full sequence, you should tell us how many times G was presented. \n We will perform 11 trails. \n\n Note that during the tapping task you cannot talk. \n Try to keep your body movements as still as possible exept for the right hand. \n\n In between the trials you will see a fixation cross for 20 seconds. \n During the first 8 seconds you will hear a metronome sound. \n Tap the sequence on this rhythm, which is the same as you studied at home. \n\n We will start with a fixation cross on the screen for 20 seconds. \n After that the first trial will start automatically. \n So start tapping the sequence as soon as a letter on the screen appears. \n Press any key to continue and start the test.', sequenceauto),'center','center', white);
    vbl = Screen('Flip', window);
    KbStrokeWait; %wait for response to terminate instructions
    
    for j=1:N_trials
      %Presentation of the letters on the screen (dual task). -> is random.
      %Participant has to count the amount that G was presented.
      Letterlist= {'A', 'G', 'O', 'L'};
      letter_order=randi(length(Letterlist), 1, N_letters);
      letters_handautodual(j).presented =Letterlist(letter_order);
      
      % always start with a 20-25 seconds fixation cross with 8 seconds of metronome
      % sound
      trig.beep(400, 0.1, 'rest');
      Screen('TextSize', window, 36);
      Screen('DrawLines', window, allCoords,...
        lineWidthPix, white, [xCenter yCenter], 2);
      Screen('Flip', window);
      PsychPortAudio('Start', h_Metronome8, 1, [], []); % Play metronome sound file (8 seconds)
      WaitSecs(t1+randi(t2))
      
      %Presentation of random letters on the screen during the finger
      %tapping test + recording of the key presses
      trig.beep(400, 0.1, 'finger_auto_dual');
      m=1; % first key press
      %           FlushEvents('keyDown'); % option A: clear all previous key presses from the list
      KbQueueFlush; % option B: clear all previous key presses from the list
      for n=1:N_letters
        % present random letter
        Screen('TextSize', window, 100);
        DrawFormattedText(window, [cell2mat(letters_handautodual(j).presented(n))],'center','center', white);
        vbl = Screen('Flip', window);
        time_letter=rand(1)+0.5; %Speed with which the letters are presented = A randomized value between 0 and 1, + 0.5 sec
        
        % record key presses
        start_timer=GetSecs;
        while GetSecs-start_timer<time_letter
          %                   if CharAvail % option A
          %                     [ch, when]=GetChar;
          %                     fprintf('the key value was: %s \n', ch);
          %                     presses_handtest(j).key{m}=ch;
          %                     presses_handtest(j).secs(m)=when.secs;% better than using string arrays
          %                     m=m+1;
          %                   end
          [ pressed, firstPress, ~, lastPress, ~]=KbQueueCheck; % option B
          if pressed
            if isempty(find(firstPress~=lastPress)) % no key was pressed twice
              keys=KbName(find(firstPress)); % find the pressed keys
              [timing, idx]=sort(firstPress(find(firstPress))); % get timing of key presses in ascending order
              keys=keys(idx); % sort the pressed keys in ascending order
              key_n=length(keys); % number of pressed keys
              presses_handautodual(j).key(m:m+key_n-1)=keys;
              presses_handautodual(j).secs(m:m+key_n-1)=timing;
              m=m+key_n;
              KbQueueFlush;
            else
              error('key was pressed twice') % if this error occurs we need to find a way to handle this
            end
          end
        end
        
        % between each letter red fixation cross
        Screen('DrawLines', window, allCoords,...
          lineWidthPix, [1 0 0], [xCenter yCenter], 2);
        Screen('Flip', window);
        WaitSecs (0.2);
      end
      
      % present white fixation cross for some seconds to show that
      % trial is over
      trig.beep(400, 0.1, 'rest');
      Screen('TextSize', window, 36);
      Screen('DrawLines', window, allCoords,...
        lineWidthPix, white, [xCenter yCenter], 2);
      Screen('Flip', window);
      WaitSecs(5); % changed this to 5 seconds, so the nirs signal has time to go back to baseline
      
      % show feedback
      % ask how many G's were presented
      Screen('TextSize',window,30);
      DrawFormattedText(window, 'How many times was G presented? ','center','center', white);
      vbl = Screen('Flip', window);
      [secs, keyCode, deltaSecs]=KbWait;
      letters_handautodual(j).reported_G=KbName(find(keyCode));
      DrawFormattedText(window, ['Your answer: ' letters_handautodual(j).reported_G '\n Press any key to continue.'],'center','center', white);
      vbl = Screen('Flip', window);
      KbStrokeWait; %wait for response to terminate instruction
      DrawFormattedText(window, 'Press any key to continue with the next trail. \n Note that you will first start with a fixation cross again. \n Start tapping the sequence as soon as a letter on the screen appears.' ,'center','center', white);
      vbl = Screen('Flip', window);
      KbStrokeWait;
    end
    
    % After all trials completed, the end of the finger tapping task is
    % reached.
    Screen('TextSize',window,30);
    DrawFormattedText(window, 'This is the end of the automaticity test for the finger tapping task. \n  Press any key to end this session.' ,'center','center', white);
    vbl = Screen('Flip', window);
    save('letters_handautodual.mat', 'letters_handautodual'); % save the letters that were presented and the reported number of g's
    save('presses_handautodual.mat', 'presses_handautodual'); %Save which keys where pressed during the experiment
    KbStrokeWait; %wait for response to terminate instructions
    
  elseif i==2 % foot test, presents letters upon randomized speed
    % Instruction automaticity task foot stomping
    trig.beep(400, 0.1, 'instructions');
    Screen('TextSize',window,25);
    DrawFormattedText(window, fprintf('You will now perform the pre-learned sequence for the FOOT stomping task. \n %s \n\n  Letters will be shown on the screen (A,G,O,L) while you perform the task. \n The goal is to perform the sequence stomping while counting how many times G is presented. \n After each time you stomped the full sequence, you should tell us how many times G was presented. \n We will perform 11 trials. \n\n Note that during the stomping task you cannot talk. \n Try to keep your body movements as still as possible exept for your right leg. \n\n In between the trials you will see a fixation cross for 20 seconds. \n During the first 8 seconds you will hear a metronome sound. \n Stomp the sequence on this rhythm, which is the same as you studied at home. \n\n We will start with a fixation cross on the screen for 20 seconds. \n After that the first trial will start automatically. \n So start stomping the sequence as soon as a letter on the screen appears. \n Press any key to continue and start the test.', sequenceauto),'center','center', white);
    vbl = Screen('Flip', window);
    KbStrokeWait; %wait for response to terminate instructions
    
    trig.digitalout(1, 'start_rec'); % starts the recording of xsens
    for j=1:N_trials
      %Presentation of the letters on the screen (dual task). -> is random.
      %Participant has to count the amount that G was presented.
      Letterlist= {'A', 'G', 'O', 'L'};
      letter_order=randi(length(Letterlist), 1, N_letters);
      letters_footautodual(j).presented =Letterlist(letter_order);
      
      % always start with a fixation cross and 8 seconds of metronome
      % sound
      trig.beep(400, 0.1, 'rest');
      Screen('TextSize', window, 36);
      Screen('DrawLines', window, allCoords,...
        lineWidthPix, white, [xCenter yCenter], 2);
      Screen('Flip', window);
      PsychPortAudio('Start', h_Metronome8, 1, [], []); % Play metronome sound file (8 seconds)
      WaitSecs(t1+randi(t2))
      
      %Presentation of random letters on the screen during the foot
      %stomping test
      trig.beep(400, 0.1, 'foot_auto_dual');
      for n=1:N_letters
        % present random letter
        Screen('TextSize', window, 100);
        DrawFormattedText(window, [cell2mat(letters_footautodual(j).presented(n))],'center','center', white);
        vbl = Screen('Flip', window);
        time_letter=rand(1)+0.5; %Speed with which the letters are presented = A randomized value between 0 and 1, + 0.5 sec
        WaitSecs(time_letter);
        
        % between each letter red fixation cross
        Screen('DrawLines', window, allCoords,...
          lineWidthPix, [1 0 0], [xCenter yCenter], 2);
        Screen('Flip', window);
        WaitSecs (0.2);
      end
      
      % present white fixation cross for some seconds to show that
      % trial is over
      trig.beep(400, 0.1, 'rest');
      Screen('TextSize', window, 36);
      Screen('DrawLines', window, allCoords,...
        lineWidthPix, white, [xCenter yCenter], 2);
      Screen('Flip', window);
      WaitSecs(5);
      
      % show feedback
      % ask how many G's were presented
      Screen('TextSize',window,30);
      DrawFormattedText(window, 'How many times was G presented? ','center','center', white);
      vbl = Screen('Flip', window);
      [secs, keyCode, deltaSecs]=KbWait;
      letters_footautodual(j).reported_G=KbName(find(keyCode));
      DrawFormattedText(window, ['Your answer: ' letters_footautodual(j).reported_G '\n Press any key to continue.'],'center','center', white);
      vbl = Screen('Flip', window);
      KbStrokeWait; %wait for response to terminate instruction
      DrawFormattedText(window, 'Press any key to continue with the next trail. \n Note that you will first start with a fixation cross again. \n Start tapping the sequence as soon as a letter on the screen appears.' ,'center','center', white);
      vbl = Screen('Flip', window);
      KbStrokeWait;
    end
    
    % After all trials completed, the end of the foot stomping task is reached.
    trig.digitalout(0, 'stop_rec'); % stops the recording of xsens
    Screen('TextSize',window,25);
    DrawFormattedText(window, 'End of the automaticity test for the foot stomping task. \n Press any key to end this session.','center','center', white);
    vbl = Screen('Flip', window);
    save('letters_footautodual.mat', 'letters_footautodual'); % save the letters that were presented and the reported number of g's
    KbStrokeWait; %wait for response to terminate instructions
  end
end

%Show dual task performance on screen (finger tapping)
for h = 1:N_trials
     if str2num(letters_handautodual(h).reported_G)==sum(strcmp(letters_handautodual(h).presented, 'G'))
      fprintf('Finger autodual: G correct \n')
     else
      fprintf('Finger autodual: G incorrect \n')
     end 
      %Show if the tempo was correct. ! reflect if you want to show
      %this, because we cannot show this result for the foot stomping
      margin=0.1; % margin of error: think about what is most convenient
      if (all(abs(diff(presses_handautodual(h).secs)-1/1.5)<margin))
        fprintf('Finger autodual: tempo correct \n')
      else
        fprintf('Finger autodual: tempo incorrect \n')  
      end
      
end

%Show dual task performance on screen (foot stomping)
for g = 1:N_trials
      if str2num(letters_footautodual(g).reported_G)==sum(strcmp(letters_footautodual(g).presented, 'G'))
        fprintf('Foot autodual: G correct \n')
      else
        fprintf('Foot autodual: G incorrect \n')
      end 
end  

% End of automaticity test is reached (both limbs are tested)
Screen('TextSize',window,25);
DrawFormattedText(window,'You have completed the automaticity test. \n We will start with the preparation of the experiment now. \n Press any key to continue.','center', 'center', white);
vbl = Screen('Flip', window);
%Press key to end the session and return to the 'normal' screen.
KbStrokeWait; %wait for response to terminate instructions
sca

%% end the lsl session
delete(trig); 
ses.stop();

%% HELPER FUNCTIONS
function triglistener(src, event)
for ii=1:numel(event.Data)
  info=src.info;
  fprintf('   lsl event (%s) received @ %s with (uncorrected) timestamp %.3f \n',  event.Data{ii}, info.type, event.Timestamps(ii));
end
end

function cleanupFun()
delete(ses);
delete(trigstr{1});
delete(trigstr{2});
delete(info);
end

