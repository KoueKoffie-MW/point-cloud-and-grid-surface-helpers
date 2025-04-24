% --- Script Configuration ---
useSmoothSpline = true; % Apply to BOTH paths: true for smooth spline, false for polyline
R = 25; % Cylinder radius (applied to both paths)
NUM_TOTAL = 20000; % Total number of points in the final combined cloud

try
    x1 = spline_points_1.X';
    y1 = spline_points_1.Y';
    z1 = spline_points_1.Z';
    
catch
    disp('Using default VarName2, VarName3, VarName4'); % Changed message
    x1 = spline_points_1.VarName2';
    y1 = spline_points_1.VarName3';
    z1 = spline_points_1.VarName4';
end

try
    x2 = spline_points_2.X';
    y2 = spline_points_2.Y';
    z2 = spline_points_2.Z';
catch
    disp('Using default VarName2, VarName3, VarName4'); % Changed message
    x2 = spline_points_2.VarName2';
    y2 = spline_points_2.VarName3';
    z2 = spline_points_2.VarName4';
end
input_points1 = [x1; y1; z1];
input_points2 = [x2; y2; z2];

% clear spline_points_1; % Optional
% clear spline_points_2; % Optional


% --- Calculate Path Lengths to Distribute Points Proportionally ---
fprintf('Calculating path lengths...\n');
% We need a simplified length calculation here just for distribution.
% The full calculation happens inside the function later.
[pathLength1, ~] = calculatePathLength(input_points1, useSmoothSpline);
[pathLength2, ~] = calculatePathLength(input_points2, useSmoothSpline);

if (pathLength1 + pathLength2) < eps
    error('Total path length is zero. Check input points.');
end

% Distribute NUM_TOTAL points proportionally
numPoints1 = round(NUM_TOTAL * pathLength1 / (pathLength1 + pathLength2));
numPoints2 = NUM_TOTAL - numPoints1; % Ensure total is NUM_TOTAL

fprintf('Path 1 Length: %.2f | Points: %d\n', pathLength1, numPoints1);
fprintf('Path 2 Length: %.2f | Points: %d\n', pathLength2, numPoints2);


% --- Generate Points for Path 1 ---
if numPoints1 > 0
    fprintf('Generating %d points for Path 1...\n', numPoints1);
    [pointCloud1, length1_actual, path1_coords_vis] = generateCylinderPoints(input_points1, R, numPoints1, useSmoothSpline);
else
    pointCloud1 = zeros(0, 3); % Empty array if no points allocated
    path1_coords_vis = input_points1; % For plotting
end

% --- Generate Points for Path 2 ---
if numPoints2 > 0
    fprintf('Generating %d points for Path 2...\n', numPoints2);
    [pointCloud2, length2_actual, path2_coords_vis] = generateCylinderPoints(input_points2, R, numPoints2, useSmoothSpline);
else
    pointCloud2 = zeros(0, 3); % Empty array if no points allocated
     path2_coords_vis = input_points2; % For plotting
end

% --- Combine Point Clouds ---
fprintf('Combining point clouds...\n');
pointCloud = [pointCloud1; pointCloud2];


%===========================================================
% Visualize the Combined Point Cloud
%===========================================================
fprintf('Visualizing the combined point cloud...\n');
figure;
% Plot the combined point cloud
scatter3(pointCloud(:,1), pointCloud(:,2), pointCloud(:,3), 10, '.', 'MarkerFaceAlpha', 0.7, 'MarkerEdgeAlpha', 0.7);
hold on;

% Plot the centerlines for context
plot3(path1_coords_vis(1,:), path1_coords_vis(2,:), path1_coords_vis(3,:), 'r-', 'LineWidth', 2.5);
plot3(path2_coords_vis(1,:), path2_coords_vis(2,:), path2_coords_vis(3,:), 'm-', 'LineWidth', 2.5);

hold off;
xlabel('X'); ylabel('Y'); zlabel('Z');
title(sprintf('Combined Point Cloud (%d Points Total)', NUM_TOTAL));
legend('Combined Point Cloud', 'Centerline 1', 'Centerline 2', 'Location', 'best');
axis equal; % Ensure aspect ratio is correct
grid on;
view(3); % Set 3D view
rotate3d on; % Allow interactive rotation
fprintf('Visualization complete.\n');


% ===========================================================
% Helper Functions
% ===========================================================

function [totalLength, path_coords] = calculatePathLength(input_pts, useSpline)
    % Calculates approximate path length for spline or polyline
    if size(input_pts, 2) < 2
        totalLength = 0;
        path_coords = input_pts;
        return;
    end

    if useSpline
        N_fine_length = 10 * size(input_pts, 2); % Resolution for length calc
        try
            pp = cscvn(input_pts);
            t_fine = linspace(pp.breaks(1), pp.breaks(end), N_fine_length);
            fine_points = ppval(pp, t_fine);
            segment_lengths = sqrt(sum(diff(fine_points, 1, 2).^2, 1));
            totalLength = sum(segment_lengths);
            path_coords = fine_points; % Return fine points for visualization
        catch spline_err
             warning('Spline creation/evaluation failed during length calculation: %s. Falling back to polyline length.', spline_err.message);
             segment_lengths = sqrt(sum(diff(input_pts, 1, 2).^2, 1));
             totalLength = sum(segment_lengths);
             path_coords = input_pts; % Return original points
        end
    else
        segment_lengths = sqrt(sum(diff(input_pts, 1, 2).^2, 1));
        totalLength = sum(segment_lengths);
        path_coords = input_pts; % Return original points
    end
