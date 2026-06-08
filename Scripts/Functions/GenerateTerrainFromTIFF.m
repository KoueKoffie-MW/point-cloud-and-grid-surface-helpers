function [imageMatrix, xi, yi, ZI, z_query] = GenerateTerrainFromTIFF(tiffFileName, resolution, x_query, y_query)
    % GenerateTerrainFromTIFF Processes a TIFF file (e.g. DEM) to generate a surface.
    %
    %   [imageMatrix, xi, yi, ZI, z_query] = GenerateTerrainFromTIFF(tiffFileName, resolution, x_query, y_query)
    %
    % Inputs:
    %   tiffFileName - Name of the TIFF file to be read.
    %   resolution   - Desired grid resolution in meters.
    %   x_query      - x-coordinates for querying z-heights.
    %   y_query      - y-coordinates for querying z-heights.
    %
    % Outputs:
    %   imageMatrix - RGB image of the surface visualization
    %   xi, yi      - Grid vectors for the x and y axes
    %   ZI          - Interpolated Z data (surface heights)
    %   z_query     - Interpolated z-heights at the query points

    % Read the TIFF data
    TIFF_data = double(imread(tiffFileName));

    % Normalize heights (remove offset)
    ZI = TIFF_data - min(TIFF_data, [], "all");

    % Rotate so that the coordinate system matches typical expectations
    ZI = rot90(ZI, -1);

    [nRows, nCols] = size(ZI);

    % Create properly spaced grid vectors
    xi = (0:nCols-1) * resolution;
    yi = (0:nRows-1) * resolution;

    % Create meshgrid for interpolation and plotting
    [XI, YI] = meshgrid(xi, yi);

    % Replace any remaining NaNs with 0
    ZI(isnan(ZI)) = 0;

    % Interpolate z-heights at the query points
    z_query = interp2(XI, YI, ZI, x_query, y_query);

    % === Visualization (hidden figure) ===
    fig = figure('Visible', 'off', 'Color', 'white');
    hold on;

    % Plot the surface
    surf(XI, YI, ZI, 'EdgeColor', 'none', 'LineStyle', 'none');
    axis equal;
    axis off;

    % Isometric view
    view(45, 35.26);

    % Plot query points
    plot3(x_query, y_query, z_query, 'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'r');

    % Capture image
    frame = getframe(fig);
    imageMatrix = frame.cdata;
    close(fig);
end
