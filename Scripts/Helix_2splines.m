% ===========================================================
% Generate Sample Data (Two Helices) for Testing
% ===========================================================
clearvars; close all; clc; % Start fresh

fprintf('Generating sample data for two splines...\n');

% --- Spline 1 Data (Helix 1) ---
num_path_points1 = 250;
num_turns1 = 2;
helix_radius1 = 70;
helix_pitch1 = 120;
theta_helix1 = linspace(0, num_turns1 * 2*pi, num_path_points1);
b1 = helix_pitch1 / (2*pi);
x1_coords = helix_radius1 * cos(theta_helix1);
y1_coords = helix_radius1 * sin(theta_helix1);
z1_coords = b1 * theta_helix1;
spline_points_1 = table(x1_coords', y1_coords', z1_coords', 'VariableNames', {'X','Y','Z'});
fprintf('Created table "spline_points_1".\n');

% --- Spline 2 Data (Helix 2 - different parameters) ---
num_path_points2 = 35; % More points
num_turns2 = 2.0;
helix_radius2 = 35;    % Smaller radius
helix_pitch2 = 120;   % Steeper pitch
offset_z = 50;        % Start higher up
theta_helix2 = linspace(0, num_turns2 * 2*pi, num_path_points2);
b2 = helix_pitch2 / (2*pi);
x2_coords = helix_radius2 * cos(theta_helix2);
y2_coords = helix_radius2 * sin(theta_helix2);
z2_coords = b2 * theta_helix2 + offset_z; % Apply Z offset
spline_points_2 = table(x2_coords', y2_coords', z2_coords', 'VariableNames', {'X','Y','Z'});
fprintf('Created table "spline_points_2".\n');

% --- Optional: Plot generated paths ---
figure;
plot3(spline_points_1.X, spline_points_1.Y, spline_points_1.Z, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 5);
hold on;
plot3(spline_points_2.X, spline_points_2.Y, spline_points_2.Z, 'g-s', 'LineWidth', 1.5, 'MarkerSize', 5);
title('Generated Input Path Points (Centerlines)');
xlabel('X'); ylabel('Y'); zlabel('Z');
legend('Path 1', 'Path 2');
axis equal; grid on; view(3);
fprintf('Displaying the generated input paths.\n');
% ===========================================================
% End of Sample Point Generation
% ===========================================================
