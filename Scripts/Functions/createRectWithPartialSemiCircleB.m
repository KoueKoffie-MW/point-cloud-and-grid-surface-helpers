function [yPoints, xPoints] = createRectWithPartialSemiCircleB(width, height, radius, circleOffset,RII)
    % Create a set of 2D points representing a rectangle with a partial semi-circular cut-out
    % Inputs:
    %   width        - Width of the rectangle
    %   height       - Height of the rectangle
    %   radius       - Radius of the semi-circular cut-out
    %   circleOffset - Vertical offset of the circle's center from the rectangle's upper boundary
    % Outputs:
    %   xPoints - X coordinates of the shape
    %   yPoints - Y coordinates of the shape

    % Rectangle points (without the bottom part)
    xRect = [width/2, width/2, -width/2, -width/2];
    yRect = [0, -height, -height,0];

    % Semi-circle points
    theta = linspace(pi, 2*pi, 360); % Angle for semi-circle
    xSemiCircle = radius * cos(theta);
    ySemiCircle = radius * sin(theta) + circleOffset - height/2;
    % figure;
    % plot(xSemiCircle, ySemiCircle, '-o');

    % Determine the intersection points of the semi-circle with the rectangle's width
    xIntersect = linspace(-radius, radius, 360);
    yIntersect = sqrt(radius^2 - xIntersect.^2) - circleOffset;
    validIndices = yIntersect >= -circleOffset/20; % Only keep points above the x-axis (With a 1mm oversampling)
    % figure;
    % plot(xIntersect(validIndices), -yIntersect(validIndices), '-o');

    % Combine points
    xPoints = [xRect, xIntersect(validIndices)];
    yPoints = [yRect, -yIntersect(validIndices)];
    yPoints = clip(yPoints,-height,0);

    % Close the shape by connecting the end of the semi-circle to the start of the rectangle
    xPoints = [xPoints, xRect(1)];
    yPoints = [yPoints, yRect(1)];
    % xPoints = flip(xPoints);
    % yPoints = flip(yPoints);
    xPoints = xPoints(2:end);
    yPoints = yPoints(2:end);
    yPoints = yPoints-min(yPoints);
    yPoints = yPoints+RII;

    % % Plot the shape for visualization
    % figure;
    % plot(xPoints, yPoints, '-o');
    % axis equal;
    % grid on;
    % xlabel('X');
    % ylabel('Y');
    % title('Rectangle with Partial Semi-Circular Cut-Out');
    % % comet(xPoints, yPoints)
end