end


function [cloudPoints, totalLength, path_coords_vis] = generateCylinderPoints(input_points, R, NUM, useSmoothSpline)
    % Generates NUM points on a cylinder of radius R around the path defined by input_points
    % Returns the point cloud, the calculated path length, and path coordinates for visualization

    cloudPoints = zeros(NUM, 3); % Initialize output
    if NUM == 0 || size(input_points, 2) < 2
        totalLength = 0;
        path_coords_vis = input_points;
        return; % Return empty if no points requested or path too short
    end

    N_fine = 10 * size(input_points, 2); % Resolution for spline evaluation

    % --- Calculate Path Length and Setup ---
    if useSmoothSpline
        try
            pp = cscvn(input_points);
            t_fine = linspace(pp.breaks(1), pp.breaks(end), N_fine);
            fine_points = ppval(pp, t_fine);
            segment_lengths = sqrt(sum(diff(fine_points, 1, 2).^2, 1));
            cumulativeLengths = [0, cumsum(segment_lengths)];
            totalLength = cumulativeLengths(end);
            pp_deriv = fnder(pp);
            path_coords_vis = fine_points; % Use fine points for visualization
        catch spline_err
             warning('Spline creation/evaluation failed in generation function: %s. Cannot proceed with spline for this path.', spline_err.message);
             cloudPoints = zeros(0,3); % Return empty
             totalLength = 0;
             path_coords_vis = input_points;
             return;
        end
    else % Polyline
        segment_lengths = sqrt(sum(diff(input_points, 1, 2).^2, 1));
        cumulativeLengths = [0, cumsum(segment_lengths)];
        totalLength = cumulativeLengths(end);
        path_coords_vis = input_points; % Use original points for visualization
    end

    if totalLength < eps
        warning('Path length is near zero. Cannot generate points.');
        cloudPoints = zeros(0,3); % Return empty
        return;
    end

    % --- Golden Angle ---
    golden_angle = pi * (3 - sqrt(5));

    % --- Generation Loop ---
    for j = 1:NUM
        frac = (j - 0.5) / NUM;
        targetArcLength = frac * totalLength;

        % Clamp targetArcLength to valid range to avoid interp1 errors
        targetArcLength = max(cumulativeLengths(1), min(cumulativeLengths(end), targetArcLength));

        % --- Get point and direction on centerline ---
        if useSmoothSpline
            t = interp1(cumulativeLengths, t_fine, targetArcLength);
            pointOnSpline = ppval(pp, t)';
            direction = ppval(pp_deriv, t)';
        else % Polyline
            segmentIndex = find(cumulativeLengths >= targetArcLength, 1) - 1;
            if isempty(segmentIndex) || targetArcLength <= cumulativeLengths(1)
                 segmentIndex = 1; localT = 0;
            elseif segmentIndex == 0
                 segmentIndex = 1;
            end
            if segmentIndex > size(input_points, 2) - 1
                 segmentIndex = size(input_points, 2) - 1; localT = 1;
            end

            p1 = input_points(:, segmentIndex)';
            p2 = input_points(:, segmentIndex + 1)';

             if ~(targetArcLength <= cumulativeLengths(1) || (segmentIndex == size(input_points, 2) - 1 && targetArcLength >= cumulativeLengths(end)))
                 segmentLength = cumulativeLengths(segmentIndex + 1) - cumulativeLengths(segmentIndex);
                 if segmentLength > eps
                      localT = (targetArcLength - cumulativeLengths(segmentIndex)) / segmentLength;
                 else; localT = 0; end
             elseif targetArcLength <= cumulativeLengths(1)
                 localT = 0; % Handle start point case explicitly
             else % Handle end point case explicitly
                 localT = 1;
             end

            pointOnSpline = (1 - localT) * p1 + localT * p2;
            direction = p2 - p1;
        end

        % --- Normalize direction vector ---
        norm_dir = norm(direction);
        if norm_dir > eps
            direction = direction / norm_dir;
        else % Handle zero-length segments/derivatives
             if j > 1 && norm(cloudPoints(j-1,:)) > 0 % Try to use vector pointing from last point
                 prev_direction = pointOnSpline - cloudPoints(j-1, :); % Approximate
                 if norm(prev_direction) > eps
                    direction = prev_direction / norm(prev_direction);
                 else; direction = [1, 0, 0]; end % Default if still fails
             else; direction = [1, 0, 0]; end % Default for first point or repeated failures
             warning('Direction vector norm near zero at point %d. Using default/previous.', j);
        end

        % --- Calculate orthogonal vectors (Robust method) ---
        [~, min_idx] = min(abs(direction));
        temp_vec = zeros(1, 3); temp_vec(min_idx) = 1;
        orthogonal1 = cross(direction, temp_vec);
        norm_orth1 = norm(orthogonal1);
         if norm_orth1 > eps
             orthogonal1 = orthogonal1 / norm_orth1;
         else % Direction is likely parallel to temp_vec
             temp_vec = zeros(1,3); temp_vec(mod(min_idx,3)+1) = 1; % Choose next axis
             orthogonal1 = cross(direction, temp_vec);
             orthogonal1 = orthogonal1 / norm(orthogonal1); % Should work now
         end
        orthogonal2 = cross(direction, orthogonal1);

        % --- Calculate position on cylinder surface ---
        theta = j * golden_angle;
        circlePoint = R * (cos(theta) * orthogonal1 + sin(theta) * orthogonal2);

        cloudPoints(j, :) = pointOnSpline + circlePoint;
    end % End generation loop
end % End function generateCylinderPoints