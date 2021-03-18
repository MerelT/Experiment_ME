% MATLAB SCRIPT FOR THE AUTOMATICITY TEST
% A dual-task paradigm in which we test whether a 12 digit prelearned
% sequence (sequenceauto) has become an automatic movement for a finger
% tapping and a foot stomping task.

%Before starting the automaticity test, clear the workspace.
clear all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% START ZMQ & LSL
% raspberry names
zmq_proxy='lsldert00.local';
lsl_hosts={'lsldert00', 'lsldert04', 'lsldert05'};

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
trig.pulseIR(3, 0.2); % start trigger for the nirs recording

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
[WAVMetronome600.wave,WAVMetronome600.fs]       = audioread('Metronome600.wav');
[WAVMetronome300.wave,WAVMetronome300.fs]       = audioread('Metronome300.wav');

% change rows<>columns
WAVMetronome8.wave = WAVMetronome8.wave';         WAVMetronome8.nrChan=2;
WAVMetronome600.wave = WAVMetronome600.wave';         WAVMetronome600.nrChan=2;
WAVMetronome300.wave = WAVMetronome300.wave';         WAVMetronome300.nrChan=2;

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
h_Metronome600   = PsychPortAudio('Open', [], [], priority, WAVMetronome600.fs, WAVMetronome600.nrChan);
h_Metronome300   = PsychPortAudio('Open', [], [], priority, WAVMetronome300.fs, WAVMetronome300.nrChan);

% Fill buffer
PsychPortAudio('FillBuffer', h_Metronome8, WAVMetronome8.wave);
PsychPortAudio('FillBuffer', h_Metronome600, WAVMetronome600.wave);
PsychPortAudio('FillBuffer', h_Metronome300, WAVMetronome300.wave);

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

logname=sprintf('%s_%s_triggers.log', sub, rec); diary(logname);
% save current script in subject directory
script=mfilename('fullpath');
script_name=mfilename;
copyfile(sprintf('%s.m', script), fullfile(sub_dir, sprintf('%s_%s.m', sub, script_name)))

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%SET UP PARAMETERS

%The sequences used for this study
sequenceA = '4 3 4 1 4 1 2 4 3 2 1 2';
sequenceB = '2 1 2 3 2 1 3 2 4 2 4 1';
sequenceprintA = {'Return', '3', 'Return', '1' ,'Return' '1', '2','Return', '3','2','1','2'};
sequenceprintB= {'2','1','2', '3','2','1','3', '2', 'Return', '2', 'Return','1' };

%Parameters for the resting period in between the trials
t1 = 20; %Resting period in seconds
t2 = 5;  %Random interval around the resting period time
t3 = 9.5; %Duration of a trial (tapping/stomping the sequence 1 time)

%Amount of letters presented during test for automaticity for one trial.
%Should be adjusted when letter presenting speed is changed!
N_letters=8; % 8 letters presented during a trial
N_trials=11; % number of trials performed for each limb

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RANDOMIZATION

% Change for each participant, randomize the sequences for auto and
% non-auto
sequenceauto = sequenceA;
sequencenonauto = sequenceB;
sequenceautoprint = sequenceprintA;
sequencenonautoprint = sequenceprintB;

%Create a vector to represent the two different options (1=finger tapping
%test, 2= foot stomping test).
order_autodual=[1,2];
%Save the order of the automaticity test experiment
save('order_autodual.mat', 'order_autodual');

%Create a vector to represent the two different options (1=non-automatic
%test, 2=automatic test).
order_experiment=[1,2];
%Save the order of the experiment
save('order_experiment.mat', 'order_experiment');

%Create a vector to represent the two different options for non-automatic
%tasks (3 = finger tapping, 4 = foot stomping).
order_nonauto=[3,4];
%Save the order of the non-automatic experiment
save('order_nonauto.mat', 'order_nonauto');

