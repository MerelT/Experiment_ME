% MATLAB SCRIPT FOR THE AUTOMATICITY TEST
% A dual-task paradigm in which we test whether a 12 digit prelearned
% sequence (sequenceauto) has become an automatic movement for a finger 
% tapping and a foot stomping task. 

%Before starting the automaticity test, clear the workspace.
clear all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% START ZMQ & LSL
% raspberry names
% zmq_proxy='lsldert00.local';
% lsl_hosts={'lsldert00', 'lsldert04', 'lsldert05'};
% 
% % add lsl streams
% trigstr=cell(1);
% nstr=0;
% for ii=1:numel(lsl_hosts)
%     host=lsl_hosts{ii};
%     info_type=sprintf('type=''Digital Triggers @ %s''',host);
%     info=lsl_resolver(info_type);
%     desc=info.list();
%     if isempty(desc)
%         warning('lsl stream on host ''%s'' not found', host);
%     else
%         nstr=nstr+1;
%         fprintf('%d: name: ''%s'' type: ''%s''\n',nstr,desc(1).name,desc(1).type);
%         trigstr{nstr}=lsl_istream(info{1});
%     end
%     delete(info);
% end
% trig = lsldert_pubclient(zmq_proxy);
% cleanupObj=onCleanup(@()cleanupFun);
% 
% % create session
% ses=lsl_session();
% for ii=1:nstr
%     ses.add_stream(trigstr{ii});
% end
% 
% % add listener
% for ii=1:nstr
%     addlistener(trigstr{ii}, 'DataAvailable', @triglistener);
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%INITIALISATION
% start lsl session
% ses.start();
% trig.digitalout(0, 'TTL_init'); % ensures that the output is set to 0
% trig.pulseIR(3, 0.2); % start trigger for the nirs recording

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
audio_dir='C:\Users\mtabo\Documents\TryOutScript\Experiment_ME\metronomesounds';
cd(audio_dir)
[WAVMetronome8.wave,WAVMetronome8.fs]       = audioread('Metronome8.wav');

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

% save current script in subject directory
% script=mfilename('fullpath');
% script_name=mfilename;
% copyfile(sprintf('%s.m', script), fullfile(sub_dir, sprintf('%s_%s.m', sub, script_name)))

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%SET UP PARAMETERS

%The sequences used for this study
sequenceA = '4 3 4 1 4 1 2 4 3 2 1 2';
sequenceB = '2 1 2 3 2 1 3 2 4 2 4 1';
sequenceprintA = 'R3R1R12R3212';
sequenceprintB = '21232132R2R1'; 

%Parameters for the resting period in between the trials
t1 = 20; %Resting period in seconds
t2 = 5;  %Random interval around the resting period time

%Amount of letters presented during test for automaticity for one trial.
%Should be adjusted when letter presenting speed is changed!
N_letters=8; % 8 letters presented during a trial
N_trials=5; % number of trials performed for each limb 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RANDOMIZATION

%Set the right sequence that was studied at home (= automatic)
sequenceauto = sequenceA;
sequenceautoprint = sequenceprintA;

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
DrawFormattedText(window,'You will now start with the automaticity test. \n You will either start with the finger tapping or foot stomping task. \n Detailed instructions will be given at the start of each task. \n Press any key to continue.','center', 'center', white);
vbl = Screen('Flip', window);
KbStrokeWait; %wait for response to terminate instructions

