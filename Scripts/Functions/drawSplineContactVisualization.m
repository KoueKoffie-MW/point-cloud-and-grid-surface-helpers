function imageMatrix = drawSplineContactVisualization(inputPoints, R, L, numDisks, drawStyle)
% drawSplineContactVisualization  Creates a 4-view visualization of a spline with contact elements.
%
%   imageMatrix = drawSplineContactVisualization(inputPoints, R, L, numDisks, drawStyle)
%
% Inputs:
%   inputPoints - Nx3 matrix of spline points [x y z]
%   R           - Radius of disks or cylinder
%   L           - Distance between disk centers (used only for 'disks')
%   numDisks    - Number of disks to draw (e.g. 11)
%   drawStyle   - 'disks' or 'cylinder'
%
% Output:
%   imageMatrix - RGB image suitable for MaskDisplay

    arguments
        inputPoints (:,3) double
        R           (1,1) double {mustBePositive}
        L           (1,1) double
        numDisks    (1,1) double {mustBeInteger, mustBePositive}
        drawStyle   (1,1) string {mustBeMember(drawStyle, ["disks","cylinder","single_cylinder"])}
    end

    if isempty(inputPoints) || size(inputPoints,1) < 2
        error('inputPoints must contain at least 2 points.');
    end

    % --- Compute consistent axis limits ---
    minVals = min(inputPoints, [], 1);
    maxVals = max(inputPoints, [], 1);
    center  = (minVals + maxVals) / 2;
    ranges  = maxVals - minVals;
    maxRange = max(ranges(ranges > eps));
    if isempty(maxRange) || maxRange == 0
        maxRange = 1.0;
    end
    margin = 0.15;
    halfRange = (maxRange / 2) * (1 + margin);

    common_xlim = [center(1) - halfRange, center(1) + halfRange];
    common_ylim = [center(2) - halfRange, center(2) + halfRange];
    common_zlim = [center(3) - halfRange, center(3) + halfRange];

    % --- Create figure ---
    fig = figure('Visible', 'off', 'Color', 'white', ...
                 'Units', 'pixels', 'Position', [100, 100, 1000, 1000]);

    pointColor = [0.4667 0.6745 0.1882];
    lineColor  = [0.4667 0.6745 0.1882];
    diskColor  = [0.8500 0.3250 0.0980];   % Orange for disks/cylinder
    titleFontSize = 28;

    % --- Compute disk / cylinder positions ---
    if strcmp(drawStyle, "disks")
        diskCenters = computeDiskCentersAlongSpline(inputPoints, L, numDisks);
    else % cylinder
        diskCenters = []; % Not needed for cylinder mode
    end

    % --- Create 4 views ---
    views = { ...
        struct('title','Top (X-Y)',     'view',[0 90],  'plane','xy'), ...
        struct('title','Front (X-Z)',   'view',[0 0],   'plane','xz'), ...
        struct('title','Side (Y-Z)',    'view',[90 0],  'plane','yz'), ...
        struct('title','Perspective',   'view',[45 35.26], 'plane','3d') ...
    };

    for i = 1:4
        ax = subplot(2,2,i);
        hold(ax, 'on');

        % Draw spline
        plot3(ax, inputPoints(:,1), inputPoints(:,2), inputPoints(:,3), ...
              'Color', lineColor, 'LineWidth', 1.5);

        % Draw contact elements using 3D patches
        if strcmp(drawStyle, "disks")
            drawOrientedDisks3D(ax, diskCenters, R, diskColor, inputPoints);
        elseif strcmp(drawStyle, "cylinder")
            drawCylinder3D(ax, inputPoints, R, diskColor);
        elseif strcmp(drawStyle, "single_cylinder")
            drawSingleCylinder3D(ax, inputPoints, R, L, diskColor);
        end

        % Formatting
        view(ax, views{i}.view);
        xlim(ax, common_xlim);
        ylim(ax, common_ylim);
        zlim(ax, common_zlim);
        axis(ax, 'equal');
        axis(ax, 'off');
        title(ax, views{i}.title, 'FontSize', titleFontSize);

        hold(ax, 'off');
    end

    % Capture image
    drawnow;
    frame = getframe(fig);
    imageMatrix = frame.cdata;
    close(fig);
end

%% --- Helper: Compute disk centers along spline ---
function centers = computeDiskCentersAlongSpline(points, L, numDisks)
    centers = zeros(numDisks, 3);
    centers(1,:) = points(1,:);

    currentDist = 0;
    idx = 1;

    for k = 2:numDisks
        targetDist = (k-1) * L;

        while idx < size(points,1) && currentDist < targetDist
            idx = idx + 1;
            seg = norm(points(idx,:) - points(idx-1,:));
            currentDist = currentDist + seg;
        end

        if idx >= size(points,1)
            centers(k,:) = points(end,:);
        else
            % Interpolate between idx-1 and idx
            prev = points(idx-1,:);
            next = points(idx,:);
            overshoot = currentDist - targetDist;
            t = 1 - (overshoot / norm(next - prev));
            centers(k,:) = prev + t * (next - prev);
        end
    end
end

