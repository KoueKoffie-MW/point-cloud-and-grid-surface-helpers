function imageMatrix = generateSplineCylinder(spline_definition_points, cylinder_radius, num_cloud_points, use_smooth_spline_flag, patchColor, output_filename_base, alpha_mod, createSurface, createSTL)
% Generates a point cloud on the surface of a cylinder following a spline path.
% Uses alphaShape for surface triangulation for visualization and STL export.
%
% NOTE: This function uses traditional nargin-style input validation
% instead of the 'arguments' block because it is intended to be called
% from Simulink mask initialization, which has limited support for the
% modern arguments block with validation attributes.

    if nargin < 9
        createSTL = true;
    end
    if nargin < 8
        createSurface = true;
    end

    %% --- Input Validation ---
    if ~ismatrix(spline_definition_points) || size(spline_definition_points, 1) ~= 3 || size(spline_definition_points, 2) < 2
        error('Input `spline_definition_points` must be a 3xN array with N >= 2.');
    end
    if cylinder_radius <= 0
        error('cylinder_radius must be positive.');
    end
    if num_cloud_points < 1
        error('num_cloud_points must be at least 1.');
    end

    input_points = spline_definition_points;
    R = cylinder_radius;
    NUM = num_cloud_points;
    useSmoothSpline = use_smooth_spline_flag;
    N_fine = max(1000, 20 * size(input_points, 2));

    %% --- Calculate Path Length and Spline Data ---
    fprintf('Calculating path definition...\n');
    if useSmoothSpline
        try
            pp = cscvn(input_points);
            pp_deriv = fnder(pp);
        catch ME
            error('Spline/Derivative error: %s', ME.message);
        end
        t_fine = linspace(pp.breaks(1), pp.breaks(end), N_fine);
        fine_points = ppval(pp, t_fine);
        segment_lengths = sqrt(sum(diff(fine_points, 1, 2).^2, 1));
        cumulativeLengths = [0, cumsum(segment_lengths)];
        totalLength = cumulativeLengths(end);
    else
        segment_lengths = sqrt(sum(diff(input_points, 1, 2).^2, 1));
        cumulativeLengths = [0, cumsum(segment_lengths)];
        totalLength = cumulativeLengths(end);
    end

    if totalLength < eps
        warning('Path length near zero.');
        imageMatrix = [];
        return;
    end

    %% --- Generate Points on Cylinder Surface ---
    fprintf('Generating %d points along path...\n', NUM);
    pointCloud = zeros(NUM, 3);
    golden_angle = pi * (3 - sqrt(5));

    for j = 1:NUM
        frac = (j - 0.5) / NUM;
        targetArcLength = frac * totalLength;
        targetArcLength = max(cumulativeLengths(1), min(cumulativeLengths(end), targetArcLength));

        if useSmoothSpline
            t = interp1(cumulativeLengths, t_fine, targetArcLength, 'linear');
            pointOnSpline = ppval(pp, t)';
            direction = ppval(pp_deriv, t)';
        else
            segmentIndex = find(cumulativeLengths >= targetArcLength, 1) - 1;
            if isempty(segmentIndex) || (targetArcLength <= cumulativeLengths(1))
                segmentIndex = 1;
                localT = 0;
            elseif segmentIndex == 0
                segmentIndex = 1;
            end
            if segmentIndex > size(input_points, 2) - 1
                segmentIndex = size(input_points, 2) - 1;
                localT = 1;
            end
            if ~(targetArcLength <= cumulativeLengths(1) || (segmentIndex == size(input_points, 2) - 1 && targetArcLength >= cumulativeLengths(end)))
                segmentLength = cumulativeLengths(segmentIndex + 1) - cumulativeLengths(segmentIndex);
                if segmentLength > eps
                    localT = (targetArcLength - cumulativeLengths(segmentIndex)) / segmentLength;
                else
                    localT = 0;
                end
            elseif targetArcLength <= cumulativeLengths(1)
                localT = 0;
            else
                localT = 1;
            end
            p1 = input_points(:, segmentIndex)';
            p2 = input_points(:, segmentIndex + 1)';
            pointOnSpline = (1 - localT) * p1 + localT * p2;
            direction = p2 - p1;
        end

        [orthogonal1, orthogonal2] = getOrthogonalVectors(direction);
        theta = j * golden_angle;
        circlePoint = R * (cos(theta) * orthogonal1 + sin(theta) * orthogonal2);
        pointCloud(j, :) = pointOnSpline + circlePoint;
    end
    fprintf('Finished generating points.\n');

    %% --- Create Alpha Shape for Surface Triangulation ---
    K_alpha = [];
    V_alpha = [];
    TR = [];

    if createSurface
        fprintf('Creating alpha shape from point cloud...\n');
        try
            shp = alphaShape(pointCloud(:,1), pointCloud(:,2), pointCloud(:,3));
            shp = alphaShape(pointCloud(:,1), pointCloud(:,2), pointCloud(:,3), criticalAlpha(shp, 'one-region') * alpha_mod);
            fprintf(' Alpha value used: %.4f\n', shp.Alpha);
            [K_alpha, V_alpha] = boundaryFacets(shp);
            fprintf(' Extracted %d boundary facets.\n', size(K_alpha, 1));
        catch
            warning('Alpha shape creation failed.');
        end
    end

    %% --- Create triangulation object FOR STLWRITE ---
    if createSTL && ~isempty(K_alpha) && ~isempty(V_alpha)
        TR = triangulation(K_alpha, V_alpha);
    end

    %% --- Calculate Consistent Axis Limits ---
    minVals = min(spline_definition_points, [], 2);
    maxVals = max(spline_definition_points, [], 2);
    center = (minVals + maxVals) / 2;
    ranges = maxVals - minVals;

    maxRange = max(ranges(ranges > eps));
    if isempty(maxRange) || maxRange == 0
        maxRange = 1.0;
    end

    margin_factor = 0.15;
    half_maxRange_with_margin = (maxRange / 2) * (1 + margin_factor);

    common_xlim = [center(1) - half_maxRange_with_margin, center(1) + half_maxRange_with_margin];
    common_ylim = [center(2) - half_maxRange_with_margin, center(2) + half_maxRange_with_margin];
    common_zlim = [center(3) - half_maxRange_with_margin, center(3) + half_maxRange_with_margin];

    %% --- Drawing - Create Figure and Layout ---
    fig = figure('Visible', 'off', ...
                 'Color', 'white', ...
                 'Units', 'pixels', ...
                 'Position', [100, 100, 1000, 1000]);

    %% --- Plotting in Subplots ---
    titleFontSize = 30;

    % --- Tile 1: Top View (X-Y) ---
    ax1 = subplot(2,2,3);
    hold(ax1, 'on');
    trisurf(TR, 'Parent', ax1, 'FaceColor', patchColor, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    hold(ax1, 'off');
    view(ax1, 0, 90);
    xlim(ax1, common_xlim);
    ylim(ax1, common_ylim);
    zlim(ax1, common_zlim);
    axis(ax1, 'equal');
    axis(ax1, 'off');
    title(ax1, 'Top (X-Y)', 'FontSize', titleFontSize);

    % --- Tile 2: Front View (X-Z) ---
    ax2 = subplot(2,2,1);
    hold(ax2, 'on');
    trisurf(TR, 'Parent', ax2, 'FaceColor', patchColor, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    hold(ax2, 'off');
    view(ax2, 0, 0);
    xlim(ax2, common_xlim);
    ylim(ax2, common_ylim);
    zlim(ax2, common_zlim);
    axis(ax2, 'equal');
    axis(ax2, 'off');
    title(ax2, 'Front (X-Z)', 'FontSize', titleFontSize);

    % --- Tile 3: Side View (Y-Z) ---
    ax3 = subplot(2,2,2);
    hold(ax3, 'on');
    trisurf(TR, 'Parent', ax3, 'FaceColor', patchColor, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    hold(ax3, 'off');
    view(ax3, 90, 0);
    xlim(ax3, common_xlim);
    ylim(ax3, common_ylim);
    zlim(ax3, common_zlim);
    axis(ax3, 'equal');
    axis(ax3, 'off');
    title(ax3, 'Side (Y-Z)', 'FontSize', titleFontSize);

    % --- Tile 4: Perspective View ---
    ax4 = subplot(2,2,4);
    hold(ax4, 'on');
    trisurf(TR, 'Parent', ax4, 'FaceColor', patchColor, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    hold(ax4, 'off');
    view(ax4, 45, 35.26);
    xlim(ax4, common_xlim);
    ylim(ax4, common_ylim);
    zlim(ax4, common_zlim);
    axis(ax4, 'equal');
    axis(ax4, 'off');
    title(ax4, 'Perspective', 'FontSize', titleFontSize);

    %% --- Capture the figure as an image matrix ---
    fprintf('Capturing figure frame...\n');
    drawnow;
    imgFrame = getframe(fig);
    imageMatrix = imgFrame.cdata;
    fprintf('Frame captured.\n');

    %% --- Close the figure ---
    close(fig);
    fprintf('Figure closed.\n');

    %% --- Save Triangulation as STL file ---
    outputDir = 'Data';
    if ~isempty(TR)
        fprintf('Saving STL file using triangulation object...\n');
        if ~exist(outputDir, 'dir')
            try
                mkdir(outputDir);
                fprintf('Created directory: %s\n', outputDir);
            catch ME_dir
                warning('Could not create directory %s: %s. Skipping STL write.', outputDir, ME_dir.message);
                TR = [];
            end
        end

        if ~isempty(TR)
            stlFilename = fullfile(outputDir, output_filename_base);
            try
                stlwrite(TR, stlFilename);
                fprintf('STL file saved to: %s\n', stlFilename);
            catch
                warning('Failed to write STL file.');
            end
        end
    end

    fprintf('Function execution finished.\n');
end

%% --- Helper: Get two perpendicular vectors to a direction ---
function [orthogonal1, orthogonal2] = getOrthogonalVectors(direction)
    norm_dir = norm(direction);
    if norm_dir > eps
        direction = direction / norm_dir;
    else
        direction = [1, 0, 0];
    end

    [~, min_idx] = min(abs(direction));
    temp_vec = zeros(1, 3);
    temp_vec(min_idx) = 1;

    orthogonal1 = cross(direction, temp_vec);
    norm_orth1 = norm(orthogonal1);

    if norm_orth1 > eps
        orthogonal1 = orthogonal1 / norm_orth1;
    else
        temp_vec = zeros(1, 3);
        temp_vec(mod(min_idx, 3) + 1) = 1;
        orthogonal1 = cross(direction, temp_vec);
        if norm(orthogonal1) > eps
            orthogonal1 = orthogonal1 / norm(orthogonal1);
        else
            orthogonal1 = [1, 0, 0];
        end
    end

    orthogonal2 = cross(direction, orthogonal1);
end