%Start the randomization loop
for i=order_autodual %Either [1,2] or [2,1] -> determines the order of the tasks
  
  % Finger tapping test -> 11 trials, presents letters upon randomized speed
  if i==1
    %Instruction automaticity task finger tapping
    %trig.beep(440, 0.2, 'instructions');
    Screen('TextSize',window,25);
    DrawFormattedText(window, sprintf('You will now perform the pre-learned sequence for the FINGER tapping task: \n %s \n\n  While you perform the task, letters will be shown on the screen (A,G,O,L). \n The goal is to perform the sequence tapping while counting how many times G is presented. \n After each time you tapped the full sequence, you should tell us how many times G was presented. \n For answering this question, \n keep in mind that if the answer is 4 you press 4 and not Return (Enter) on the keyboard. \n\n We will perform 11 trails. \n Note that during the tapping task you cannot talk. \n Try to keep your body movements as still as possible exept for the right hand. \n Keep your eyes open (also during the rest periods). \n\n In between the trials you will see a fixation cross for 20 seconds. \n During the first few seconds you will hear a metronome sound. \n Tap the sequence on this rhythm, which is the same as you studied at home. \n\n We will start with a fixation cross on the screen for 20 seconds. \n After that the first trial will start automatically. \n So start tapping the sequence as soon as a letter on the screen appears. \n When ready: press any key to continue and start the test.', sequenceauto),'center','center', white);
    vbl = Screen('Flip', window);
    KbStrokeWait; %wait for response to terminate instructions
    
    for j=1:N_trials
      %Presentation of the letters on the screen (dual task). -> is random.
      %Participant has to count the amount that G was presented.
      Letterlist= {'A', 'G', 'O', 'L'};
      letter_order=randi(length(Letterlist), 1, N_letters);
      letters_handautodual(j).presented =Letterlist(letter_order);
      
      % Always start with a 20-25 seconds fixation cross with 8 seconds of metronome
      % sound
      %trig.beep(440, 0.2, 'rest');
      Screen('TextSize', window, 36);
      Screen('DrawLines', window, allCoords,...
        lineWidthPix, white, [xCenter yCenter], 2);
      Screen('Flip', window);
      PsychPortAudio('Start', h_Metronome8, 1, [], []); % Play metronome sound file (8 seconds)
      WaitSecs(t1+randi(t2))
      
      %Presentation of random letters on the screen during the finger
      %tapping test + recording of the key presses
      %trig.beep(440, 0.2, 'finger_auto_dual');
      m=1; % first key press
      %           FlushEvents('keyDown'); % option A: clear all previous key presses from the list
      KbQueueFlush; % option B: clear all previous key presses from the list
      for n=1:N_letters
        % Present random letter
        Screen('TextSize', window, 100);
        DrawFormattedText(window, [cell2mat(letters_handautodual(j).presented(n))],'center','center', white);
        vbl = Screen('Flip', window);
        time_letter=rand(1)+0.5; %Speed with which the letters are presented = A randomized value between 0 and 1, + 0.5 sec
        
        % Record key presses
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
            else
              error('key was pressed twice') % if this error occurs we need to find a way to handle this
            end
          end
        end
        
        % Between each letter show a red fixation cross
        Screen('DrawLines', window, allCoords,...
          lineWidthPix, [1 0 0], [xCenter yCenter], 2);
        Screen('Flip', window);
        WaitSecs (0.2);
      end
      
      % Present white fixation cross for some seconds to show that
      % trial is over
      %trig.beep(440, 0.2, 'rest');
      Screen('TextSize', window, 36);
      Screen('DrawLines', window, allCoords,...
        lineWidthPix, white, [xCenter yCenter], 2);
      Screen('Flip', window);
      WaitSecs(5); % changed this to 5 seconds, so the nirs signal has time to go back to baseline
      
      % Ask how many G's were presented
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
    DrawFormattedText(window, 'This is the end of the automaticity test for the finger tapping task. \n You can take a rest if needed. \n When ready: press any key to end this session.' ,'center','center', white);
    vbl = Screen('Flip', window);
    save('letters_handautodual.mat', 'letters_handautodual'); % save the letters that were presented and the reported number of g's
    save('presses_handautodual.mat', 'presses_handautodual'); % save which keys where pressed during the experiment
    KbStrokeWait; %wait for response to terminate instructions
    
    
    % Foot stomping test -> 11 trials, presents letters upon randomized speed
  elseif i==2
    % Instruction automaticity task foot stomping
    %trig.beep(440, 0.2, 'instructions');
    Screen('TextSize',window,25);
    DrawFormattedText(window, sprintf('You will now perform the pre-learned sequence for the FOOT stomping task: \n %s \n\n While you perform the task, letters will be shown on the screen (A,G,O,L). \n The goal is to perform the sequence stomping while counting how many times G is presented. \n After each time you stomped the full sequence, you should tell us how many times G was presented. \n For answering this question, \n keep in mind that if the answer is 4 you press 4 and not Return (Enter) on the keyboard. \n\n We will perform 11 trials. \n Note that during the stomping task you cannot talk. \n Try to keep your body movements as still as possible exept for your right leg. \n Keep your eyes open (also during the rest periods). \n\n In between the trials you will see a fixation cross for 20 seconds. \n During the first few seconds you will hear a metronome sound. \n Stomp the sequence on this rhythm, which is the same as you studied at home. \n\n We will start with a fixation cross on the screen for 20 seconds. \n After that the first trial will start automatically. \n So start stomping the sequence as soon as a letter on the screen appears. \n When ready: press any key to continue and start the test.', sequenceauto),'center','center', white);
    vbl = Screen('Flip', window);
    KbStrokeWait; %wait for response to terminate instructions
    
    %trig.digitalout(1, 'start_rec'); % starts the recording of xsens
    for j=1:N_trials
      %Presentation of the letters on the screen (dual task). -> is random.
      %Participant has to count the amount that G was presented.
      Letterlist= {'A', 'G', 'O', 'L'};
      letter_order=randi(length(Letterlist), 1, N_letters);
      letters_footautodual(j).presented =Letterlist(letter_order);
      
      % Always start with a fixation cross and 8 seconds of metronome
      % sound
      %trig.beep(440, 0.2, 'rest');
      Screen('TextSize', window, 36);
      Screen('DrawLines', window, allCoords,...
        lineWidthPix, white, [xCenter yCenter], 2);
      Screen('Flip', window);
      PsychPortAudio('Start', h_Metronome8, 1, [], []); % Play metronome sound file (8 seconds)
      WaitSecs(t1+randi(t2))
      
      %Presentation of random letters on the screen during the foot
      %stomping test
      %trig.beep(880, 0.2, 'foot_auto_dual');
      for n=1:N_letters
        % present random letter
        Screen('TextSize', window, 100);
        DrawFormattedText(window, [cell2mat(letters_footautodual(j).presented(n))],'center','center', white);
        vbl = Screen('Flip', window);
        time_letter=rand(1)+0.5; %Speed with which the letters are presented = A randomized value between 0 and 1, + 0.5 sec
        WaitSecs(time_letter);
        
        % Between each letter show a red fixation cross
        Screen('DrawLines', window, allCoords,...
          lineWidthPix, [1 0 0], [xCenter yCenter], 2);
        Screen('Flip', window);
        WaitSecs (0.2);
      end
      
      % Present white fixation cross for some seconds to show that
      % trial is over
      %trig.beep(440, 0.2, 'rest');
      Screen('TextSize', window, 36);
      Screen('DrawLines', window, allCoords,...
        lineWidthPix, white, [xCenter yCenter], 2);
      Screen('Flip', window);
      WaitSecs(5);
      
      % Ask how many G's were presented
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
    %trig.digitalout(0, 'stop_rec'); % stops the recording of xsens
    Screen('TextSize',window,25);
    DrawFormattedText(window, 'End of the automaticity test for the foot stomping task. \n You can take a rest if needed. \n When ready: press any key to end this session.','center','center', white);
    vbl = Screen('Flip', window);
    save('letters_footautodual.mat', 'letters_footautodual'); % save the letters that were presented and the reported number of g's
    KbStrokeWait; %wait for response to terminate instructions
  end
