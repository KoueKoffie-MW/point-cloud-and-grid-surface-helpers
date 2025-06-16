function imageMatrix = generateSplineCylinder(spline_definition_points, cylinder_radius, num_cloud_points, use_smooth_spline_flag, patchColor, output_filename_base,alpha_mod)
% Generates a point cloud on the surface of a cylinder following a spline path.
% Uses alphaShape for surface triangulation for visualization and STL export.
%
% Inputs:
%   spline_definition_points - 3xN matrix [x;y;z] defining the spline path. (Requires N >= 2)
%   cylinder_radius          - Radius of the cylinder (R).
%   num_cloud_points         - Approx. number of points on the cylinder surface (NUM).
%   use_smooth_spline_flag   - Boolean flag (true for smooth spline, false for polyline).
%   patchColor               - 1x3 RGB color for the surface patch [R G B].
%   output_filename_base     - Base name for the output STL file (string).
%
% Outputs:
%   pointCloud               - Mx3 matrix of the originally generated points.
%   imageMatrix              - HxWx3 matrix of the captured visualization.
%
% Requires:
%   - Curve Fitting Toolbox (for cscvn, ppval, fnder if use_smooth_spline_flag=true)
%   - MATLAB R2018b or later (for built-in stlwrite)

%% --- Input Validation ---
if nargin ~= 7
    error('Function requires 7 input arguments.');
end
% ... (Keep previous input validation checks) ...
if ~ismatrix(spline_definition_points) || size(spline_definition_points, 1) ~= 3 || size(spline_definition_points, 2) < 2
    error('Input `spline_definition_points` must be a 3xN array with N >= 2.');
end
% ... (rest of input validation) ...

input_points = spline_definition_points;
R = cylinder_radius;
NUM = num_cloud_points;
useSmoothSpline = use_smooth_spline_flag;
N_fine = max(1000, 20 * size(input_points, 2));

%% --- Calculate Path Length and Spline Data ---
fprintf('Calculating path definition...\n');
% ... (Keep path length calculation logic) ...
if useSmoothSpline
    try pp = cscvn(input_points); pp_deriv = fnder(pp); catch ME; error('Spline/Derivative error: %s', ME.message); end
    t_fine = linspace(pp.breaks(1), pp.breaks(end), N_fine); fine_points = ppval(pp, t_fine);
    segment_lengths = sqrt(sum(diff(fine_points, 1, 2).^2, 1)); cumulativeLengths = [0, cumsum(segment_lengths)]; totalLength = cumulativeLengths(end);
else
    segment_lengths = sqrt(sum(diff(input_points, 1, 2).^2, 1)); cumulativeLengths = [0, cumsum(segment_lengths)]; totalLength = cumulativeLengths(end);
end
if totalLength < eps, warning('Path length near zero.'); pointCloud = zeros(0, 3); imageMatrix = []; return; end

%% --- Generate Points on Cylinder Surface ---
fprintf('Generating %d points along path...\n', NUM);
% ... (Keep point generation loop logic) ...
pointCloud = zeros(NUM, 3); golden_angle = pi * (3 - sqrt(5));
for j = 1:NUM
    frac = (j - 0.5) / NUM; targetArcLength = frac * totalLength; targetArcLength = max(cumulativeLengths(1), min(cumulativeLengths(end), targetArcLength));
    if useSmoothSpline
        t = interp1(cumulativeLengths, t_fine, targetArcLength, 'linear'); pointOnSpline = ppval(pp, t)'; direction = ppval(pp_deriv, t)';
    else % Polyline logic
        segmentIndex=find(cumulativeLengths>=targetArcLength,1)-1; if isempty(segmentIndex)||(targetArcLength<=cumulativeLengths(1)); segmentIndex=1; localT=0; elseif segmentIndex==0; segmentIndex=1; end; if segmentIndex>size(input_points,2)-1; segmentIndex=size(input_points,2)-1; localT=1; end
        p1=input_points(:,segmentIndex)'; p2=input_points(:,segmentIndex+1)'; if ~(targetArcLength<=cumulativeLengths(1)||(segmentIndex==size(input_points,2)-1&&targetArcLength>=cumulativeLengths(end))); segmentLength=cumulativeLengths(segmentIndex+1)-cumulativeLengths(segmentIndex); if segmentLength>eps; localT=(targetArcLength-cumulativeLengths(segmentIndex))/segmentLength; else; localT=0; end; elseif targetArcLength<=cumulativeLengths(1); localT=0; else; localT=1; end
        pointOnSpline=(1-localT)*p1+localT*p2; direction=p2-p1;
    end
    norm_dir=norm(direction); if norm_dir>eps; direction=direction/norm_dir; else; direction=[1,0,0]; end
    [~,min_idx]=min(abs(direction)); temp_vec=zeros(1,3); temp_vec(min_idx)=1; orthogonal1=cross(direction,temp_vec); norm_orth1=norm(orthogonal1); if norm_orth1>eps; orthogonal1=orthogonal1/norm_orth1; else; temp_vec=zeros(1,3); temp_vec(mod(min_idx,3)+1)=1; orthogonal1=cross(direction,temp_vec); if norm(orthogonal1)>eps; orthogonal1=orthogonal1/norm(orthogonal1); else; orthogonal1=[1,0,0]; end; end; orthogonal2=cross(direction,orthogonal1);
    theta=j*golden_angle; circlePoint=R*(cos(theta)*orthogonal1+sin(theta)*orthogonal2); pointCloud(j,:)=pointOnSpline+circlePoint;
