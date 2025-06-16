function [ptCloud, Z, RA] = processPcdToRasterTiff(pcdFilePath, outputTiffPath, varargin)
%processPcdToRasterTiff Reads PCD (local coords), plots, creates DEM, saves as Float TIFF + World File (.tfw).
% Allows specifying scalar/vector resolution OR matching input point count (anisotropic). Includes diagnostics.
%
%   Syntax:
%   [ptCloud, Z, RA] = processPcdToRasterTiff(pcdFilePath, outputTiffPath, gridResolution, ...) % Mode 'Resolution'
%   [ptCloud, Z, RA] = processPcdToRasterTiff(pcdFilePath, outputTiffPath, 'ControlMode', 'PointCount', ...) % Mode 'PointCount'
%
%   Description:
%   Reads a LOCAL coordinate PCD file. Plots the point cloud. Creates DEM grid (Z)
%   using Lidar Toolbox pc2dem and RA using Mapping Toolbox maprefcells.
%   Writes Z to a floating-point TIFF using Tiff object and creates a .tfw World File.
%
%   Control Modes:
%   - 'Resolution': (Default) User must provide gridResolution (positive scalar for square
%                   pixels OR 1x2 positive vector [resX, resY] for rectangular pixels).
%   - 'PointCount': User should NOT provide gridResolution. Function estimates average
%                   anisotropic point spacing [estX, estY] and uses that as the
%                   effective resolution, aiming for numPixels ≈ numPoints.
%
%   Required Inputs:
%   pcdFilePath     - Path to the input PCD file.
%   outputTiffPath  - Path for the output TIFF/TFW files.
%
%   Optional Input (Mode 'Resolution' Only):
%   gridResolution  - Positive scalar OR 1x2 positive vector [resX, resY].
%                     *Required* if ControlMode is 'Resolution'. *Ignored* if 'PointCount'.
%
%   Optional Name/Value Pairs:
%   'ControlMode'   - 'Resolution' (default) or 'PointCount'. Determines how grid size is set.
%
%   Outputs:
%   ptCloud         - pointCloud object. Loaded data.
%   Z               - Numeric matrix. Calculated DEM grid.
%   RA              - MapCellsReference/MapPostingsReference object. Raster reference.
%
%   Requires: (License checks removed)
%   - Point Cloud Tbx (or equivalent), Lidar Tbx (pc2dem), Mapping Tbx (maprefcells), Statistics Tbx (knnsearch)
%
%   Examples:
%       % --- Mode: Specify Resolution (Square Pixels) ---
%       processPcdToRasterTiff('in.pcd', 'out_res_sq.tif', 0.5);
%
%       % --- Mode: Specify Resolution (Rectangular Pixels) ---
%       processPcdToRasterTiff('in.pcd', 'out_res_rect.tif', [0.4, 0.6]); % X res=0.4, Y res=0.6
%
%       % --- Mode: Match Point Count (Estimate Anisotropic Resolution) ---
%       processPcdToRasterTiff('in.pcd', 'out_pc.tif', 'ControlMode', 'PointCount');

    % --- Input Parsing ---
    p = inputParser;
    p.CaseSensitive = false;
    p.KeepUnmatched = false;

    validateattributes(pcdFilePath, {'char', 'string'}, {'scalartext'}, mfilename, 'pcdFilePath', 1);
    validateattributes(outputTiffPath, {'char', 'string'}, {'scalartext'}, mfilename, 'outputTiffPath', 2);

    % Custom validation function for gridResolution (scalar or 1x2 vector, positive)
    isValidResolution = @(x) isnumeric(x) && isreal(x) && all(isfinite(x)) && ~issparse(x) && (isscalar(x) || (isvector(x) && numel(x)==2)) && all(x > 0);
    defaultResolution = NaN; % Use NaN to check if it was explicitly provided
    addOptional(p, 'gridResolution', defaultResolution, isValidResolution);

    defaultControlMode = 'Resolution';
    validControlModes = {'Resolution', 'PointCount'};
    addParameter(p, 'ControlMode', defaultControlMode, @(x) any(validatestring(x, validControlModes)));

    parse(p, varargin{:});
    controlMode = p.Results.ControlMode;
    userGridResolution = p.Results.gridResolution;

    % Validate inputs based on ControlMode
    if strcmpi(controlMode, 'Resolution')
        if isequaln(userGridResolution, defaultResolution) % Check if default NaN value is still there
             error('Grid resolution (scalar or 1x2 vector) must be provided when ControlMode is ''Resolution''.');
        end
        effectiveResolution = userGridResolution; % Can be scalar or 1x2 vector
        if isscalar(effectiveResolution)
            fprintf('Using ControlMode: Resolution (User specified: %g for X and Y)\n', effectiveResolution);
        else
            fprintf('Using ControlMode: Resolution (User specified: [%g, %g] for X, Y)\n', effectiveResolution(1), effectiveResolution(2));
        end
    elseif strcmpi(controlMode, 'PointCount')
        if ~isequaln(userGridResolution, defaultResolution)
            warning('Grid resolution input is ignored when ControlMode is ''PointCount''.');
        end
        fprintf('Using ControlMode: PointCount (Estimating anisotropic resolution)\n');
        effectiveResolution = NaN; % Placeholder, calculated after loading PCD
    end

    % --- License Checks Removed ---
    % Note: Requires Statistics and Machine Learning Toolbox for knnsearch

    % --- 1. Read PCD File ---
    fprintf('Reading PCD file: %s\n', pcdFilePath);
    if ~isfile(pcdFilePath)
        error('Input PCD file not found: %s', pcdFilePath);
    end
    try
        ptCloud = pcread(pcdFilePath);
        fprintf('Point cloud loaded successfully (%d points).\n', ptCloud.Count);

        % --- DIAGNOSTIC: Check Input Z Range ---
        % ... (diagnostic code remains the same) ...
        if ptCloud.Count > 0
            minZ_in = min(ptCloud.Location(:,3));
            maxZ_in = max(ptCloud.Location(:,3));
            rangeZ_in = maxZ_in - minZ_in;
            fprintf('DEBUG: Input PtCloud Z Stats: Min=%.4f, Max=%.4f, Range=%.4f\n', minZ_in, maxZ_in, rangeZ_in);
        else
            fprintf('DEBUG: Input PtCloud is empty.\n');
        end

    catch ME
        error('Failed to read PCD file "%s": %s', pcdFilePath, ME.message);
    end

    % --- Calculate Effective Resolution if in PointCount mode ---
    if strcmpi(controlMode, 'PointCount')
        if ptCloud.Count < 2 % Need at least 2 points for nearest neighbor
            error('Cannot use ControlMode ''PointCount'' with fewer than 2 points.');
        end

        fprintf('Estimating average point spacing using nearest neighbors...\n');
        try
            % Use a sample for large clouds for efficiency
            numSamples = min(5000, ptCloud.Count); % Sample size limit
            sampleIndices = randperm(ptCloud.Count, numSamples);
            samplePoints = ptCloud.Location(sampleIndices, :);

            % Find the index of the nearest neighbor for each sample point
            % K=2 finds itself and the nearest one
            [idx, ~] = knnsearch(ptCloud.Location, samplePoints, 'K', 2);

            % Get coordinates of the neighbors (second column of idx)
            neighborPoints = ptCloud.Location(idx(:, 2), :);

            % Calculate differences
            deltaCoords = samplePoints - neighborPoints;

            % Estimate spacing as median absolute difference (robust to outliers)
            estSpacingX = median(abs(deltaCoords(:, 1)));
            estSpacingY = median(abs(deltaCoords(:, 2)));

            % Handle potential zero spacing (e.g., duplicate points)
            epsVal = eps(class(ptCloud.Location)); % Machine epsilon for data type
            estSpacingX = max(estSpacingX, epsVal);
            estSpacingY = max(estSpacingY, epsVal);

            effectiveResolution = [estSpacingX, estSpacingY];
            fprintf('Estimated effective resolution [X, Y] for PointCount mode: [%g, %g]\n', effectiveResolution(1), effectiveResolution(2));

        catch ME_knn
            error('Failed to estimate resolution using nearest neighbors: %s', ME_knn.message);
        end
    end

    % --- 2. Plot Point Cloud ---
    % ... (plotting code remains the same) ...
     fprintf('Plotting point cloud...\n');
    try
        figure; % Create a new figure window for the point cloud
        pcshow(ptCloud);
        title(['Point Cloud (Local Coords): ', pcdFilePath], 'Interpreter', 'none');
        xlabel('Local X'); ylabel('Local Y'); zlabel('Local Z (Elevation)');
        axis equal;
        drawnow;
    catch ME
        warning('Could not plot the point cloud: %s', ME.message);
    end


    % --- 3. Create DEM and RA using the effectiveResolution ---
    % Print the resolution actually being used by pc2dem
    if isscalar(effectiveResolution)
        fprintf('Creating DEM grid with effective resolution: %g (X and Y)\n', effectiveResolution);
    else
        fprintf('Creating DEM grid with effective resolution: [%g, %g] (X, Y)\n', effectiveResolution(1), effectiveResolution(2));
    end

    try
        % pc2dem handles both scalar and 1x2 vector for resolution
        [Z_dem, xLimits, yLimits] = pc2dem(ptCloud, effectiveResolution);
        fprintf('DEM grid created (%d x %d cells).\n', size(Z_dem, 1), size(Z_dem, 2));

        fprintf('Creating raster reference object (RA) from limits...\n');
        RA = maprefcells(xLimits, yLimits, size(Z_dem), 'ColumnsStartFrom','north');
        fprintf('RA object created successfully (Class: %s).\n', class(RA));

        % --- Add confirmation printout for RA cell extent ---
        fprintf('DEBUG: RA Cell Extent (Pixel Size): X=%.6f, Y=%.6f\n', RA.CellExtentInWorldX, RA.CellExtentInWorldY);
        % --- End confirmation printout ---

        % --- DIAGNOSTIC: Check Output Z_dem Range and Visualize ---
        % ... (diagnostic code remains the same) ...
        minElev = min(Z_dem(:));
        maxElev = max(Z_dem(:));
        rangeElev = maxElev - minElev;
        fprintf('DEBUG: DEM (Z_dem) Elevation Stats: Min=%.4f, Max=%.4f, Range=%.4f\n', minElev, maxElev, rangeElev);

        figure; % Create a new figure window for the DEM
        imagesc(xLimits, yLimits, Z_dem);
        set(gca,'YDir','normal');
        axis equal tight; colorbar;
        title('DEM Grid (Z\_dem) - Scaled Colors');
        xlabel('Local X'); ylabel('Local Y');
        fprintf('DEBUG: Displaying Z_dem using imagesc scaled to its own range.\n');
        % --- End DIAGNOSTIC ---

    catch ME
         % ... Error handling for Step 3 ...
         if contains(ME.identifier, 'pc2dem', 'IgnoreCase', true)
             error('Failed to create DEM using pc2dem: %s', ME.message);
        elseif contains(ME.identifier, 'maprefcells', 'IgnoreCase', true)
             error('Failed to create RA object using maprefcells: %s', ME.message);
        else
            error('Error during DEM/RA creation: %s', ME.message);
        end
    end

    % --- 4. Write Float TIFF using Tiff object and create World File (.tfw) ---
    % ... (TIFF and TFW writing code remains the same, uses correct pixelSizeX/Y) ...
     fprintf('Writing floating-point TIFF file using Tiff object: %s\n', outputTiffPath);
    try
        % --- 4a. Write TIFF using Tiff object ---
        t = Tiff(outputTiffPath, 'w');
        tagstruct.ImageLength = size(Z_dem, 1);
        tagstruct.ImageWidth = size(Z_dem, 2);
        tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
        tagstruct.BitsPerSample = 32;
        tagstruct.SamplesPerPixel = 1;
        tagstruct.SampleFormat = Tiff.SampleFormat.IEEEFP;
        tagstruct.RowsPerStrip = 16;
        tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
        tagstruct.Software = 'MATLAB Tiff object';
        t.setTag(tagstruct);
        t.write(Z_dem);
        t.close();
        fprintf('Floating-point TIFF file written successfully.\n');

        % --- 4b. Create World File (.tfw) ---
        [~, baseName, ~] = fileparts(outputTiffPath);
        tfwFilename = fullfile(fileparts(outputTiffPath), [baseName, '.tfw']);
        fprintf('Creating World File: %s\n', tfwFilename);
        pixelSizeX = RA.CellExtentInWorldX;
        pixelSizeY = RA.CellExtentInWorldY;
        topLeftXCenter = RA.XWorldLimits(1) + pixelSizeX / 2; % Corrected variable name
        topLeftYCenter = RA.YWorldLimits(2) - pixelSizeY / 2; % Corrected variable name
        fileID = fopen(tfwFilename, 'w');
        if fileID == -1
            error('Could not open file %s for writing.', tfwFilename);
        end
        fprintf(fileID, '%.10f\n', pixelSizeX);
        fprintf(fileID, '%.10f\n', 0);
        fprintf(fileID, '%.10f\n', 0);
        fprintf(fileID, '%.10f\n', -pixelSizeY);
        fprintf(fileID, '%.10f\n', topLeftXCenter);
        fprintf(fileID, '%.10f\n', topLeftYCenter);
        fclose(fileID);
        fprintf('World File written successfully.\n');

    catch ME
         % ... Error handling for Step 4 ...
        if contains(ME.identifier, 'MATLAB:imagesci:Tiff', 'IgnoreCase', true)
             error('Failed to write TIFF file "%s" using Tiff object: %s', outputTiffPath, ME.message);
        elseif contains(ME.identifier, 'fopen', 'IgnoreCase', true) || contains(ME.identifier, 'fprintf', 'IgnoreCase', true)
            error('Failed to write World File "%s": %s', tfwFilename, ME.message);
        else
            error('Error during TIFF/World File writing: %s', ME.message);
        end
    end

    % Assign Z_dem to output Z
    Z = Z_dem;

    fprintf('Function finished.\n');

end