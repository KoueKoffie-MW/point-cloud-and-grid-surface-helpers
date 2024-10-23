function [points, imageMatrix] = generateBrickPointCloud(length, width, height, numDivisionsLength, numDivisionsWidth, numDivisionsHeight, patchColor, markerColor)
    % Generate a point cloud with equally spaced, unique points on the surface of a brick.
    %
    % Inputs:
    %   length - Length of the brick (x-dimension)
    %   width - Width of the brick (y-dimension)
    %   height - Height of the brick (z-dimension)
    %   numDivisionsLength - Number of divisions along the length
    %   numDivisionsWidth - Number of divisions along the width
    %   numDivisionsHeight - Number of divisions along the height
    %   patchColor - Color of the patches in [R G B] format
    %   markerColor - Color of the markers in [R G B] format
    %
    % Output:
    %   points - A matrix containing the (x, y, z) coordinates of the unique points

    % Create linearly spaced points along each dimension
    x = linspace(-length/2, length/2, numDivisionsLength);
    y = linspace(-width/2, width/2, numDivisionsWidth);
    z = linspace(-height/2, height/2, numDivisionsHeight);

    % Initialize an empty array to store points
    points = [];

    % Generate points for each face of the brick
    % Front and back faces (y = ±width/2)
    [X, Z] = meshgrid(x, z);
    points = [points; X(:), width/2 * ones(numel(X), 1), Z(:)];
    points = [points; X(:), -width/2 * ones(numel(X), 1), Z(:)];

    % Left and right faces (x = ±length/2)
    [Y, Z] = meshgrid(y, z);
    points = [points; length/2 * ones(numel(Y), 1), Y(:), Z(:)];
    points = [points; -length/2 * ones(numel(Y), 1), Y(:), Z(:)];

    % Top and bottom faces (z = ±height/2)
    [X, Y] = meshgrid(x, y);
    points = [points; X(:), Y(:), height/2 * ones(numel(X), 1)];
    points = [points; X(:), Y(:), -height/2 * ones(numel(X), 1)];

    % Ensure all points are unique
    points = unique(points, 'rows');

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