end

%Show dual task performance in command window (finger tapping)
fprintf('Finger AutoDual \n')
for h = 1:N_trials
     if str2num(letters_handautodual(h).reported_G)==sum(strcmp(letters_handautodual(h).presented, 'G'))
      fprintf('T%d: G correct \n', h)
     else
      fprintf('T%d: G incorrect \n', h)
     end 
      %Show if the tempo was correct. ! reflect if you want to show
      %this, because we cannot show this result for the foot stomping
      margin=0.25; % margin of error: think about what is most convenient
      delay=mean(diff((presses_handautodual(h).secs))-1/1.50);
      fprintf('T%d: the tempo was off with on average %f seconds \n', h, delay);
      if (all(abs(diff(presses_handautodual(h).secs)-1/1.5)<margin))
        fprintf('T%d: tempo correct \n', h)
      else
        fprintf('T%d: tempo incorrect \n', h)  
      end
      if strcmp(presses_handautodual(h).key,sequenceautoprint)
          fprintf('T%d: seq correct \n', h)
      else
          fprintf('T%d: seq incorrect \n', h)
      end         
         
end

%Show dual task performance in command window (foot stomping)
fprintf('Foot AutoDual \n')
for g = 1:N_trials
      if str2num(letters_footautodual(g).reported_G)==sum(strcmp(letters_footautodual(g).presented, 'G'))
        fprintf('T%d: G correct \n', g)
      else
        fprintf('T%d: G incorrect \n', g)
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
% trig.pulseIR(3, 0.2); % stop trigger for the nirs recording
% delete(trig); 
% ses.stop();
% dairy off; 

%% HELPER FUNCTIONS
% function triglistener(src, event)
% for ii=1:numel(event.Data)
%   info=src.info;
%   fprintf('   lsl event (%s) received @ %s with (uncorrected) timestamp %.3f \n',  event.Data{ii}, info.type, event.Timestamps(ii));
% end
% end
% 
% function cleanupFun()
% delete(ses);
% delete(trigstr{1});
% delete(trigstr{2});
% delete(info);
% end
% 
