% ===========================================================
% Generate Sample Helix Points for Testing
% ===========================================================
% clearvars; % Clear existing variables (optional, but good practice)
% close all; % Close existing figures (optional)
% clc;       % Clear command window (optional)

fprintf('Generating sample helix points...\n');

num_path_points = 50; % Number of points defining the basic helix path
num_turns = 2.5;      % Number of turns in the helix
helix_radius = 80;    % Radius of the helix itself
helix_pitch = 140;    % Vertical distance covered in one full turn

% Parameter for the helix curve (angle)
theta_helix = linspace(0, num_turns * 2*pi, num_path_points);

% Calculate coefficient for z based on pitch
b = helix_pitch / (2*pi);

% Calculate helix coordinates
x_coords = helix_radius * cos(theta_helix);
y_coords = helix_radius * sin(theta_helix);
z_coords = b * theta_helix;

% --- Create the table 'spline_points_2' ---
% The main script expects the data in this table format with these names
spline_points = table(x_coords', y_coords', z_coords', ...
                        'VariableNames', {'X','Y','Z'});

fprintf('Created table "spline_points_2" with %d helix points.\n', num_path_points);
disp('Sample path points table:');
disp(spline_points(1:min(5, num_path_points), :)); % Display first few points

% --- Optional: Plot the generated path points ---
figure;
plot3(spline_points.X, spline_points.Y, spline_points.Z, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 5);
title('Generated Helix Path Points (Centerline)');
xlabel('X'); ylabel('Y'); zlabel('Z');
axis equal;
grid on;
view(3);
fprintf('Displaying the generated helix path.\n');
% ===========================================================
% End of Sample Point Generation
% ===========================================================

% Now the main script starts...
%===========================================================
% Choose the path type for the cylinder centerline
%===========================================================
useSmoothSpline = true; % Set to 'true' for a smooth spline, 'false' for a polyline

% ... (rest of your script follows) ...