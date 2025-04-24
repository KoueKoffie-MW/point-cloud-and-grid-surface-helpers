function [output_points, output_directions, output_angles] = findPointsNearClosest(spline_xyz, target_point, point_distance)
%findPointsNearClosest Finds 11 points on a spline centered around the closest point to a target.
%   Uses target_point to find an initial guess parameter t_guess before optimization.
%
%   [output_points, output_directions, output_angles] = findPointsNearClosest(spline_xyz, target_point, point_distance)
%
%   Inputs:
%       spline_xyz     - 3xN array defining the spline path [x; y; z]. Requires N >= 2.
%       target_point   - 1x3 array for the target point in space [xt, yt, zt].
%       point_distance - Scalar defining the desired distance *along the spline*
%                        between consecutive output points. Must be positive.
%
%   Outputs:
%       output_points    - 11x3 array of the calculated points on the spline.
%                          Row 6 is the point closest to target_point. Rows
%                          outside the spline bounds will be NaN.
%       output_directions- 11x3 array of the normalized tangent direction vectors
%                          at each output point. [NaN, NaN, NaN] if outside bounds
%                          or if derivative is zero.
%       output_angles    - 11x3 array of orientation angles [Rx, Ry, Rz] in radians.
%                          Rx (Roll) is assumed 0. Ry (Pitch) is the elevation angle.
%                          Rz (Yaw) is the azimuth angle. [NaN, NaN, NaN] if direction
%                          cannot be determined.
%
%   Requires: Curve Fitting Toolbox (for cscvn, ppval, fnder)
%             Optimization Toolbox (for fminbnd)

% --- Input Validation ---
if nargin ~= 3
    error('Requires 3 input arguments: spline_xyz (3xN), target_point (1x3), point_distance (scalar)');
end
if ~ismatrix(spline_xyz) || size(spline_xyz, 1) ~= 3 || size(spline_xyz, 2) < 2
    error('Input `spline_xyz` must be a 3xN array with N >= 2.');
end
if ~isvector(target_point) || numel(target_point) ~= 3
    error('Input `target_point` must be a 1x3 or 3x1 vector.');
end
target_point = reshape(target_point, 1, 3); % Ensure target_point is 1x3

if ~isscalar(point_distance) || ~isnumeric(point_distance) || point_distance <= 0
    error('Input `point_distance` must be a positive scalar.');
end

fprintf('Setting up spline and calculating arc length...\n');

% --- Spline Creation ---
try
    pp = cscvn(spline_xyz); % Create cubic spline (piecewise polynomial)
catch spline_err
    error('Failed to create spline using cscvn: %s\nPlease check Curve Fitting Toolbox installation and input points.', spline_err.message);
end

% --- Arc Length Parameterization ---
N_fine = max(2000, 20 * size(spline_xyz, 2));
t_fine = linspace(pp.breaks(1), pp.breaks(end), N_fine); % Parameter range
fine_points = ppval(pp, t_fine); % Evaluate spline at many points (3xN_fine)

segment_lengths = sqrt(sum(diff(fine_points, 1, 2).^2, 1)); % Lengths of tiny segments
s_fine = [0, cumsum(segment_lengths)]; % Cumulative arc length
totalLength = s_fine(end);

if totalLength < eps
    warning('Total calculated spline length is near zero. Check input points.');
    output_points = nan(11, 3); output_directions = nan(11, 3); output_angles = nan(11, 3);
    return;
end

interp_s_to_t = @(s_query) interp1(s_fine, t_fine, s_query, 'linear');
interp_t_to_s = @(t_query) interp1(t_fine, s_fine, t_query, 'linear');

% --- Find Initial Guess for Parameter t based on Target Point ---
fprintf('Finding initial parameter guess based on target point...\n');
% Calculate squared Euclidean distances (faster than sqrt)
distances_sq = sum((fine_points - target_point').^2, 1); % target_point' is 3x1
[~, idx_guess] = min(distances_sq); % Index of the minimum distance
t_guess = t_fine(idx_guess); % The spline parameter 't' for the closest fine point
point_guess = fine_points(:, idx_guess)'; % Coordinates of this closest fine point

fprintf('Initial parameter guess: t_guess = %.4f\n', t_guess);
fprintf('Closest point on discretized spline (guess): [%.3f, %.3f, %.3f]\n', point_guess);


fprintf('Finding actual closest point on spline using optimization...\n');
% --- Find Closest Point Parameter using Optimization ---
dist_func = @(t) norm(ppval(pp, t) - target_point');
optim_options = optimset('TolX', 1e-6);
try
    % fminbnd finds the minimum within the interval [t_min, t_max].
    % Providing t_guess doesn't directly influence fminbnd's algorithm start,
    % but we have calculated the guess.
    [t_closest, ~, exitflag] = fminbnd(dist_func, pp.breaks(1), pp.breaks(end), optim_options);
    if exitflag <= 0
         warning('Optimization (fminbnd) may not have converged properly to find the closest point.');
    end
catch optim_err
    error('Optimization failed to find closest point using fminbnd: %s\nPlease check Optimization Toolbox installation.', optim_err.message);
end

s_closest = interp_t_to_s(t_closest);
closest_point_on_spline = ppval(pp, t_closest)';

fprintf('Optimization finished.\n');
fprintf('Closest point found at arc length %.3f (parameter t=%.3f).\n', s_closest, t_closest);
fprintf('Coordinates of closest point: [%.3f, %.3f, %.3f]\n', closest_point_on_spline);

% --- Calculate Target Arc Lengths for the 11 points ---
offsets = (-5:5)' * point_distance;
s_targets = s_closest + offsets;

fprintf('Calculating positions, directions, and angles for 11 points...\n');

% --- Initialize Outputs ---
output_points = nan(11, 3);
output_directions = nan(11, 3);
output_angles = nan(11, 3);
pp_deriv = fnder(pp); % Get derivative structure

% --- Generate Points, Directions, Angles ---
for i = 1:11
    s_current = s_targets(i);
    if s_current >= -eps && s_current <= totalLength + eps
        s_current_clipped = max(0, min(totalLength, s_current));
        t_current = interp_s_to_t(s_current_clipped);

        % Get Point
        pt = ppval(pp, t_current)';
        output_points(i, :) = pt;

        % Get Direction
        dir_vec = ppval(pp_deriv, t_current)';
        norm_dir = norm(dir_vec);
        if norm_dir > eps
            dir_normalized = dir_vec / norm_dir;
        else
            dir_normalized = [NaN, NaN, NaN];
             warning('Spline derivative norm is near zero at point %d (arc length %.3f). Direction is undefined.', i, s_current);
        end
        output_directions(i, :) = dir_normalized;

        % Get Angles
        if all(~isnan(dir_normalized))
            tx = dir_normalized(1); ty = dir_normalized(2); tz = dir_normalized(3);
            yaw = atan2(ty, tx);
            pitch = atan2(tz, sqrt(tx^2 + ty^2));
            roll = 0;
            output_angles(i, :) = [roll, pitch, yaw];
        else
            output_angles(i, :) = [NaN, NaN, NaN];
        end
    else
        fprintf('Point %d (target arc length %.3f) is outside spline bounds [0, %.3f].\n', i, s_current, totalLength);
    end
end

fprintf('Function execution finished.\n');

end