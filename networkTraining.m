% This file trains the network created by generateESN.m with the training
% data generated by generateMGData.m.
% A small test is included at the end of the training to verify the model

%% Data preparation
% Training data extraction
sampleOut = trainSeq';

% Data splitting
washoutLength = 1000;           % Data portion used for transient clearance
trainingLength = 2000;          % Data portion used for learning
testingLength = 200;            % Small data portion for testing

%% Noise level
% Noise level is used as a trick to increase stability of the network
noiselevel = 1e-10;

%% Data initialization for learning
% Activation state of all units
totalstate =  zeros(totalDim,1);    

% Activation states of internal units
internalState = totalstate(1:internalLength);

% Output weight matrix (trainable)
outWM = initialOutWM;

% Collection of all activation states during training period for learning
stateCollectMat = zeros(trainingLength, internalLength + inputLength);
teachCollectMat = zeros(trainingLength, outputLength);

%% Data initialization for testing
% Teacher and network output after training
teacherTest = zeros(outputLength, testingLength);
netOutTest = zeros(outputLength, testingLength);

% Internal states after training
plotStates = [1 2 3 4];         % Indices of internal states for plotting
internalStateTest = zeros(length(plotStates),testingLength);
plotindex = 0;

% Mean-squared error (MSE) values initialization
msetest = zeros(1,outputLength); 
msetrain = zeros(1,outputLength); 

%% Parameter visualization
fprintf('Initialization:\n')
fprintf('Spectral radius = %g   reservoirSize = %g   TrainingLength = %g\n',...
    spectralRadius, internalLength, trainingLength);

fprintf('Start learning...\n')

%% Scanning through training data
for i = 1 : washoutLength + trainingLength + testingLength 
    %% Teacher extraction
    teach = sampleOut(1,i);  
    
    %% Input update
    % Input unit is constantly biased of size 0.02
    in = 0.02;
    
    % Update input state into totalstate
    totalstate(internalLength+1:internalLength+inputLength) = in; 
    
    %% Internal state update
    % Update internal state
    if noiselevel == 0 ||  i > washoutLength + trainingLength
            internalState = tanh([intWM, inWM, ofbWM]*totalstate);  
    else
            internalState = tanh([intWM, inWM, ofbWM]*totalstate + ...
                noiselevel * 2.0 * (rand(internalLength,1)-0.5));
    end
    
    %% Output update
    % Update output units
    netOut = tanh(outWM *[internalState;in]);
    
    % Update internal states and output state into totalstate
    totalstate = [internalState;in;netOut];    
    
    %% Forcing teacher output (During washout and training period)
    % Force teacher output 
    if i <= washoutLength + trainingLength
        totalstate(internalLength+inputLength+1:internalLength+inputLength+outputLength) = teach'; 
    end
    
    %% Collecting states for later use in computing model (During training period)
    % Note: States during washoutLength will be ignored
    if (i > washoutLength) && (i <= washoutLength + trainingLength) 
        collectIndex = i - washoutLength;
        stateCollectMat(collectIndex,:) = [internalState' in'];
        teachCollectMat(collectIndex,:) = (atanh(teach))';
    end
    
    %% Computing new model (At the end of training period)
    if i == washoutLength + trainingLength
        % Update output weight matrix
        % Linear regression algorithm: Using normal equation
        outWM = (pinv(stateCollectMat) * teachCollectMat)'; 
        
        % Compute MSE_train using the newly computed weights
        msetrain = sum((tanh(teachCollectMat) - tanh(stateCollectMat * outWM')).^2);
    end  
    
    %% Collecting testing data (After training period)
    if i > washoutLength + trainingLength
        % Record plotting data
        plotindex = plotindex + 1;
        teacherTest(:,plotindex) = teach; 
        netOutTest(:,plotindex) = netOut;
        for j = 1:length(plotStates)
            internalStateTest(j,plotindex) = totalstate(plotStates(j),1);
        end
        
        % Update MSE_test
        msetest = msetest + (teach - netOut)^2;
    end
end

fprintf('Learning completed!\n')

%% MSE result printing
fprintf('Training result:\n');

msetest = msetest / testingLength;
msetrain = msetrain / trainingLength;

fprintf('MSE_train = %g   MSE_test = %g   avgWeights = %g\n', ...
    msetrain, msetest, mean(abs(outWM)));

%% Data plotting
% Plot internal state
figure(1);
for k = 1:length(plotStates)
    subplot(2,2,k);
    plot(internalStateTest(k,:));
    title('Internal state');
end    

% Plot network output and teacher after training  
figure(2);
% Teacher
subplot(2,1,1);
plot(1:testingLength,teacherTest(1,:),'-k');
title('Teacher');
% Network output
subplot(2,1,2);
plot(1:testingLength,netOutTest(1,:),'-b');
title('Output');