%% --- Helper: Draw oriented disks using patch (true 3D) ---
function drawOrientedDisks3D(ax, centers, R, color, points)
    for i = 1:size(centers,1)
        c = centers(i,:);

        % Find local tangent
        [~, idx] = min(vecnorm(points - c, 2, 2));
        if idx == 1
            tangent = points(2,:) - points(1,:);
        elseif idx == size(points,1)
            tangent = points(end,:) - points(end-1,:);
        else
            tangent = points(idx+1,:) - points(idx-1,:);
        end
        tangent = tangent / norm(tangent);

        % Create two perpendicular vectors
        if abs(tangent(3)) < 0.9
            perp1 = cross(tangent, [0 0 1]);
        else
            perp1 = cross(tangent, [0 1 0]);
        end
        perp1 = perp1 / norm(perp1);
        perp2 = cross(tangent, perp1);

        % Create circle vertices
        theta = linspace(0, 2*pi, 24);
        verts = c + R * (perp1 .* cos(theta)' + perp2 .* sin(theta)');

        % Draw as patch
        patch(ax, 'XData', verts(:,1), 'YData', verts(:,2), 'ZData', verts(:,3), ...
              'FaceColor', color, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    end
end

%% --- Helper: Draw cylinder using patch ---
function drawCylinder3D(ax, points, R, color)
    % Create a simple tubular surface around the spline
    nTheta = 20;
    theta = linspace(0, 2*pi, nTheta);

    % Very simplified cylinder (constant radius tube)
    for i = 1:size(points,1)-1
        p1 = points(i,:);
        p2 = points(i+1,:);
        dir = p2 - p1;
        if norm(dir) < eps, continue; end
        dir = dir / norm(dir);

        % Create two perpendicular vectors
        if abs(dir(3)) < 0.9
            n1 = cross(dir, [0 0 1]);
        else
            n1 = cross(dir, [0 1 0]);
        end
        n1 = n1 / norm(n1);
        n2 = cross(dir, n1);

        % Create ring vertices
        ring1 = p1 + R * (n1 .* cos(theta)' + n2 .* sin(theta)');
        ring2 = p2 + R * (n1 .* cos(theta)' + n2 .* sin(theta)');

        % Simple quad strip between rings
        for k = 1:nTheta-1
            X = [ring1(k,1), ring2(k,1), ring2(k+1,1), ring1(k+1,1)];
            Y = [ring1(k,2), ring2(k,2), ring2(k+1,2), ring1(k+1,2)];
            Z = [ring1(k,3), ring2(k,3), ring2(k+1,3), ring1(k+1,3)];
            patch(ax, 'XData', X, 'YData', Y, 'ZData', Z, ...
                  'FaceColor', color, 'EdgeColor', 'none', 'FaceAlpha', 0.5);
        end
    end
end
%% --- Helper: Draw single finite cylinder (midpoint on spline) ---
function drawSingleCylinder3D(ax, points, R, L, color)
    if L <= 0 || isempty(points)
        return;
    end

    % Position at L/2 from start
    targetDist = L / 2;
    currentDist = 0;
    idx = 1;

    while idx < size(points,1) && currentDist < targetDist
        idx = idx + 1;
        seg = norm(points(idx,:) - points(idx-1,:));
        currentDist = currentDist + seg;
    end

    if idx >= size(points,1)
        c = points(end,:);
        tangent = points(end,:) - points(end-1,:);
    else
        prev = points(idx-1,:);
        nextP = points(idx,:);
        overshoot = currentDist - targetDist;
        t = 1 - (overshoot / norm(nextP - prev));
        c = prev + t * (nextP - prev);
        tangent = nextP - prev;
    end

    tangent = tangent / norm(tangent);

    % Create two perpendicular vectors for the cylinder orientation
    if abs(tangent(3)) < 0.9
        n1 = cross(tangent, [0 0 1]);
    else
        n1 = cross(tangent, [0 1 0]);
    end
    n1 = n1 / norm(n1);
    n2 = cross(tangent, n1);

    % Create cylinder along the tangent direction (length L)
    halfL = L / 2;
    nTheta = 24;
    theta = linspace(0, 2*pi, nTheta);

    % Two end rings
    ring1 = c - halfL * tangent + R * (n1 .* cos(theta)' + n2 .* sin(theta)');
    ring2 = c + halfL * tangent + R * (n1 .* cos(theta)' + n2 .* sin(theta)');

    % Draw end caps (optional - simple disks)
    patch(ax, 'XData', ring1(:,1), 'YData', ring1(:,2), 'ZData', ring1(:,3), ...
          'FaceColor', color, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    patch(ax, 'XData', ring2(:,1), 'YData', ring2(:,2), 'ZData', ring2(:,3), ...
          'FaceColor', color, 'EdgeColor', 'none', 'FaceAlpha', 0.7);

    % Draw tube between rings
    for k = 1:nTheta-1
        X = [ring1(k,1), ring2(k,1), ring2(k+1,1), ring1(k+1,1)];
        Y = [ring1(k,2), ring2(k,2), ring2(k+1,2), ring1(k+1,2)];
        Z = [ring1(k,3), ring2(k,3), ring2(k+1,3), ring1(k+1,3)];
        patch(ax, 'XData', X, 'YData', Y, 'ZData', Z, ...
              'FaceColor', color, 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    end
end
