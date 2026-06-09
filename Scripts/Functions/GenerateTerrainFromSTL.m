function [imageMatrix, xi, yi, ZI, Res_orig, z_query] = GenerateTerrainFromSTL(stlFileName, resolution, x_query, y_query, Int_method, generateImage)

    if nargin < 6
        generateImage = true;
    end

    % GenerateTerrainFromSTL Processes an STL file to generate a surface with specified resolution.
    %
    %   [imageMatrix, xi, yi, ZI, Res_orig, z_query] = GenerateTerrainFromSTL(stlFileName, resolution, x_query, y_query, Int_method, generateImage)
    %
    % Inputs:
    %   stlFileName - Name of the STL file to be read.
    %   resolution  - Desired resolution in meters.
    %   x_query     - x-coordinates for querying z-heights.
    %   y_query     - y-coordinates for querying z-heights.
    %   Int_method  - Interpolation method ('linear', 'nearest', 'natural', 'cubic', 'v4')
    %                 Note: 'cubic' and 'v4' (bi-harmonic) are slower as they fall back to griddata.
    %   generateImage - If false, skips figure creation (default = true)
    %
    % Outputs:
    %   imageMatrix - RGB image of the surface visualization
    %   xi, yi      - Grid vectors for the x and y axes
    %   ZI          - Interpolated Z data
    %   Res_orig    - Estimated original resolution of the STL data
    %   z_query     - Interpolated z-heights at the query points

    % Read the STL data
    STL_data = stlread(stlFileName);

    % Extract coordinates
    x = STL_data.Points(:, 1);
    y = STL_data.Points(:, 2);
    z = STL_data.Points(:, 3);
    clear STL_data

    % Replace zeros in z with NaN
    z(z == 0) = NaN;

    % Filter valid points
    validIndices = ~isnan(z);
    x_filtered = x(validIndices);
    y_filtered = y(validIndices);
    z_filtered = z(validIndices);

    % Estimate original resolution
    Data_length = sqrt(length(x_filtered));
    x_length = max(x_filtered) - min(x_filtered);
    y_length = max(y_filtered) - min(y_filtered);
    Res_orig = [x_length / Data_length, y_length / Data_length];

    % Create grid vectors
    xi = min(x_filtered):resolution:max(x_filtered);
    yi = min(y_filtered):resolution:max(y_filtered);

    % Create meshgrid
    [XI, YI] = meshgrid(xi, yi);

    % Interpolate Z data
    if ismember(Int_method, {'cubic','v4'})
        % These methods are only supported by griddata (slower)
        ZI = griddata(x_filtered, y_filtered, z_filtered, XI, YI, Int_method);
    else
        % Faster path using scatteredInterpolant
        F = scatteredInterpolant(x_filtered, y_filtered, z_filtered, Int_method);
        ZI = F(XI, YI);
    end

    ZI(isnan(ZI)) = 0; % Replace all NaN with 0

    % Interpolate at query points
    z_query = interp2(XI, YI, ZI, x_query, y_query);

    if generateImage
        % === Visualization ===
        fig = figure('Visible', 'off', 'Color', 'white');
        hold on;

        % Use full grids for surf (more robust)
        surf(XI, YI, ZI, 'EdgeColor', 'none', 'LineStyle', 'none');
        axis equal;
        axis off;
        view(45, 35.26);

        % Plot query points
        plot3(x_query, y_query, z_query, 'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'r');

        % Capture image
        frame = getframe(fig);
        imageMatrix = frame.cdata;
        close(fig);
    else
        if ~exist('imageMatrix','var')
            imageMatrix = [];
        end
    end
end
