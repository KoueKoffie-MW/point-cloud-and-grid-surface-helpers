function [x, y, z] = createToroidFibonacci(nPoints, R, r, minDist, maxDist)
    % Create a toroidal point cloud using a Fibonacci lattice with distance filtering
    % Inputs:
    %   nPoints - Number of points to generate
    %   R       - Major radius of the toroid
    %   r       - Minor radius of the toroid
    %   minDist - Minimum distance from the origin to keep a point
    %   maxDist - Maximum distance from the origin to keep a point
    % Outputs:
    %   x, y, z - Cartesian coordinates of the filtered points on the toroid

    % Golden angle in radians
    goldenAngle = pi * (3 - sqrt(5));

    % Initialize arrays
    theta = zeros(nPoints, 1);
    phi = zeros(nPoints, 1);

    % Generate points using Fibonacci lattice
    for i = 1:nPoints
        theta(i) = goldenAngle * i; % Angle around the toroid's tube
        phi(i) = 2 * pi * i / nPoints; % Angle around the toroid's ring
    end

    % Convert to Cartesian coordinates
    x = (R + r * cos(theta)) .* cos(phi);
    y = (R + r * cos(theta)) .* sin(phi);
    z = r * sin(theta);

    % Calculate the distance of each point from the origin
    distances = sqrt(x.^2 + y.^2 + z.^2);

    % Filter points based on the specified distance range
    validIndices = (distances >= minDist) & (distances <= maxDist);
    x = x(validIndices);
    y = y(validIndices);
    z = z(validIndices);

    % % Plot the filtered toroid
    % figure;
    % scatter3(x, y, z, 'filled');
    % axis equal;
    % xlabel('X');
    % ylabel('Y');
    % zlabel('Z');
    % title('Filtered Toroid with Fibonacci Lattice');
    % grid on;
end