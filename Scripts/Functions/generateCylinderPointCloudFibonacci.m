function [points, imageMatrix] = generateCylinderPointCloudFibonacci(radius, height, numPoints, numCircumferencePoints, numFacePoints, patchColor, markerColor, filename)
    % Generate a point cloud with equally spaced, unique points on the surface of a cylinder using the Fibonacci lattice method.
    %
    % Inputs:
    %   radius - Radius of the cylinder
    %   height - Height of the cylinder
    %   numPoints - Total number of points on the cylinder surface using the Fibonacci lattice
    %   numCircumferencePoints - Number of points on the circumference of each disc
    %   numFacePoints - Number of points on each disc surface using the Fibonacci lattice
    %   patchColor - Color of the patches in [R G B] format
    %   markerColor - Color of the markers in [R G B] format
    %
    % Output:
    %   points - A matrix containing the (x, y, z) coordinates of the unique points

    % Preallocate an array to store points with an estimated size
    estimatedTotalPoints = numPoints + 2 * (numCircumferencePoints + numFacePoints);
    points = zeros(estimatedTotalPoints, 3);
    pointIndex = 1;

    % Constants
    goldenAngle = pi * (3 - sqrt(5)); % Golden angle in radians
    halfHeight = height / 2;

    %% Cylindrical Surface
    for k = 1:numPoints
        z = height * (k - 0.5) / numPoints - halfHeight;
        theta = k * goldenAngle;
        x = radius * cos(theta);
        y = radius * sin(theta);
        points(pointIndex, :) = [x, y, z];
        pointIndex = pointIndex + 1;
    end

    %% Circumference
    theta = linspace(0, 2*pi, numCircumferencePoints + 1);
    theta(end) = []; % Remove the last point to avoid duplication

    x = radius * cos(theta);
    y = radius * sin(theta);

    % Top and bottom disc circumference
    points(pointIndex:pointIndex + numCircumferencePoints - 1, :) = [x', y', halfHeight * ones(size(x'))];
    pointIndex = pointIndex + numCircumferencePoints;
    points(pointIndex:pointIndex + numCircumferencePoints - 1, :) = [x', y', -halfHeight * ones(size(x'))];
    pointIndex = pointIndex + numCircumferencePoints;

    %% Discs
    for k = 1:numFacePoints
        r = sqrt(k - 0.5) / sqrt(numFacePoints) * radius;
        theta = k * goldenAngle;
        x = r * cos(theta);
        y = r * sin(theta);
        points(pointIndex, :) = [x, y, halfHeight];
        pointIndex = pointIndex + 1;
        points(pointIndex, :) = [x, y, -halfHeight];
        pointIndex = pointIndex + 1;
    end

    % Trim any unused preallocated space
    points = points(1:pointIndex-1, :);

    % Ensure all points are unique
    points = unique(points, 'rows');

    %% Drawing - Create figure
    K = convhull(points(:,1), points(:,2), points(:,3));

    fig = figure('Visible', 'off', 'Color', 'white');
    hold on;
    trisurf(K, points(:,1), points(:,2), points(:,3), 'FaceColor', patchColor, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    scatter3(points(:,1), points(:,2), points(:,3), 30, 'filled', 'MarkerFaceColor', markerColor);
    axis equal;
    axis off;
    view(45, 35.26);

    % Capture the figure as an image matrix
    frame = getframe(fig);
    imageMatrix = frame.cdata;

    % Close the figure
    close(fig);
end