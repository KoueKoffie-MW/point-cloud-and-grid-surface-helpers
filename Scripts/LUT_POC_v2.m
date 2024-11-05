function [Z, X, Y, xGrid, yGrid] = createLookupTableFromSTL(stlFileName, boundingBox, gridResolution)
    % Read the STL file selectively
    vertices = readBinarySTLSelective(stlFileName, boundingBox);
    
    % Define the grid based on the bounding box and resolution
    xGrid = boundingBox(1):gridResolution:boundingBox(4);
    yGrid = boundingBox(2):gridResolution:boundingBox(5);
    [X, Y] = meshgrid(xGrid, yGrid);
    
    % Interpolate Z values on the grid
    Z = interpolateSTLToGrid(vertices, X, Y);
end

function vertices = readBinarySTLSelective(stlFileName, boundingBox)
    % Open the binary STL file
    fid = fopen(stlFileName, 'rb');
    if fid == -1
        error('Cannot open STL file.');
    end
    
    % Skip the header (80 bytes)
    fseek(fid, 80, 'bof');
    
    % Read the number of triangles
    numTriangles = fread(fid, 1, 'uint32');
    
    vertices = [];
    
    for i = 1:numTriangles
        % Read normal vector (3 floats)
        fread(fid, 3, 'float32');
        
        % Read the vertices of the triangle (3 vertices, each with 3 floats)
        triVerts = fread(fid, [3, 3], 'float32')';
        
        % Check if the triangle is within the 2D bounding box (x and y only)
        if any(triVerts(:, 1) >= boundingBox(1) & triVerts(:, 1) <= boundingBox(4) & ...
               triVerts(:, 2) >= boundingBox(2) & triVerts(:, 2) <= boundingBox(5))
            vertices = [vertices; triVerts];
        end
        
        % Skip the attribute byte count (2 bytes)
        fseek(fid, 2, 'cof');
    end
    
    fclose(fid);
end

function Z = interpolateSTLToGrid(vertices, X, Y)
    % Initialize Z with NaNs
    Z = NaN(size(X));
    
    % Delaunay triangulation for all vertices
    tri = delaunayTriangulation(vertices(:, 1), vertices(:, 2));
    
    % Interpolate Z values over the grid
    F = scatteredInterpolant(vertices(:, 1), vertices(:, 2), vertices(:, 3), 'linear', 'none');
    Z = F(X, Y);
    
    % Replace NaNs with zeros or another default value if needed
    % Z(isnan(Z)) = 0;
end

% Example usage:
tic
stlFileName = 'MRC_t.stl'; % Replace with your STL file
boundingBox = [-10, -10, NaN, 10, 10, NaN]; % Define the bounding box [xmin, ymin, zmin, xmax, ymax, zmax]
gridResolution = 0.5; % Define the grid resolution
[Z, X, Y, xGrid, yGrid] = createLookupTableFromSTL(stlFileName, boundingBox, gridResolution);
toc
% The variable Z can now be used as a table input in Simulink