%Create a vector to represent the two different options for automatic tasks
%(5 = finger tapping, 6 = foot stomping).
order_auto=[5,6];
%Save the order of the automatic experiment
save('order_auto.mat', 'order_auto');
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
events_handautodual=struct([]); % same for the presented letters of the hand + the answer
events_footautodual=struct([]); % same for the presented letters of the foot + the answer

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
    trig.beep(440, 0.2, 'instructions');
    Screen('TextSize',window,25);
    DrawFormattedText(window, sprintf('You will now perform the pre-learned sequence for the FINGER tapping task: \n %s \n\n  While you perform the task, letters will be shown on the screen (A,G,O,L). \n The goal is to perform the sequence tapping while counting how many times G is presented. \n After each time you tapped the full sequence, you should tell us how many times G was presented. \n For answering this question, \n keep in mind that when the answer is 4 you press 4 and not Return (Enter) on the keyboard. \n\n We will perform 11 trails. \n Note that during the tapping task you cannot talk. \n Try to keep your body movements as still as possible exept for the right hand. \n Keep your eyes open (also during the rest periods). \n\n In between the trials you will see a fixation cross for 20 seconds. \n During the first few seconds you will hear a metronome sound. \n Tap the sequence on this rhythm, which is the same as you studied at home. \n\n We will start with a fixation cross on the screen for 20 seconds. \n After that the first trial will start automatically. \n So start tapping the sequence as soon as a letter on the screen appears. \n When ready: press any key to continue and start the test.', sequenceauto),'center','center', white);
    vbl = Screen('Flip', window);
    KbStrokeWait; %wait for response to terminate instructions

    for j=1:N_trials
      %Presentation of the letters on the screen (dual task). -> is random.
      %Participant has to count the amount that G was presented.
      Letterlist='AGOL';
      letter_order=randi(length(Letterlist), 1, N_letters);
      value={Letterlist(letter_order)};
      

      % Always start with a 20-25 seconds fixation cross with 8 seconds of metronome
      % sound
      trig.beep(440, 0.2, 'rest');
      Screen('TextSize', window, 36);
      Screen('DrawLines', window, allCoords,...
        lineWidthPix, white, [xCenter yCenter], 2);
      Screen('Flip', window);
      PsychPortAudio('Start', h_Metronome8, 1, [], []); % Play metronome sound file (8 seconds)
      WaitSecs(t1+randi(t2))

      %Presentation of random letters on the screen during the finger
      %tapping test + recording of the key presses
      trig.beep(440, 0.2, 'finger_auto_dual');
      onset=GetSecs;
      % preallocate table with key presses
      keypresses=table('Size', [12, 3], 'VariableNames', {'onset', 'duration', 'value'}, 'VariableTypes', {'double', 'double', 'cell'});
      m=1; % first key press
      %           FlushEvents('keyDown'); % option A: clear all previous key presses from the list
      KbQueueFlush; % option B: clear all previous key presses from the list
      for n=1:N_letters
        % Present random letter
        Screen('TextSize', window, 100);
        DrawFormattedText(window, value{1}(n),'center','center', white);
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
              if length(idx)>1
                keys=keys(idx); % sort the pressed keys in ascending order
              else
                keys={keys};
              end
              key_n=length(keys); % number of pressed keys
              keypresses.onset(m:m+key_n-1)=timing';
              keypresses.value(m:m+key_n-1)=keys;
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
      duration=GetSecs-onset;
      trig.beep(440, 0.2, 'rest');
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
      % save the response and the key presses
      response={KbName(find(keyCode))};
      events_handautodual(j).stimuli=table(onset,duration, value, response);
      events_handautodual(j).responses=keypresses;
      DrawFormattedText(window, ['Your answer: ' response{1} '\n Press any key to continue.'],'center','center', white);
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
    save('events_handautodual.mat', 'events_handautodual'); % save the events
    KbStrokeWait; %wait for response to terminate instructions


    % Foot stomping test -> 11 trials, presents letters upon randomized speed
  elseif i==2
    % Instruction automaticity task foot stomping
    trig.beep(440, 0.2, 'instructions');
    Screen('TextSize',window,25);
    DrawFormattedText(window, sprintf('You will now perform the pre-learned sequence for the FOOT stomping task: \n %s \n\n While you perform the task, letters will be shown on the screen (A,G,O,L). \n The goal is to perform the sequence stomping while counting how many times G is presented. \n After each time you stomped the full sequence, you should tell us how many times G was presented. \n For answering this question, \n keep in mind that when the answer is 4 you press 4 and not Return (Enter) on the keyboard. \n\n We will perform 11 trials. \n Note that during the stomping task you cannot talk. \n Try to keep your body movements as still as possible exept for your right leg. \n Keep your eyes open (also during the rest periods). \n\n In between the trials you will see a fixation cross for 20 seconds. \n During the first few seconds you will hear a metronome sound. \n Stomp the sequence on this rhythm, which is the same as you studied at home. \n\n We will start with a fixation cross on the screen for 20 seconds. \n After that the first trial will start automatically. \n So start stomping the sequence as soon as a letter on the screen appears. \n When ready: press any key to continue and start the test.', sequenceauto),'center','center', white);
    vbl = Screen('Flip', window);
    KbStrokeWait; %wait for response to terminate instructions

    trig.digitalout(1, 'start_rec'); % starts the recording of xsens
    for j=1:N_trials
      %Presentation of the letters on the screen (dual task). -> is random.
      %Participant has to count the amount that G was presented.
      Letterlist= 'AGOL';
      letter_order=randi(length(Letterlist), 1, N_letters);
      value={Letterlist(letter_order)};
      

      % Always start with a fixation cross and 8 seconds of metronome
      % sound
      trig.beep(440, 0.2, 'rest');
      Screen('TextSize', window, 36);
      Screen('DrawLines', window, allCoords,...
        lineWidthPix, white, [xCenter yCenter], 2);
      Screen('Flip', window);
      PsychPortAudio('Start', h_Metronome8, 1, [], []); % Play metronome sound file (8 seconds)
      WaitSecs(t1+randi(t2))

      %Presentation of random letters on the screen during the foot
      %stomping test
      trig.beep(880, 0.2, 'foot_auto_dual');
      onset=GetSecs;
      for n=1:N_letters
        % present random letter
        Screen('TextSize', window, 100);
        DrawFormattedText(window, value{1}(n),'center','center', white);
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
      duration=GetSecs-onset;
      trig.beep(440, 0.2, 'rest');
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
      % save the response and the key presses
      response={KbName(find(keyCode))};
      events_footautodual(j).stimuli=table(onset,duration, value, response);
      DrawFormattedText(window, ['Your answer: ' response{1} '\n Press any key to continue.'],'center','center', white);
      vbl = Screen('Flip', window);
      KbStrokeWait; %wait for response to terminate instruction
      DrawFormattedText(window, 'Press any key to continue with the next trail. \n Note that you will first start with a fixation cross again. \n Start tapping the sequence as soon as a letter on the screen appears.' ,'center','center', white);
      vbl = Screen('Flip', window);
      KbStrokeWait;
    end

    % After all trials completed, the end of the foot stomping task is reached.
    trig.digitalout(0, 'stop_rec'); % stops the recording of xsens
    Screen('TextSize',window,25);
    DrawFormattedText(window, 'End of the automaticity test for the foot stomping task. \n You can take a rest if needed. \n When ready: press any key to end this session.','center','center', white);
    vbl = Screen('Flip', window);
    save('events_footautodual.mat', 'events_footautodual'); % save the letters that were presented and the reported number of g's
    KbStrokeWait; %wait for response to terminate instructions
  end
