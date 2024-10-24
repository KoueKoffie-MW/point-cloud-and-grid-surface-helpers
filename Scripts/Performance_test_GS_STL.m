% Performance of GS visualization Evaluation

% Define parameters
N = 3; % Number of times to run each simulation
Lower_res = 0.1; % Lower bound of the parameter range
Upper_res = 15; % Upper bound of the parameter range
Steps = 50; % Number of steps between Lower_res and Upper_res

% Calculate the step size
stepSize = (Upper_res - Lower_res) / (Steps - 1);

% Open the Simulink model
modelName = 'Terrain';
open_system(modelName);

% Initialize results storage
timingResultsGS = zeros(Steps, N);
timingResultsSTL = zeros(Steps, N);

% Function to run simulations for a given block configuration
function timings = runSimulations(paramRange, blockToComment, Steps, N, Lower_res, Upper_res, stepSize, modelName)
    timings = zeros(Steps, N);
    for stepIndex = 1:Steps
        % Calculate the current parameter value
        paramValue = Lower_res + (stepIndex - 1) * stepSize;

        % Set the parameter value in the active block
        set_param([modelName '/Visualize GS'], 'Commented', blockToComment{1});
        set_param([modelName '/Visualize STL'], 'Commented', blockToComment{2});
        
        % Assign 'Res' to the base workspace
        assignin('base', 'Res', paramValue);
        
        % Run the simulation N times for the current parameter value
        for runIndex = 1:N
            % Start timing
            tic;
            
            % Run the simulation
            sim(modelName);
            
            % Stop timing and store the result
            timings(stepIndex, runIndex) = toc;
        end
    end
end

% Run simulations with "Visualize GS" active and "Visualize STL" commented
timingResultsGS = runSimulations(Lower_res:stepSize:Upper_res, {'off', 'on'}, Steps, N, Lower_res, Upper_res, stepSize, modelName);

% Run simulations with "Visualize GS" commented and "Visualize STL" active
timingResultsSTL = runSimulations(Lower_res:stepSize:Upper_res, {'on', 'off'}, Steps, N, Lower_res, Upper_res, stepSize, modelName);

% Close the model
% close_system(modelName, 0);

% Display the timing results
disp('Timing Results with Visualize GS active:');
disp(timingResultsGS);
disp('Timing Results with Visualize STL active:');
disp(timingResultsSTL);

% Compare average times
averageTimesGS = mean(timingResultsGS, 2);
averageTimesSTL = mean(timingResultsSTL, 2);
paramValues = Lower_res:stepSize:Upper_res;

% Plot the results
figure;
plot(paramValues, averageTimesGS, '-o', 'DisplayName', 'Visualize GS Active');
hold on;
plot(paramValues, averageTimesSTL, '-x', 'DisplayName', 'Visualize STL Active');
xlabel('Resolution of the Grid Surface');
ylabel('Average Simulation Time (s)');
title('Simulation Time Comparison');
legend('show');
grid on;