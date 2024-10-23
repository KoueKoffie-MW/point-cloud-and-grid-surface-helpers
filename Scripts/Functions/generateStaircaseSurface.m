function [X_grid_vector, Y_grid_vector, Z_heights, imageMatrix, x, z] = generateStaircaseSurface(nSteps, Tread, NosingProtusion, Riser, yWidth, input_angle_degrees, markerColor, patchColor)
    % Convert the input angle to radians
    input_angle_radians = deg2rad(input_angle_degrees);

    % Initialize the sequence array for x
    x = zeros(1, nSteps * 2);

    % Set the initial value for x
    x(1) = 0;

    % Generate the sequence for x
    for n = 2:(nSteps * 2)
        if mod(n, 2) == 0
            % Even index (add Tread)
            x(n) = x(n-1) + Tread;
        else
            % Odd index (subtract NosingProtusion)
            x(n) = x(n-1) - NosingProtusion;
        end
    end

    % Initialize the sequence array for z
    z = zeros(1, nSteps * 2);

    % Generate the sequence for z
    for n = 1:(nSteps * 2)
        % Every two steps, increase the height by one Riser
        z(n) = Riser * floor((n-1)/2);
    end

    % Rotation matrix using the input angle
    R = [cos(input_angle_radians) -sin(input_angle_radians); 
         sin(input_angle_radians)  cos(input_angle_radians)];

    % Apply the rotation to each (x, z) pair
    rotated_coords = R * [x; z];

    % Extract rotated x and z
    x_rotated = rotated_coords(1, :);
    z_rotated = rotated_coords(2, :);

    % Define the y-direction extrusion
    y = [0, yWidth];

    % Create a meshgrid for the surface with rotated x
    [X, Y] = meshgrid(x_rotated, y);
    Z = repmat(z_rotated, length(y), 1);

    % Extract the grid vectors and heights matrix for Simscape Multibody
    X_grid_vector = x_rotated;  % Rotated X grid vector
    Y_grid_vector = y;          % Y grid vector
    Z_heights = Z;              % Adjusted Z heights matrix

    % Plot the unrotated surface
    % Create the figure and plot the point cloud
    fig = figure('Visible', 'off', 'Color', 'white'); % Create the figure without displaying it
    hold on;
    
    [X_unrotated, Y_unrotated] = meshgrid(x, y);
    Z_unrotated = repmat(z, length(y), 1);
    surf(X_unrotated, Y_unrotated, Z_unrotated, 'FaceColor', patchColor, 'EdgeColor', [0, 0, 0]);
    % xlabel('X');
    % ylabel('Y');
    % zlabel('Z');
    % title('Unrotated Staircase Surface');
    
    % Plot the point cloud
    scatter3(X_unrotated, Y_unrotated, Z_unrotated, 30, 'filled', 'MarkerFaceColor', markerColor);
    axis equal;
    axis off; % Turn off the axes visibility
    
    % Set the view to isometric
    view(3);
    
    % Capture the figure as an image matrix
    frame = getframe(fig);
    imageMatrix = frame.cdata;

    % Close the figure
    close(fig);

end