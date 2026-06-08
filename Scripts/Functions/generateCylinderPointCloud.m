function [points, imageMatrix] = generateCylinderPointCloud(radius, height, numRadialDivisions, numHeightDivisions, numFaceRadialDivisions, numFaceAngularDivisions, angularOffset, faceAngularOffset, patchColor, markerColor, generateImage)

    if nargin < 11
        generateImage = true;
    end
    % Generate a point cloud with equally spaced, unique points on the surface of a cylinder.
    %
    % Inputs:
    %   radius - Radius of the cylinder
    %   height - Height of the cylinder
    %   numRadialDivisions - Number of divisions around the circumference for the curved surface
    %   numHeightDivisions - Number of divisions along the height
    %   numFaceRadialDivisions - Number of radial divisions for the circular faces
    %   numFaceAngularDivisions - Number of angular divisions for the circular faces
    %   angularOffset - Angular offset in radians for each layer in the z-direction
    %   faceAngularOffset - Angular offset in radians for the points on the circular faces
    %   patchColor - Color of the patches in [R G B] format
    %   markerColor - Color of the markers in [R G B] format
    %
    % Output:
    %   points - A matrix containing the (x, y, z) coordinates of the unique points

    % Create linearly spaced points along the height
    z = linspace(-height/2, height/2, numHeightDivisions);

    % Create angular divisions for the circumference
    theta = linspace(0, 2*pi, numRadialDivisions);

    % Initialize an empty array to store points
    points = [];

    % Generate points for the curved surface of the cylinder with angular offset
    for i = 1:length(z)
        currentTheta = theta + (i-1) * angularOffset;
        x = radius * cos(currentTheta);
        y = radius * sin(currentTheta);
        z_layer = z(i) * ones(size(currentTheta));
        points = [points; x', y', z_layer'];
    end

    % Generate points for the top and bottom circular faces with angular offset
    radialDivisions = linspace(0, radius, numFaceRadialDivisions);
    for j = 1:numFaceRadialDivisions
        angularDivisions = linspace(0, 2*pi, numFaceAngularDivisions) + (j-1) * faceAngularOffset;
        [R, T] = meshgrid(radialDivisions(j), angularDivisions);
        X = R .* cos(T);
        Y = R .* sin(T);

        Z_top = (height/2) * ones(size(X));
        Z_bottom = (-height/2) * ones(size(X));

        points = [points; X(:), Y(:), Z_top(:)];
        points = [points; X(:), Y(:), Z_bottom(:)];
    end

    % Ensure all points are unique
    points = unique(points, 'rows');

    % Compute the convex hull
    K = convhull(points(:,1), points(:,2), points(:,3));

    % Create the figure and plot the point cloud
    fig = figure('Visible', 'off', 'Color', 'white'); % Create the figure without displaying it
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