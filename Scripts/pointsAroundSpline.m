%===========================================================
% Choose the path type for the cylinder centerline
%===========================================================
useSmoothSpline = true; % Set to 'true' for a smooth spline, 'false' for a polyline

%===========================================================
% Input Data & Parameters
%===========================================================
% Load or define your spline/polyline points here
% Ensure the table 'spline_points_2' exists or load data here.
% Example: If your data is in a file:
% opts = detectImportOptions('spline_data.xlsx'); % Or .csv, etc.
% opts = setvartype(opts, {'VarName2','VarName3','VarName4'}, 'double');
% opts = renamevars(opts, ["VarName2", "VarName3", "VarName4"], ["X", "Y", "Z"]);
% spline_points_2 = readtable('spline_data.xlsx', opts);

% Get coordinates from table (try X,Y,Z first, then VarName...)
try
    x = spline_points.X';
    y = spline_points.Y';
    z = spline_points.Z';
catch
    disp('Using default VarName2, VarName3, VarName4'); % Changed message
    x = spline_points.VarName2';
    y = spline_points.VarName3';
    z = spline_points.VarName4';
end

% clear spline_points_2; % Clear table if no longer needed (optional)

input_points = [x; y; z]; % Combine points for easier handling

% Parameters
R = 15; % Radius of the cylinder
NUM = 2500; % Number of points on the cylinder surface
N_fine = 100 * size(input_points, 2); % Number of points for fine spline evaluation (for length calculation)

%===========================================================
% Calculate Path Length and Spline Data (if needed)
%===========================================================
if useSmoothSpline
    fprintf('Using smooth spline path.\n'); % Changed message
    % Create a parametric cubic spline through the points
    pp = cscvn(input_points); % Piecewise polynomial structure

    % Evaluate spline at fine points to estimate length
    t_fine = linspace(pp.breaks(1), pp.breaks(end), N_fine);
    fine_points = ppval(pp, t_fine);

    % Calculate cumulative arc length along the fine points
    segment_lengths = sqrt(sum(diff(fine_points, 1, 2).^2, 1));
    cumulativeLengths = [0, cumsum(segment_lengths)];
    totalLength = cumulativeLengths(end);

    % Create derivative structure (for direction/tangent vector)
    pp_deriv = fnder(pp);

else
    fprintf('Using polyline path.\n'); % Changed message
    % Calculate cumulative arc length along the input points (polyline)
    segment_lengths = sqrt(sum(diff(input_points, 1, 2).^2, 1));
    cumulativeLengths = [0, cumsum(segment_lengths)];
    totalLength = cumulativeLengths(end);
end

%===========================================================
% Generate Points on Cylinder Surface
%===========================================================
% Initialize point cloud
pointCloud = zeros(NUM, 3);

% Golden angle in radians (for Fibonacci lattice distribution)
% This method helps distribute points fairly evenly over the cylinder surface.
golden_angle = pi * (3 - sqrt(5));

