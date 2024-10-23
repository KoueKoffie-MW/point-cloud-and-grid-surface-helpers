function [points, imageMatrix] = generateSpherePointCloud(numPoints, radius, patchColor, markerColor)
    % Generate a point cloud with equally spaced points on a sphere
    % using the Fibonacci lattice method.
    %
    % Inputs:
    %   numPoints - Number of points to generate on the sphere
    %   radius - Radius of the sphere
    %   patchColor - Color of the patches in [R G B] format
    %   markerColor - Color of the markers in [R G B] format
    %
    % Output:
    %   points - A numPoints x 3 matrix containing the (x, y, z) coordinates

    % Golden angle in radians
    goldenAngle = pi * (3 - sqrt(5));

    % Preallocate the matrix for efficiency
    points = zeros(numPoints, 3);

    % Generate points using the Fibonacci lattice method
    for i = 0:numPoints-1
        theta = goldenAngle * i;
        z = (2 * i / numPoints) - 1; % z ranges from -1 to 1
        radiusAtZ = sqrt(1 - z^2);   % Radius of the circle at height z

        x = radiusAtZ * cos(theta);
        y = radiusAtZ * sin(theta);

        % Scale by the sphere's radius
        points(i+1, :) = radius * [x, y, z];
    end

    % Compute the convex hull
    K = convhull(points(:,1), points(:,2), points(:,3));

    % Create the figure and plot the point cloud
    fig = figure('Visible', 'off','Color','white'); % Create the figure without displaying it
    hold on;
    
    % Plot the convex hull
    trisurf(K, points(:,1), points(:,2), points(:,3), 'FaceColor', patchColor, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    
    % Plot the point cloud
    scatter3(points(:,1), points(:,2), points(:,3), 30, 'filled', 'MarkerFaceColor', markerColor);
    axis equal;
    axis off; % Turn off the axes visibility
    
    % Set the view to isometric
    view(45, 35.26);

    % Capture the figure as an image matrix
    frame = getframe(fig);
    imageMatrix = frame.cdata;

    % Close the figure
    close(fig);
end