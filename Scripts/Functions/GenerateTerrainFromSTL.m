function [imageMatrix, xi, yi, ZI, Res_orig, z_query] = GenerateTerrainFromSTL(stlFileName, resolution, x_query, y_query, Int_method)
    % GenerateTerrainFromSTL Processes an STL file to generate a surface object with specified resolution.
    %
    %   [imageMatrix, xi, yi, ZI, Res_orig, z_query] = GenerateTerrainFromSTL(stlFileName, resolution, x_query, y_query)
    %
    % Inputs:
    %   stlFileName - Name of the STL file to be read.
    %   resolution  - Desired resolution in meters.
    %   x_query     - x-coordinates for querying z-heights.
    %   y_query     - y-coordinates for querying z-heights.
    %
    % Outputs:
    %   imageMatrix - Mask Image
    %   xi, yi      - Grid vectors for the x and y axes.
    %   ZI          - Interpolated Z data.
    %   Res_orig    - Original resolution of the STL data.
    %   z_query     - Interpolated z-heights at the query points.
    
    % Read the STL data
    STL_data = stlread(stlFileName);
    
    % Extract x, y, and z coordinates
    x = STL_data.Points(:, 1);
    y = STL_data.Points(:, 2);
    z = STL_data.Points(:, 3);
    clear STL_data
    
    % Replace zeros in z with NaN
    z(z == 0) = NaN;
    
    % Identify indices where z is not NaN
    validIndices = ~isnan(z);
    
    % Filter x, y, and z using the valid indices
    x_filtered = x(validIndices);
    y_filtered = y(validIndices);
    z_filtered = z(validIndices);
    
    % Calculate the original resolution
    Data_length = sqrt(length(x_filtered));
    x_length = (-min(x_filtered) + max(x_filtered));
    y_length = (-min(y_filtered) + max(y_filtered));
    Res_orig = [(x_length / Data_length) (y_length / Data_length)];
    
    % Create grid vectors based on the desired resolution
    xi = min(x_filtered):resolution:max(x_filtered);
    yi = min(y_filtered):resolution:max(y_filtered);
    
    % Create a meshgrid for interpolation
    [XI, YI] = meshgrid(xi, yi);
    
    % Interpolate the Z data
    % tic
    ZI = griddata(x_filtered, y_filtered, z_filtered, XI, YI, Int_method);
    % toc
% "linear"	
% "nearest"	
% "natural"	
% "cubic"	
% "v4"	


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