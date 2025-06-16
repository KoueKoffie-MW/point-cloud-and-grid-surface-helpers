function [imageMatrix, xi, yi, ZI, z_query] = GenerateTerrainFromTIFF(stlFileName, resolution, x_query, y_query)
    % GenerateTerrainFromTIFF Processes an Local TIFF file to generate a surface object. with specified resolution.
    %
    %   [imageMatrix, xi, yi, ZI, Res_orig, z_query] = GenerateTerrainFromTIFF(stlFileName, resolution, x_query, y_query)
    %
    % Inputs:
    %   stlFileName - Name of the TIFF file to be read.
    %   resolution  - Tiff File resolution resolution in meters.
    %   x_query     - x-coordinates for querying z-heights.
    %   y_query     - y-coordinates for querying z-heights.
    %
    % Outputs:
    %   imageMatrix - Mask Image
    %   xi, yi      - Grid vectors for the x and y axes.
    %   ZI          - Interpolated Z data.
    %   Res_orig    - Original resolution of the STL data.
    %   z_query     - Interpolated z-heights at the query points.
    
    % Read the TIFF data
    TIFF_data = double(imread(stlFileName));
    %remove the offset - can be masked to a CHOICE
    ZI = TIFF_data - min(TIFF_data,[],"all");
    ZI = rot90(ZI,-1);
    
    % Create grid vectors based on the desired resolution
    xi = 1:size(ZI,1)*resolution;
    yi = resolution:resolution:width(TIFF_data)*resolution;

    % Create a meshgrid for interpolation
    [XI, YI] = meshgrid(xi, yi);
    
    ZI(isnan(ZI)) = 0; % Replace all NaN with 0
    
    % Interpolate the z-heights at the query points
    z_query = interp2(XI, YI, ZI, x_query, y_query);
    
    % Create the figure and plot the point cloud
    fig = figure('Visible', 'off', 'Color', 'white'); % Set figure background color to white
    hold on;

    % Plot the surface
    surf(xi, yi, ZI, 'EdgeColor', 'none', 'LineStyle', 'none');
    axis equal;
    axis off; % Turn off the axes visibility
    
    % Set the view to isometric
    view(45, 35.26);

    % Plot the query points as markers
    plot3(x_query, y_query, z_query, 'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'r'); % Red circles

    % Capture the figure as an image matrix
    frame = getframe(fig);
    imageMatrix = frame.cdata;

    % Close the figure
    close(fig);
end

% Example usage:
% [imageMatrix, xi, yi, ZI, Res_orig, z_query] = GenerateTerrainFromSTL('Nordschleife_Exported_From_RoadRunner.stl', 10*100, [5, 10], [5, 10]); 