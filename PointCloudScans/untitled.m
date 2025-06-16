function [ptCloud, Z, RA] = processPcdToGeoTiff(pcdFilePath, outputTiffPath, gridResolution, epsgCode)
%processPcdToGeoTiff Reads a PCD file, plots it, creates a DEM, and saves as GeoTIFF.
%
%   Syntax:
%   [ptCloud, Z, RA] = processPcdToGeoTiff(pcdFilePath, outputTiffPath, gridResolution, epsgCode)
%
%   Description:
%   Reads a Point Cloud Data (PCD) file specified by pcdFilePath.
%   Plots the point cloud in a new figure window.
%   Creates a Digital Elevation Model (DEM) grid (Z) and its raster
%   reference object (RA) from the point cloud using the specified
%   gridResolution. By default, pc2dem uses the maximum elevation in each cell.
%   Writes the DEM grid (Z) to a GeoTIFF file specified by outputTiffPath,
%   using the Coordinate Reference System (CRS) defined by epsgCode.
%
%   Inputs:
%   pcdFilePath     - Character vector or string scalar. Path to the input PCD file.
%   outputTiffPath  - Character vector or string scalar. Path for the output GeoTIFF file.
%   gridResolution  - Numeric scalar. The resolution (cell size) of the output DEM grid
%                     in the units of the point cloud's coordinates (e.g., meters).
%   epsgCode        - Numeric scalar. The EPSG code defining the Coordinate
%                     Reference System (CRS) of the point cloud data.
%
%   Outputs:
%   ptCloud         - pointCloud object. The loaded point cloud data.
%   Z               - Numeric matrix. The calculated DEM elevation grid.
%   RA              - MapCellsReference or MapPostingsReference object. The raster
%                     reference object for the DEM grid Z.
%
%   Requires:
%   - MATLAB Point Cloud Toolbox (for pcread, pcshow)
%   - MATLAB Mapping Toolbox (for pc2dem, projcrs, geotiffwrite)
%
%   Example:
%       % Define inputs
%       pcdFile = 'myCloud.pcd';
%       tifFile = 'myDEM.tif';
%       resolution = 0.5; % meters
%       epsg = 32632;     % WGS 84 / UTM zone 32N - CHANGE AS NEEDED!
%
%       % Run the function
%       [ptCloud, Z, RA] = processPcdToGeoTiff(pcdFile, tifFile, resolution, epsg);

    % --- Input Validation (Basic) ---
    if ~ischar(pcdFilePath) && ~isstring(pcdFilePath)
        error('pcdFilePath must be a character vector or string.');
    end
    if ~ischar(outputTiffPath) && ~isstring(outputTiffPath)
        error('outputTiffPath must be a character vector or string.');
    end
    if ~isnumeric(gridResolution) || ~isscalar(gridResolution) || gridResolution <= 0
        error('gridResolution must be a positive numeric scalar.');
    end
    if ~isnumeric(epsgCode) || ~isscalar(epsgCode)
         error('epsgCode must be a numeric scalar.');
    end

    % --- Check for required toolboxes ---
    if ~license('test', 'MAP_Toolbox')
        error('Mapping Toolbox license is required for pc2dem, projcrs, and geotiffwrite.');
    end
     if ~license('test', 'Point_Cloud_Toolbox') % Or 'Computer_Vision_Toolbox' in older versions
        error('Point Cloud Toolbox (or Computer Vision System Toolbox) license is required for pcread and pcshow.');
    end


    % --- 1. Read PCD File ---
    fprintf('Reading PCD file: %s\n', pcdFilePath);
    if ~isfile(pcdFilePath)
        error('Input PCD file not found: %s', pcdFilePath);
    end
    try
        ptCloud = pcread(pcdFilePath);
        fprintf('Point cloud loaded successfully (%d points).\n', ptCloud.Count);
    catch ME
        error('Failed to read PCD file "%s": %s', pcdFilePath, ME.message);
    end

    % --- 2. Plot Point Cloud ---
    fprintf('Plotting point cloud...\n');
    try
        figure; % Create a new figure window
        pcshow(ptCloud);
        title(['Point Cloud: ', pcdFilePath], 'Interpreter', 'none'); % Prevent underscores being treated as subscripts
        xlabel('X'); ylabel('Y'); zlabel('Z');
        drawnow; % Ensure plot is updated
    catch ME
        warning('Could not plot the point cloud: %s', ME.message);
    end

    % --- 3. Create DEM ---
    fprintf('Creating DEM with grid resolution: %g\n', gridResolution);
    try
        % Using default 'max' method for elevation - change if needed
        [Z, RA] = pc2dem(ptCloud, gridResolution);
        fprintf('DEM grid created (%d x %d cells).\n', size(Z, 1), size(Z, 2));
    catch ME
        error('Failed to create DEM using pc2dem: %s', ME.message);
    end

    % --- 4. Define Coordinate Reference System (CRS) ---
    fprintf('Defining CRS using EPSG:%d\n', epsgCode);
    try
        geoCRS = projcrs(epsgCode);
    catch ME
        error('Failed to create projection CRS for EPSG code %d. Is the code valid and Mapping Toolbox database up to date? Error: %s', epsgCode, ME.message);
    end

    % --- 5. Write GeoTIFF File ---
    fprintf('Writing GeoTIFF file: %s\n', outputTiffPath);
    try
        % Use 'CoordRefSysCode' for potentially wider compatibility,
        % although passing the geoCRS object directly might work in newer versions.
        % Check your MATLAB version's geotiffwrite documentation if needed.
        geotiffwrite(outputTiffPath, Z, RA, 'CoordRefSysCode', geoCRS);
        fprintf('GeoTIFF file written successfully.\n');
    catch ME
        error('Failed to write GeoTIFF file "%s": %s', outputTiffPath, ME.message);
    end

    fprintf('Function finished.\n');

end