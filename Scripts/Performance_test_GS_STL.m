% Performance of GS visualization Evaluation

% Define parameters
N = 5; % Number of times to run each simulation
Lower_res = 3.5; % Lower bound of the parameter range
Upper_res = 10; % Upper bound of the parameter range
Steps = 30; % Number of steps between Lower_res and Upper_res

% Calculate the step size
stepSize = (Upper_res - Lower_res) / (Steps - 1);

% Open the Simulink model
modelName = 'Terrain';
open_system(modelName);

% Initialize results storage
timingResultsGS = NaN(Steps, N);
timingResultsSTL = NaN(Steps, N);

% Function to run simulations for a given block configuration
function timings = runSimulations(paramRange, blockToComment, Steps, N, Lower_res, Upper_res, stepSize, modelName)
    timings = NaN(Steps, N);
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
            try
                % Start timing
                tic;
                
                % Run the simulation
                sim(modelName);
                
                % Stop timing and store the result if successful
                timings(stepIndex, runIndex) = toc;
            catch ME
                % Handle simulation error
                warning('Simulation failed at step %d, run %d: %s', stepIndex, runIndex, ME.message);
                % Optionally, log the error message or take other actions
            end
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

% Prepare data for box plot
allResults = [timingResultsGS(:); timingResultsSTL(:)];
groupLabels = [repmat({'G'}, Steps*N, 1); repmat({'S'}, Steps*N, 1)];
paramValuesExpanded = repmat((Lower_res:stepSize:Upper_res)', N, 2);

% Plot the results as a box plot
figure;
boxplot(allResults, {paramValuesExpanded(:), groupLabels(:)}, 'factorgap', 5, ...
    'colors', ['b', 'r'], 'labelverbosity', 'minor');
xlabel('Resolution of the Grid Surface');
ylabel('Simulation Time (s)');
title('Simulation Time Comparison');
grid on;

% Add custom legend for the box plot
hold on;
h = findobj(gca, 'Tag', 'Box');
legend([h(1), h(end)], {'Visualize GS Active', 'Visualize STL Active'});

% Compare average times
averageTimesGS = mean(timingResultsGS, 2);
averageTimesSTL = mean(timingResultsSTL, 2);
paramValues = Lower_res:stepSize:Upper_res;

% Plot the average times as lines for comparison
figure;
hold on;
plot(paramValues, averageTimesGS, '-o', 'DisplayName', 'Visualize GS Active');
plot(paramValues, averageTimesSTL, '-x', 'DisplayName', 'Visualize STL Active');
xlabel('Resolution of the Grid Surface');
ylabel('Average Simulation Time (s)');
title('Average Simulation Time Comparison');
legend('show');
grid on;