fprintf('Generating %d points...\n', NUM); % Changed message
for j = 1:NUM
    % Calculate the fractional position along the total length
    frac = (j - 0.5) / NUM; % Fraction of total length
    targetArcLength = frac * totalLength;

    % Get point and direction on the centerline
    if useSmoothSpline
        % Find the spline parameter 't' corresponding to targetArcLength
        % Linear interpolation on our fine arc length table
        t = interp1(cumulativeLengths, t_fine, targetArcLength);

        % Evaluate spline position and direction at this parameter 't'
        pointOnSpline = ppval(pp, t)';         % Column vector -> Row vector
        direction = ppval(pp_deriv, t)';    % Column vector -> Row vector

    else % useSmoothSpline = false (Polyline)
        % Find the segment where this arc length falls
        % Search for the first index 'k' where cumulativeLengths(k) >= targetArcLength
        segmentIndex = find(cumulativeLengths >= targetArcLength, 1) - 1;

        % Handle edge cases for segmentIndex
        if isempty(segmentIndex) || targetArcLength <= cumulativeLengths(1) % Before the first point
             segmentIndex = 1;
             localT = 0; % Stay at the first point
        elseif segmentIndex == 0 % Special case if find returns 1 (meaning target is between 1st and 2nd)
             segmentIndex = 1;
        end
        if segmentIndex > size(input_points, 2) - 1 % If it falls exactly on or after the last point
             segmentIndex = size(input_points, 2) - 1;
             localT = 1; % Stay at the last point
        end

        % Get the start and end points of the segment
        p1 = input_points(:, segmentIndex)';
        p2 = input_points(:, segmentIndex + 1)';

        % Calculate the local position within the segment (if not handled by edge cases)
        if ~(targetArcLength <= cumulativeLengths(1) || segmentIndex == size(input_points, 2) - 1 && targetArcLength >= cumulativeLengths(end))
            segmentLength = cumulativeLengths(segmentIndex + 1) - cumulativeLengths(segmentIndex);
            if segmentLength > eps % Avoid division by zero if points coincide
                 localT = (targetArcLength - cumulativeLengths(segmentIndex)) / segmentLength;
            else
                 localT = 0; % Stay at p1 if segment length is zero
            end
        end

        % Interpolate to find the point on the polyline
        pointOnSpline = (1 - localT) * p1 + localT * p2;

        % Calculate the direction vector of the segment
        direction = p2 - p1;
    end

    % Normalize the direction vector
    norm_dir = norm(direction);
    if norm_dir > eps % Avoid division by zero
        direction = direction / norm_dir;
    else
        % If direction is zero (e.g., duplicate points), use previous direction
        % or a default. We use a simple default here.
        if j > 1 % Try to reuse previous direction if possible
             % Estimate previous direction (might not be perfectly accurate if R is large)
             prev_direction = pointCloud(j-1, :) - pointOnSpline;
             if norm(prev_direction) > eps
                 direction = prev_direction / norm(prev_direction);
             else
                 direction = [1, 0, 0]; % Safe default
             end
        else
             direction = [1, 0, 0]; % Safe default for the very first point
        end
         warning('Segment with near-zero length found near point index %d. Direction approximated.', j); % Changed message
    end

    %-----------------------------------------------------
    % Calculate orthogonal vectors (Robust method)
    %-----------------------------------------------------
    % Find the axis corresponding to the smallest component of 'direction'
    [~, min_idx] = min(abs(direction));
    temp_vec = zeros(1, 3);
    temp_vec(min_idx) = 1; % Create a unit vector along that axis (e.g., [1,0,0] or [0,1,0] or [0,0,1])

    % The cross product will be orthogonal to both 'direction' and 'temp_vec'
    orthogonal1 = cross(direction, temp_vec);
    norm_orth1 = norm(orthogonal1);
     if norm_orth1 > eps % Normalize the first orthogonal vector
         orthogonal1 = orthogonal1 / norm_orth1;
     else
         % This case is unlikely if norm(direction) > 0.
         % It could happen if 'direction' is parallel to 'temp_vec' (e.g., direction=[1,0,0]).
         % Choose a different temp_vec.
         temp_vec = zeros(1,3); temp_vec(mod(min_idx,3)+1) = 1; % Choose next axis (cyclical)
         orthogonal1 = cross(direction, temp_vec);
         orthogonal1 = orthogonal1 / norm(orthogonal1); % Should work now
     end

    % Calculate the second orthogonal vector
    orthogonal2 = cross(direction, orthogonal1);
    % orthogonal2 does not need explicit normalization if direction & orthogonal1
    % are unit vectors and orthogonal. You could add normalization for robustness:
    % orthogonal2 = orthogonal2 / norm(orthogonal2);

    %-----------------------------------------------------
    % Calculate position on cylinder surface (Fibonacci)
    %-----------------------------------------------------
    theta = j * golden_angle;
    circlePoint = R * (cos(theta) * orthogonal1 + sin(theta) * orthogonal2);

    % Final point is the centerline point + offset on the circle
    pointCloud(j, :) = pointOnSpline + circlePoint;
end
fprintf('Finished generating points.\n'); % Changed message

%===========================================================
% Visualize the Point Cloud
%===========================================================
figure;
scatter3(pointCloud(:,1), pointCloud(:,2), pointCloud(:,3), 10, '.', 'MarkerFaceAlpha', 0.8, 'MarkerEdgeAlpha', 0.8); % Smaller points, slightly transparent
hold on;
% Plot the centerline for context
if useSmoothSpline
    plot3(fine_points(1,:), fine_points(2,:), fine_points(3,:), 'r-', 'LineWidth', 2);
else
    plot3(input_points(1,:), input_points(2,:), input_points(3,:), 'r-o', 'LineWidth', 1.5, 'MarkerSize', 4);
end
hold off;

xlabel('X'); ylabel('Y'); zlabel('Z');
if useSmoothSpline
    title('Point Cloud on Cylinder Surface (Smooth Spline Path)'); % Changed title
else
    title('Point Cloud on Cylinder Surface (Polyline Path)'); % Changed title
end
axis equal; % Ensure aspect ratio is correct
grid on;
view(3); % Set 3D view
rotate3d on; % Allow interactive rotation

disp('Visualization complete.'); % Changed message