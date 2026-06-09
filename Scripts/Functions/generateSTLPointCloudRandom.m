function [points, imageMatrix] = generateSTLPointCloudRandom(stlFilename, totalPoints, patchColor, markerColor, STL_points, numPoints, generateImage)

    if nargin < 7
        generateImage = true;
    end
    % Generate a point cloud with randomly spaced points on the surfaces of an STL model.
    %
    % Inputs:
    %   stlFilename - Name of the STL file to load
    %   totalPoints - Total number of points to distribute on the surfaces
    %   patchColor - Color of the patches in [R G B] format
    %   markerColor - Color of the markers in [R G B] format
    %   STL_points - Flag to include original STL vertices in the point cloud
    %
    % Output:
    %   points - A matrix containing the (x, y, z) coordinates of the points

    % Load the STL file using the provided stlread function
    tri = stlread(stlFilename);

    % Extract faces and vertices from the triangulation object
    faces = tri.ConnectivityList;
    vertices = tri.Points;

    % Compute the area of each triangle
    triAreas = computeTriangleAreas(vertices, faces);
    totalArea = sum(triAreas);

    % Determine the number of points per triangle based on area
    pointsPerTriangle = round(totalPoints * (triAreas / totalArea));

    % Initialize an empty array to store points
    points = [];

    % Generate points for each triangle
    for i = 1:size(faces, 1)
        % Get the vertices of the triangle
        v1 = vertices(faces(i, 1), :);
        v2 = vertices(faces(i, 2), :);
        v3 = vertices(faces(i, 3), :);

        % Generate random points within the triangle
        points = [points; generatePointsInTriangle(v1, v2, v3, pointsPerTriangle(i))];
    end

    % Include original STL vertices if STL_points flag is set
    if STL_points == 1
    
    % Ensure numPoints does not exceed the number of available vertices
    numVertices = size(vertices, 1);
    if numPoints > numVertices
        warning('Requested number of points exceeds available vertices. Using all vertices.');
        numPoints = numVertices;
    end

    % Randomly select a subset of vertices
    indices = randperm(numVertices, numPoints);
    points_random = vertices(indices, :);

        points = unique([points; points_random], 'rows');
    else
        points = unique(points, 'rows');
    end

    % Create the figure and plot the point cloud
    fig = figure('Visible', 'off', 'Color', 'white'); % Create the figure without displaying it
    hold on;

    % Plot the STL surface
    trisurf(faces, vertices(:,1), vertices(:,2), vertices(:,3), 'FaceColor', patchColor, 'FaceAlpha', 0.5, 'EdgeColor', 'none');

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

function points = generatePointsInTriangle(v1, v2, v3, numPoints)
    % Generate random points within a triangle using barycentric coordinates
    points = zeros(numPoints, 3);
    for i = 1:numPoints
        r1 = sqrt(rand());
        r2 = rand();
        a = 1 - r1;
        b = r1 * (1 - r2);
        c = r1 * r2;
        points(i, :) = a * v1 + b * v2 + c * v3;
    end
end

function areas = computeTriangleAreas(vertices, faces)
    % Compute the area of each triangle in a mesh
    numFaces = size(faces, 1);
    areas = zeros(numFaces, 1);

    for i = 1:numFaces
        v1 = vertices(faces(i, 1), :);
        v2 = vertices(faces(i, 2), :);
        v3 = vertices(faces(i, 3), :);
        areas(i) = 0.5 * norm(cross(v2 - v1, v3 - v1));
    end
end