end
fprintf('Finished generating points.\n');

%% --- Create Alpha Shape for Surface Triangulation ---
fprintf('Creating alpha shape from point cloud...\n');
K_alpha = []; V_alpha = []; TR = []; % Initialize
try
    shp = alphaShape(pointCloud(:,1), pointCloud(:,2), pointCloud(:,3));   
    shp = alphaShape(pointCloud(:,1), pointCloud(:,2), pointCloud(:,3),criticalAlpha(shp,'one-region')*alpha_mod);
    fprintf(' Alpha value used: %.4f\n', shp.Alpha);
    [K_alpha, V_alpha] = boundaryFacets(shp); % K_alpha=Faces, V_alpha=Vertices
    fprintf(' Extracted %d boundary facets.\n', size(K_alpha, 1));

    % --- Create triangulation object FOR STLWRITE ---
    if ~isempty(K_alpha) && ~isempty(V_alpha)
        TR = triangulation(K_alpha, V_alpha);
    end
catch alpha_err
    warning('Could not compute alpha shape or triangulation: %s. Surface visualization and STL export might be skipped.', alpha_err.message);
end

%% --- Calculate Consistent Axis Limits ---
minVals = min(spline_definition_points, [], 1); % Find min X, Y, Z
maxVals = max(spline_definition_points, [], 1); % Find max X, Y, Z
center = (minVals + maxVals) / 2;  % Calculate center point
ranges = maxVals - minVals;        % Calculate ranges in X, Y, Z

% Find the largest range across dimensions (ignoring dimensions with no variation)
maxRange = max(ranges(ranges > eps)); % Use eps to handle near-zero ranges
if isempty(maxRange) || maxRange == 0 % Handle case of a single point or flat data
    maxRange = 1.0; % Default range if no variation
end

% Set limits based on the center and half the max range, plus a margin
margin_factor = 0.15; % Add 15% margin (adjust as needed)
half_maxRange_with_margin = (maxRange / 2) * (1 + margin_factor);

common_xlim = [center(1) - half_maxRange_with_margin, center(1) + half_maxRange_with_margin];
common_ylim = [center(2) - half_maxRange_with_margin, center(2) + half_maxRange_with_margin];
common_zlim = [center(3) - half_maxRange_with_margin, center(3) + half_maxRange_with_margin];

%% --- Drawing - Create Figure and Layout ---
fig = figure('Visible', 'off', ... % Keep it invisible while drawing
             'Color', 'white', ...
             'Units', 'pixels', ... % Use pixels for consistent getframe
             'Position', [100, 100, 1000, 1000]); % Adjust Position [left, bottom, width, height] if needed

%% --- Plotting in Subplots ---

% Define common plot properties
titleFontSize = 30; % Define title font size here

% --- Tile 1: Top View (X-Y) ---
ax1 = subplot(2,2,3);  % Get axes handle
hold(ax1, 'on');
trisurf(TR, 'Parent', ax1, 'FaceColor', patchColor, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
hold(ax1, 'off');
view(ax1, 0, 90); % Set view from top
xlim(ax1, common_xlim);
ylim(ax1, common_ylim);
zlim(ax1, common_zlim);
axis(ax1, 'equal'); % Ensure aspect ratio is correct
axis(ax1, 'off');   % Turn off axes lines, ticks, labels
 title(ax1, 'Top (X-Y)', 'FontSize', titleFontSize); % Title optional

% --- Tile 2: Front View (X-Z) ---
ax2 = subplot(2,2,1); 
hold(ax2, 'on');
trisurf(TR, 'Parent', ax2, 'FaceColor', patchColor, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
hold(ax2, 'off');
view(ax2, 0, 0);   % Set view from front
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
view(ax3, 90, 0);  % Set view from side
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
view(ax4, 45, 35.26); % Your original perspective view
xlim(ax4, common_xlim); % Use same limits for consistency, though 'equal' might make it look small
ylim(ax4, common_ylim);
zlim(ax4, common_zlim);
axis(ax4, 'equal');
axis(ax4, 'off');
 title(ax4, 'Perspective', 'FontSize', titleFontSize);

%% --- Capture the figure as an image matrix ---
fprintf('Capturing figure frame...\n');
drawnow; % Ensure drawing is complete before capturing
frame = getframe(fig);
imageMatrix = frame.cdata;
fprintf('Frame captured.\n');

%% --- Close the figure ---
close(fig);
fprintf('Figure closed.\n');

%% --- Save Triangulation as STL file ---
outputDir = 'Data';
% Check if a valid triangulation object was created
if ~isempty(TR)
    fprintf('Saving STL file using triangulation object...\n');
    if ~exist(outputDir, 'dir') % Create directory if needed
        try mkdir(outputDir); fprintf('Created directory: %s\n', outputDir); catch ME_dir; warning('Could not create directory %s: %s. Skipping STL write.', outputDir, ME_dir.message); TR = []; end
    end

    if ~isempty(TR) % Check again in case directory creation failed
        stlFilename = fullfile(outputDir, output_filename_base);
        try
            % Use MATLAB's built-in stlwrite with the triangulation object
            stlwrite(TR, stlFilename); % Default is binary format
            % For text format use: stlwrite(TR, stlFilename, 'text');
            fprintf('STL file saved to: %s\n', stlFilename);
        catch stl_err
            warning('Failed to write STL file using stlwrite: %s', stl_err.message);
        end
    end
else
     warning('Triangulation object is empty (possibly due to alphaShape failure), skipping STL file generation.');
end

fprintf('Function execution finished.\n');

end % End of function