end

%Show dual task performance in command window (finger tapping)
fprintf('Finger AutoDual \n')
for h = 1:N_trials
     fprintf('Trial %d: \n', h)
     if str2num(events_handautodual(h).stimuli.response{1})==length(strfind(events_handautodual(h).stimuli.value{1}, 'G'))
      fprintf('G correct \n')
     else
      fprintf('G incorrect \n')
     end
      %Show if the tempo was correct. ! reflect if you want to show
      %this, because we cannot show this result for the foot stomping
      margin=0.25; % margin of error: think about what is most convenient
      delay=mean(diff(events_handautodual(h).responses.onset)-1/1.50);
      fprintf('the tempo was off with on average %f seconds \n', delay);
%       if (all(abs(diff(events_handautodual(h).responses.onset)-1/1.5)<margin))
%         fprintf('T%d: tempo correct \n', h)
%       else
%         fprintf('T%d: tempo incorrect \n', h)
%       end
      if all(strcmp(events_handautodual(h).responses.value,sequenceautoprint'))
          fprintf('Seq correct \n')
      else
          fprintf('Seq incorrect \n')
      end

end

%Show dual task performance in command window (foot stomping)
fprintf('Foot AutoDual \n')
for g = 1:N_trials
    fprintf('Trial %d: \n', g)
     if str2num(events_footautodual(g).stimuli.response{1})==length(strfind(events_footautodual(g).stimuli.value{1}, 'G'))
        fprintf('G correct \n')
      else
        fprintf('G incorrect \n')
      end
end

% End of automaticity test is reached (both limbs are tested)
Screen('TextSize',window,25);
DrawFormattedText(window,'You have completed the automaticity test. \n We will continue with the rest of the experiment. \n Press any key to end this session.','center', 'center', white);
vbl = Screen('Flip', window);
%Press key to end the session and return to the 'normal' screen.
KbStrokeWait; %wait for response to terminate instructions
sca

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% START OF THE EXPERIMENT

%Empty structure for key presses -> use later again so it saves the key
%presses within this structure -> save at the end
events_handauto=struct([]); 
events_footauto=struct([]); 
events_handnonauto=struct([]); 
events_footnonauto=struct([]); 
events_handnonautodual=struct([]); 
events_footnonautodual=struct([]); 

%Instruction experiment
%trig.beep(440, 0.2, 'instructions');
Screen('TextSize',window,25);
DrawFormattedText(window,'You will now start with the experiment. \n You will either start with the automatic tasks, performing the at home studied sequence, \n or with the non-automatic tasks, for which you will be presented with a new sequence, \n which you can study for 5 minutes for each limb. \n Note that for the non-automatic tasks you will also perform an automaticity test (dual task). \n This is the same test as you just did for the automatic (at home studied) sequence. \n\n Detailed instructions will appear at the start of each new task. \n You can take a break in between tasks. \n This will be indicated in the on-screen instructions. \n\n Press any key to continue and see with which test you start.','center', 'center', white);
vbl = Screen('Flip', window);
KbStrokeWait; %wait for response to terminate instructions

%Start the randomization loop between non-automatic (=1) and automatic (=2)
for i=order_experiment; %Either [1,2] or [2,1] -> determines the order of the tasks
    
    % NON-AUTOMATICITY TASKS
    if i==1; %Start with the non-automatic tasks        
        % Show instructions
        Screen('TextSize', window, 25);
        DrawFormattedText(window, 'NON-AUTOMATICITY TASK \n\n You will perform the finger tapping and foot stomping task for a new sequence. \n You will either start with the finger tapping or the foot stomping task. \n You will get 5 minutes practice time before each task starts. \n Press any key to continue.', 'center', 'center', white);
        vbl= Screen('Flip', window);
        KbStrokeWait; %wait for response to terminate instructions
        
        %Determine to start with either hand or foot task.
        for j=order_nonauto %Either [3,4] or [4,3] -> determines the order of the limbs
            %trig.beep(440, 0.2, 'instructions');
            
            % NON-AUTOMATIC FINGER TAPPING TASK
            if j==3
                
                %Non automatic finger tapping task instructions
                %Practice new sequence
                %trig.beep(440, 0.2, 'practice_finger_nonauto');
                Screen('TextSize', window, 25);
                DrawFormattedText(window, 'You will now perform the non-automaticity FINGER tapping task. \n For the next 5 minutes you can practice a new sequence for the finger tapping task, \n the same way you practiced at home. \n After that we will start with the finger tapping task. \n Press any key to see the new sequence and start practicing.', 'center', 'center', white);
                vbl= Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                
                %Presenting the new (non-automatic) sequence on the screen
                Screen('TextSize', window, 50);
                DrawFormattedText(window, sprintf('%s', sequencenonauto), 'center', 'center', white); % is this the same for each participant?
                vbl= Screen('Flip', window);
                %PsychPortAudio('Start', h_Metronome300, 1, [], []); %Play metronome sound file (5 minutes)
                WaitSecs(3);
                
                Screen('TextSize', window, 25);
                DrawFormattedText(window, 'The time to practice the new sequence is over. \n Press any key to continue to the finger tapping experiment.', 'center', 'center', white);
                vbl= Screen('Flip', window);
                WaitSecs(5)
                KbStrokeWait; %wait for response to terminate instructions
                
                %Instructions non-automatic finger tapping task
                Screen('TextSize',window,25);
                DrawFormattedText(window, sprintf('You will now perform the finger tapping task for the sequence you just practiced (non-automatic). \n There is a total of 11 trials, so performing the sequence 11 times. \n  In between each trial there is a rest period of 20 seconds. \n During this rest you will hear a metronome sound, tap the sequence according to this interval sound. \n Trials and rest periods are indicated with red(= trial) and white(= rest) fixation crosses showing on the screen. \n\n When the experiment starts you cannot talk anymore. \n Furthermore, it is important to stay still except for your right hand. \n Keep your eyes open (also during the rest periods). \n\n Before the start of each new trial the sequence will be shown on the screen. \n If you press any key, the experiment starts. \n It will start with a rest period. \n Whenever a RED fixation cross appears on the screen, you should start tapping the sequence: \n %s \n When ready: press any key to start the finger tapping experiment.', sequencenonauto),'center','center', white);
                vbl = Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                
                %Stimulus for finger tapping non-automatic sequence
                for l = 1:N_trials %Will perform 11 trials
                    keypresses=table('Size', [12, 3], 'VariableNames', {'onset', 'duration', 'value'}, 'VariableTypes', {'double', 'double', 'cell'});
                    %Rest period between each sequence 20-25 seconds
                    %trig.beep(440, 0.2, 'rest');
                    % Fixation cross during rest
                    Screen('TextSize', window, 36);        
                    Screen('DrawLines', window, allCoords,...
                        lineWidthPix, white, [xCenter yCenter], 2);
                    Screen('Flip', window);
                    PsychPortAudio('Start', h_Metronome8, 1, [], []); % Play metronome sound file (8 seconds)
                    WaitSecs(t1+randi(t2));
                    
                    %Red fixation cross during finger tapping trial
                    %trig.beep(440, 0.2, 'finger_nonauto');
                    onset=GetSecs;
                    Screen('TextSize', window, 36);
                    Screen('DrawLines', window, allCoords,...
                        lineWidthPix, [1 0 0], [xCenter yCenter], 2);
                    Screen('Flip', window)
                    m=1;
                    
                    % Record key presses
                    start_timer=GetSecs;
                    while GetSecs-start_timer < t3
                        if m<13
                            [secs, keyCode, deltaSecs] = KbWait([],2);
                            if any(keyCode)
                                key={KbName(find(keyCode))};
                                keypresses.onset(m)=secs;
                                keypresses.value(m)=key;
                                m=m+1;
                            elseif KbName('ESCAPE')
                            elseif GetSecs-start_timer >= t3
                                break
                            end
                        end
                    end
                
                
                % Short white fix cross after trial
                duration=GetSecs-onset;
                %trig.beep(440, 0.2, 'rest');
                Screen('TextSize', window, 36);
                Screen('DrawLines', window, allCoords,...
                        lineWidthPix, white, [xCenter yCenter], 2);
                Screen('Flip', window)
                WaitSecs (5)    
                
                % Show sequence before new trial starts
                Screen('TextSize', window, 25);
                DrawFormattedText(window, sprintf('%s \n Press any key to continue with the next trial.', sequencenonauto), 'center', 'center', white);
                vbl= Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                
                % save the response and the key presses
                value={'red X'};
                events_handnonauto(l).stimuli=table(onset,duration, value);
                events_handnonauto(l).responses=keypresses;
                
                end
                 
                % End of the non-automatic finger tapping task is reached.
                Screen('TextSize', window, 25);
                DrawFormattedText(window, 'This is the end of the non-automatic finger tapping task. \n Take a rest if needed. \n When ready: press any key to continue with the automaticity test for this task.', 'center', 'center', white);
                vbl= Screen('Flip', window);
                save('events_handnonauto.mat', 'events_handnonauto'); % save the events
                KbStrokeWait; %wait for response to terminate instructions
                
                %Instruction automaticity task finger tapping
                %trig.beep(440, 0.2, 'instructions');
                Screen('TextSize',window,25);
                DrawFormattedText(window, sprintf('You will now perform the sequence you just learned during an automaticity test for the FINGER tapping task. \n %s \n\n  While you perform the task, letters will be shown on the screen (A,G,O,L). \n The goal is to perform the sequence tapping while counting how many times G is presented. \n After each time you tapped the full sequence, you should tell us how many times G was presented. \n For answering this question, \n keep in mind that when the answer is 4 you press 4 and not Return (Enter) on the keyboard. \n\n We will perform 11 trails. \n Note that during the tapping task you cannot talk. \n Try to keep your body movements as still as possible exept for the right hand. \n Keep your eyes open (also during the rest periods). \n\n In between the trials you will see a white fixation cross for 20 seconds. \n During the first few seconds you will hear a metronome sound. \n Tap the sequence on this rhythm, which is the same as you practiced before. \n \n We will start with a fixation cross on the screen for 20 seconds. \n After that the first trial will start automatically. \n So start tapping the sequence as soon as a letter on the screen appears. \n When ready: press any key to continue and start the test.', sequencenonauto),'center','center', white);
                vbl = Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                
                for r=1:N_trials
                    %Presentation of the letters on the screen (dual task). -> is random.
                    %Participant has to count the amount that G was presented.
                    Letterlist='AGOL';
                    letter_order=randi(length(Letterlist), 1, N_letters);
                    value={Letterlist(letter_order)};
                    
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
                    %trig.beep(440, 0.2, 'finger_nonauto_dual');
                    onset=GetSecs;
                    % preallocate table with key presses
                    keypresses=table('Size', [12, 3], 'VariableNames', {'onset', 'duration', 'value'}, 'VariableTypes', {'double', 'double', 'cell'});
                    v=1; % first key press
                    %FlushEvents('keyDown'); % option A: clear all previous key presses from the list
                    KbQueueFlush; % option B: clear all previous key presses from the list
                    for w=1:N_letters
                         % Present random letter
                    Screen('TextSize', window, 100);
                    DrawFormattedText(window, value{1}(w),'center','center', white);
                    vbl = Screen('Flip', window);
                    time_letter=rand(1)+0.5; %Speed with which the letters are presented = A randomized value between 0 and 1, + 0.5 sec
                        
        % Record key presses
        start_timer=GetSecs;
        while GetSecs-start_timer<time_letter
          [ pressed, firstPress, ~, lastPress, ~]=KbQueueCheck; % option B
          if pressed
            if isempty(find(firstPress~=lastPress)) % no key was pressed twice
              keys=KbName(find(firstPress)); % find the pressed keys
              [timing, idx]=sort(firstPress(find(firstPress))); % get timing of key presses in ascending order
              if length(idx)>1
                keys=keys(idx); % sort the pressed keys in ascending order
              else
                keys={keys};
              end
              key_n=length(keys); % number of pressed keys
              keypresses.onset(v:v+key_n-1)=timing';
              keypresses.value(v:v+key_n-1)=keys;
              v=v+key_n;
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
                    duration=GetSecs-onset;
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
      % save the response and the key presses
      response={KbName(find(keyCode))};
      events_handnonautodual(r).stimuli=table(onset,duration, value, response);
      events_handnonautodual(r).responses=keypresses;
      DrawFormattedText(window, ['Your answer: ' response{1} '\n Press any key to continue.'],'center','center', white);
      vbl = Screen('Flip', window);
      KbStrokeWait; %wait for response to terminate instruction
      DrawFormattedText(window, 'Press any key to continue with the next trail. \n Note that you will first start with a fixation cross again. \n Start tapping the sequence as soon as a letter on the screen appears.' ,'center','center', white);
      vbl = Screen('Flip', window);
      KbStrokeWait;
                end
                
                % After all trials completed, the end of the finger tapping task is
                % reached.
                Screen('TextSize',window,30);
                DrawFormattedText(window, 'This is the end of the automaticity test for the non-automatic finger tapping task. \n You can take a rest if needed. \n Whenever you feel ready, \n press any key to continue with the experiment.' ,'center','center', white);
                vbl = Screen('Flip', window);
                save('events_handnonautodual.mat', 'events_handnonautodual'); % save the events
                KbStrokeWait; %wait for response to terminate instructions
                
            end
                
            %NON-AUTOMATIC FOOT STOMPING TASK
            if j==4;
               
                %Non automatic foot stomping task instructions
                %Practice new sequence
                %trig.beep(440, 0.2, 'practice_foot_nonauto');
                Screen('TextSize', window, 25);
                DrawFormattedText(window, 'You will now perform the non-automaticity FOOT stomping task. \n For the next 5 minutes you can practice the new sequence for the foot stomping task. \n After that the experiment for the foot stomping task will start. \n\n\n Press any key to see the new sequence and start practicing.', 'center', 'center', white);
                vbl= Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                
                % Presenting the new (non-automatic) sequence on the screen
                Screen('TextSize', window, 50);
                DrawFormattedText(window, sprintf('%s', sequencenonauto), 'center', 'center', white); % is this the same for each participant?
                vbl= Screen('Flip', window);
                %PsychPortAudio('Start', h_Metronome300, 1, [], []); % Play metronome sound file
                WaitSecs(3);
                
                Screen('TextSize', window, 25);
                DrawFormattedText(window, 'The time to practice the new sequence is over. \n Press any key to continue to the foot stomping experiment.', 'center', 'center', white);
                vbl= Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                
                %Instructions non-automatic foot stomping task
                %trig.beep(440, 0.2, 'instructions');
                Screen('TextSize',window,25);
                DrawFormattedText(window, sprintf('You will now perform the foot stomping experiment for the sequence you just practiced (non-automatic). \n There is a total of 11 trials, so performing the sequence 11 times. \n In between each trial there is a rest period of 20 seconds. \n During this rest you will hear a metronome sound, stomp the sequence according to this interval sound. \n Trials and rest periods are indicated with red(= trial) and white(=rest) fixation crosses presented on the screen. \n\n When the experiment starts you cannot talk anymore. \n Furthermore, it is important to stay still except for your right leg. \n Keep your eyes open (also during the rest periods). \n\n Before the start of each new trial the sequence will be shown on the screen. \n If you press any key, the experiment starts right away. \n It will start with a rest period. \n Whenever a RED fixation cross appears on the screen, you should start stomping the sequence: \n %s \n When ready: press any key to start the foot stomping experiment.', sequencenonauto),'center', 'center', white);
                vbl = Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                
                %trig.digitalout(1, 'start_rec'); % starts the recording of xsens
                %Stimulus for foot stomping non-automatic sequence
                for n = 1:N_trials %Will perform 11 trials
                    
                    % Rest period 20-25 seconds
                    %trig.beep(440, 0.2, 'rest');
                    Screen('TextSize', window, 36);
                    Screen('DrawLines', window, allCoords,...
                        lineWidthPix, white, [xCenter yCenter], 2);
                    Screen('Flip', window);
                    PsychPortAudio('Start', h_Metronome8, 1, [], []); % Play metronome sound file (8 seconds)
                    WaitSecs(t1+randi(t2))
                    
                    % Red fixation cross during trial
                    %trig.beep(880, 0.2, 'foot_nonauto');
                    onset=GetSecs;
                    Screen('TextSize', window, 36);
                    Screen('DrawLines', window, allCoords,...
                        lineWidthPix, [1 0 0], [xCenter yCenter], 2);
                    %draw on screen
                    Screen('Flip', window)
                    WaitSecs(t3)
                    
                     % Short white fix cross after trial
                     %trig.beep(440, 0.2, 'rest');
                     duration=GetSecs-onset
                Screen('TextSize', window, 36);
                Screen('DrawLines', window, allCoords,...
                        lineWidthPix, white, [xCenter yCenter], 2);
                Screen('Flip', window)
                WaitSecs (5)    
                
                % Show sequence before new trial starts
                Screen('TextSize', window, 25);
                DrawFormattedText(window, sprintf('%s \n Press any key to continue with the next trial.', sequencenonauto), 'center', 'center', white);
                vbl= Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                 
                value={'red X'};
                events_footnonauto(n).stimuli=table(onset,duration, value);
                
                end
                
                % End of the non-automatic foot stomping task
                %trig.beep(440, 0.2, 'rest');
                Screen('TextSize', window, 25);
                DrawFormattedText(window, 'This is the end of the non-automatic foot stomping task. \n Take a rest if needed. \n When ready: press any key to continue with the automaticity test.', 'center', 'center', white);
                vbl= Screen('Flip', window);
                save('events_footnonauto.mat', 'events_footnonauto'); % save the events
                KbStrokeWait; %wait for response to terminate instructions
                %trig.digitalout(0, 'stop_rec'); % stops the recording of xsens
                
                
                % Instruction automaticity task foot stomping
                %trig.beep(440, 0.2, 'instructions');
                Screen('TextSize',window,25);
                DrawFormattedText(window, sprintf('You will now perform the sequence you just learned for an automaticity test for the FOOT stomping task. \n %s \n\n While you perform the task, letters will be shown on the screen (A,G,O,L). \n The goal is to perform the sequence stomping while counting how many times G is presented. \n After each time you stomped the full sequence, you should tell us how many times G was presented. \n For answering this question, \n keep in mind that when the answer is 4 you press 4 and not Return (Enter) on the keyboard \n\n We will perform 11 trials. \n Note that during the stomping task you cannot talk. \n Try to keep your body movements as still as possible exept for your right leg. \n Keep your eyes open (also during the rest periods). \n\n In between the trials you will see a fixation cross for 20 seconds. \n During the first few seconds you will hear a metronome sound. \n Stomp the sequence on this rhythm, which is the same as you studied at home. \n\n We will start with a fixation cross on the screen for 20 seconds. \n After that the first trial will start automatically. \n So start stomping the sequence as soon as a letter on the screen appears. \n When ready: press any key to continue and start the test.', sequencenonauto),'center','center', white);
                vbl = Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                
                %trig.digitalout(1, 'start_rec'); % starts the recording of xsens
                for r=1:N_trials
                    %Presentation of the letters on the screen (dual task). -> is random.
                    %Participant has to count the amount that G was presented.
                   Letterlist= 'AGOL';
                    letter_order=randi(length(Letterlist), 1, N_letters);
                    value={Letterlist(letter_order)};
                    
                    % Always start with a fixation cross and 5 seconds of metronome
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
                    %trig.beep(880, 0.2, 'foot_nonauto_dual');
                    onset=GetSecs;
                    for w=1:N_letters
                        % present random letter
                        Screen('TextSize', window, 100);
                        DrawFormattedText(window, value{1}(w),'center','center', white);
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
                    duration=GetSecs-onset;
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
      % save the response and the key presses
      response={KbName(find(keyCode))};
      events_footnonautodual(r).stimuli=table(onset,duration, value, response);
      DrawFormattedText(window, ['Your answer: ' response{1} '\n Press any key to continue.'],'center','center', white);
      vbl = Screen('Flip', window);
      KbStrokeWait; %wait for response to terminate instruction
      DrawFormattedText(window, 'Press any key to continue with the next trail. \n Note that you will first start with a fixation cross again. \n Start tapping the sequence as soon as a letter on the screen appears.' ,'center','center', white);
      vbl = Screen('Flip', window);
      KbStrokeWait;
      
                end
                
                % After all trials completed, the end of the foot stomping task is reached.
                %trig.digitalout(0, 'stop_rec'); % stops the recording of xsens
                Screen('TextSize',window,25);
                DrawFormattedText(window, 'End of the automaticity test for the non-automatic foot stomping task. \n You can take a rest if needed. \n Whenever you feel ready, \n press any key to continue with the experiment.','center','center', white);
                vbl = Screen('Flip', window);
                save('events_footnonautodual.mat', 'events_footnonautodual'); % save the letters that were presented and the reported number of g's
                KbStrokeWait; %wait for response to terminate instructions
            end
        end
    end
    
    
    
    % AUTOMATICITY TASKS
    if i==2; %Start with the automatic tasks
        
        % Show instructions
        %trig.beep(440, 0.2, 'instructions');
        Screen('TextSize', window, 25);
        DrawFormattedText(window, 'AUTOMATICITY TASK \n\n You will perform the finger tapping and foot stomping task for the sequence you studied at home. \n You will either start with the finger tapping or foot stomping task. \n Press any key to continue.', 'center', 'center', white);
        vbl= Screen('Flip', window);
        KbStrokeWait; %wait for response to terminate instructions
        
        %Determine to start with either hand or foot task.
        for k=order_auto; %Either [5,6] or [6,5] -> determines the order of the limbs
            
            % Automatic finger tapping experiment
            if k==5;
                %Automatic finger tapping task instructions
                Screen('TextSize',window,25);
                DrawFormattedText(window, sprintf('You will now perform the FINGER tapping task for the sequence you studied at home (automatic). \n %s \n\n There is a total of 11 trials, so performing the sequence 11 times. \n  In between each trial there is a rest period of 20 seconds. \n During this rest you will hear a metronome sound, tap the sequence according to this interval sound. \n Trials and rest periods are indicated with red(= trial) and white(= rest) fixation crosses presented on the screen. \n\n When the experiment starts you cannot talk anymore. \n Furthermore, it is important to stay still except for your right hand. \n Keep your eyes open (also during the rest periods). \n\n Before the start of each new trial the sequence will be shown on the screen. \n If you press any key, the experiment starts right away. \n It will start with a rest period. \n Whenever a RED fixation cross appears on the screen, you should start tapping the sequence. \n When ready: press any key to start the finger tapping experiment.', sequenceauto),'center','center', white);
                vbl = Screen('Flip', window);
                KbStrokeWait;
                
                %Stimulus for finger tapping automatic sequence
                for o = 1:N_trials % Will perform 11 trials
                    keypresses=table('Size', [12, 3], 'VariableNames', {'onset', 'duration', 'value'}, 'VariableTypes', {'double', 'double', 'cell'});
                    %Rest period 20-25 seconds
                    %trig.beep(440, 0.2, 'rest');
                    Screen('TextSize', window, 36);
                    Screen('DrawLines', window, allCoords,...
                        lineWidthPix, white, [xCenter yCenter], 2);
                    Screen('Flip', window);
                    PsychPortAudio('Start', h_Metronome8, 1, [], []); % Play metronome sound file
                    WaitSecs(t1+randi(t2))
                    
                    % Red fixation cross during trial
                    %trig.beep(440, 0.2, 'finger_auto');
                    onset=GetSecs;
                    Screen('TextSize', window, 36);
                    Screen('DrawLines', window, allCoords,...
                        lineWidthPix, [1 0 0], [xCenter yCenter], 2);
                    %draw on screen
                    Screen('Flip', window)
                    p=1;
                    
                    % Record key presses
                    start_timer=GetSecs;
                    while GetSecs-start_timer < t3
                        if p<13
                            [secs, keyCode, deltaSecs] = KbWait([],2);
                            if any(keyCode)
                                key={KbName(find(keyCode))};
                                keypresses.onset(p)=secs;
                                keypresses.value(p)=key;
                                p=p+1;
                            elseif KbName('ESCAPE')
                            elseif GetSecs-start_timer >= t3
                                break
                            end
                        end
                    end
                
                     % Short white fix cross after trial
                %trig.beep(440, 0.2, 'rest');
                duration=GetSecs-onset
                Screen('TextSize', window, 36);
                Screen('DrawLines', window, allCoords,...
                        lineWidthPix, white, [xCenter yCenter], 2);
                Screen('Flip', window)
                WaitSecs (5)    
                
                % Show sequence before new trial starts
                Screen('TextSize', window, 25);
                DrawFormattedText(window, sprintf('%s \n Press any key to continue with the next trial.', sequenceauto), 'center', 'center', white);
                vbl= Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                 
                % save the response and the key presses
                value={'red X'};
                events_handauto(o).stimuli=table(onset,duration, value);
                events_handauto(o).responses=keypresses;
                
                end
                
                %End of the automatic finger tapping task
                %trig.beep(440, 0.2, 'rest');
                Screen('TextSize', window, 25);
                DrawFormattedText(window, 'This is the end of the automatic finger tapping task. \n You can take a rest if needed. \n Whenever you feel ready, \n press any key to continue with the rest of the experiment.', 'center', 'center', white);
                save('events_handauto.mat', 'events_handauto'); % save the events
                vbl= Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                
            end
            
            
            % Automatic foot stomping task
            if k==6;                
                % Automatic foot stomping instructions
                %trig.beep(440, 0.2, 'instructions');
                Screen('TextSize',window,25);
                DrawFormattedText(window, sprintf('You will now perform the FOOT stomping experiment for the sequence you studied at home (automatic). \n %s \n\n There is a total of 11 trials, so performing the sequence 11 times. \n In between each trial there is a rest period of 20 seconds. \n During this rest you will hear a metronome sound, stomp the sequence according to this interval sound. \n Trials and rest periods are indicated with red(= trial) and white(= rest)fixation crosses presented on the screen. \n\n When the experiment starts you cannot talk anymore. \n Furthermore, it is important to stay still except for your right leg. \n Keep your eyes open (also during the rest periods). \n\n Before the start of each new trial the sequence will be shown on the screen. \n If you press any key, the experiment starts right away. \n It will start with a rest period. \n Whenever a RED fixation cross appears on the screen, you should start stomping the sequence. \n When ready: press any key to start the foot stomping experiment.', sequenceauto), 'center', 'center', white);
                vbl = Screen('Flip', window);
                KbStrokeWait;
                
                %trig.digitalout(1, 'start_rec'); % starts the recording of xsens
                %Stimulus for foot stomping automatic sequence
                for q = 1:N_trials % Will perform 11 trials
                    
                    % Rest period 20-25 seconds
                    %trig.beep(440, 0.2, 'rest');
                    %fixation cross
                    Screen('TextSize', window, 36);
                    Screen('DrawLines', window, allCoords,...
                        lineWidthPix, white, [xCenter yCenter], 2);
                    Screen('Flip', window);
                    PsychPortAudio('Start', h_Metronome8, 1, [], []); % Play metronome sound file
                    WaitSecs(t1+randi(t2))
                    
                    %Red fixation cross during trial
                    %trig.beep(880, 0.2, 'foot_auto');
                    onset=GetSecs;
                    Screen('TextSize', window, 36);
                    Screen('DrawLines', window, allCoords,...
                        lineWidthPix, [1 0 0], [xCenter yCenter], 2);
                    Screen('Flip', window)
                    WaitSecs (t3)
                    
                     % Short white fix cross after trial
                %trig.beep(440, 0.2, 'rest');
                duration=GetSecs-onset
                Screen('TextSize', window, 36);
                Screen('DrawLines', window, allCoords,...
                        lineWidthPix, white, [xCenter yCenter], 2);
                Screen('Flip', window)
                WaitSecs (5)    
                
                % Show sequence before new trial starts
                Screen('TextSize', window, 25);
                DrawFormattedText(window, sprintf('%s \n Press any key to continue with the next trial.', sequenceauto), 'center', 'center', white);
                vbl= Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                    
                value={'red X'};
                events_footauto(q).stimuli=table(onset,duration, value);
                
                end
                                
                % End of the automatic foot stomping task.
                %trig.beep(440, 0.2, 'rest');
                Screen('TextSize', window, 25);
                DrawFormattedText(window, 'This is the end of the automatic foot stomping task. \n You can take a rest if needed. \n Whenever you are ready, \n press any key to continue with the rest of the experiment.', 'center', 'center', white);
                save('events_footauto.mat', 'events_footauto'); % save the events
                vbl= Screen('Flip', window);
                KbStrokeWait; %wait for response to terminate instructions
                %trig.digitalout(0, 'stop_rec'); % stops the recording of xsens
            end
        end
    end
    
end

%Show dual task performance (non-automatic sequence) of finger tapping task in command window
fprintf('Finger NonAutoDual \n')
for h = 1:N_trials
      fprintf('Trial %d: \n', h)
     if str2num(events_handnonautodual(h).stimuli.response{1})==length(strfind(events_handnonautodual(h).stimuli.value{1}, 'G'))
      fprintf('G correct \n')
     else
      fprintf('G incorrect \n')
     end 
      %Show if the tempo was correct. ! reflect if you want to show
      %this, because we cannot show this result for the foot stomping
      margin=0.25; % margin of error: think about what is most convenient
      delay=mean(diff(events_handnonautodual(h).responses.onset)-1/1.50);
      fprintf('the tempo was off with on average %f seconds \n', delay);
%       if (all(abs(diff(presses_handnonautodual(h).secs)-1/1.5)<margin))
%         fprintf('T%d: tempo correct \n', h)
%       else
%         fprintf('T%d: tempo incorrect \n', h)  
%       end
      if all(strcmp(events_handnonautodual(h).responses.value,sequencenonautoprint'))
          fprintf('Seq correct \n')
      else
          fprintf('Seq incorrect \n')
      end  
end

%Show dual task performance (non-automatic sequence) for foot stomping task
%in command window
fprintf('Foot NonAutoDual \n')
for g = 1:N_trials
    fprintf('Trial %d: \n', g)
      if str2num(events_footnonautodual(g).stimuli.response{1})==length(strfind(events_footnonautodual(g).stimuli.value{1}, 'G'))
        fprintf('G correct \n')
      else
        fprintf('G incorrect \n')
      end 
end  

%Show tempo performance of finger tapping task of non-automaticity experiment
fprintf('Finger NonAuto \n')
for e = 1:N_trials
    fprintf('Trial %d: \n', e)
        margin=0.25; % margin of error: think about what is most convenient
      delay=mean(diff((events_handnonauto(e).responses.onset))-1/1.50);
      fprintf('the tempo was off with on average %f seconds \n', delay);
      if all(strcmp(events_handnonauto(e).responses.value,sequencenonautoprint'))
          fprintf('Seq correct \n')
      else
          fprintf('Seq incorrect \n')
      end         
end

%Show tempo performance of finger tapping task of automaticity experiment
fprintf('Finger Auto \n')
for f = 1:N_trials
    fprintf('Trial %d: \n', f)
        margin=0.25; % margin of error: think about what is most convenient
      delay=mean(diff((events_handauto(f).responses.onset))-1/1.50);
      fprintf('the tempo was off with on average %f seconds \n', delay);
      if all(strcmp(events_handauto(f).responses.value,sequenceautoprint'))
          fprintf('Seq correct \n')
      else
          fprintf('Seq incorrect \n')
      end         
end

% End of the experiment, thank the participant
Screen('TextSize',window,30);
DrawFormattedText(window,'This is the end of the experiment, thank you for participating!', 'center', 'center', white);
vbl = Screen('Flip', window);

KbStrokeWait;
sca

%% end the lsl session
trig.pulseIR(3, 0.2); % stop trigger for the nirs recording
delete(trig);
ses.stop();
dairy off;

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
