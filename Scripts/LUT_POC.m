function [Z, X, Y,xGrid,yGrid] = createLookupTableFromSTL(stlFileName, boundingBox, gridResolution)
    % Read the STL file
    [vertices, faces] = readSTL(stlFileName);
    
    % Filter triangles within the bounding box
    triangles = querySpatialIndex(vertices, faces, boundingBox);
    
    % Define the grid based on the bounding box and resolution
    xGrid = boundingBox(1):gridResolution:boundingBox(4);
    yGrid = boundingBox(2):gridResolution:boundingBox(5);
    [X, Y] = meshgrid(xGrid, yGrid);
    
    % Interpolate Z values on the grid
    Z = interpolateSTLToGrid(vertices, triangles, X, Y);
end

function [vertices, faces] = readSTL(stlFileName)
    % This function reads an STL file and returns vertices and faces
    stlData = stlread(stlFileName);
    vertices = stlData.Points;
    faces = stlData.ConnectivityList;
end

function triangles = querySpatialIndex(vertices, faces, boundingBox)
    % Filter triangles based on the 2D bounding box (x and y only)
    triangles = [];
    for i = 1:size(faces, 1)
        triVerts = vertices(faces(i, :), :);
        if any(triVerts(:, 1) >= boundingBox(1) & triVerts(:, 1) <= boundingBox(4) & ...
               triVerts(:, 2) >= boundingBox(2) & triVerts(:, 2) <= boundingBox(5))
            triangles = [triangles; faces(i, :)];
        end
    end
end

function Z = interpolateSTLToGrid(vertices, triangles, X, Y)
    % Initialize Z with NaNs
    Z = NaN(size(X));
    
    % Loop through each triangle and interpolate
    for i = 1:size(triangles, 1)
        triVerts = vertices(triangles(i, :), :);
        
        % Create a delaunay triangulation for interpolation
        tri = delaunayTriangulation(triVerts(:, 1), triVerts(:, 2));
        
        % Interpolate Z values over the grid
        F = scatteredInterpolant(tri.Points, triVerts(:, 3), 'linear', 'none');
        Z = max(Z, F(X, Y)); % Use max to handle overlapping triangles
    end
    
    % Replace NaNs with zeros or another default value if needed
    % Z(isnan(Z)) = 0;
end
tic
% Example usage:
stlFileName = 'MRC_t.stl'; % Replace with your STL file
boundingBox = [-10, -10, NaN, 10, 10, NaN]; % Define the bounding box [xmin, ymin, zmin, xmax, ymax, zmax]
gridResolution = 0.5; % Define the grid resolution
[Z, X, Y,xGrid,yGrid] = createLookupTableFromSTL(stlFileName, boundingBox, gridResolution);
toc
% The variable Z can now be used as a table input in Simulink