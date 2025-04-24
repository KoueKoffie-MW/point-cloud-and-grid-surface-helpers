function resampled_data = preprocessSplineResample(spline_xyz, point_distance)
%preprocessSplineResample Resamples a spline at fixed arc length intervals
%   and pre-calculates point coordinates, directions, and angles.
%
%   resampled_data = preprocessSplineResample(spline_xyz, point_distance)
%
%   Inputs:
%       spline_xyz     - 3xN array defining the spline path [x; y; z]. N >= 2.
%       point_distance - Scalar defining the desired distance *along the spline*
%                        between resampled points. Must be positive.
%
%   Outputs:
%       resampled_data - A structure containing:
%           .points        : 3xM matrix of resampled point coordinates.
%           .directions    : 3xM matrix of normalized tangent directions.
%           .angles        : 3xM matrix of orientation angles [Rx, Ry, Rz] (rad).
%           .num_points    : Scalar M, the number of resampled points.
%           .point_distance: The resampling distance used.
%           .total_length  : The total calculated arc length of the spline.
%
%   Requires: Curve Fitting Toolbox (for cscvn, ppval, fnder)

% --- Input Validation ---
if nargin ~= 2
    error('Requires 2 input arguments: spline_xyz (3xN), point_distance (scalar)');
end
if ~ismatrix(spline_xyz) || size(spline_xyz, 1) ~= 3 || size(spline_xyz, 2) < 2
    error('Input `spline_xyz` must be a 3xN array with N >= 2.');
end
if ~isscalar(point_distance) || ~isnumeric(point_distance) || point_distance <= eps
    error('Input `point_distance` must be a positive scalar.');
end

fprintf('Starting spline pre-processing...\n');
fprintf('Setting up spline and calculating arc length...\n');

% --- Spline Creation ---
try
    pp = cscvn(spline_xyz); % Create cubic spline
    pp_deriv = fnder(pp);   % Get derivative structure once
catch spline_err
    error('Failed to create spline using cscvn: %s', spline_err.message);
end

% --- Arc Length Parameterization ---
N_fine = max(2000, 20 * size(spline_xyz, 2));
t_fine = linspace(pp.breaks(1), pp.breaks(end), N_fine);
fine_points = ppval(pp, t_fine);

segment_lengths = sqrt(sum(diff(fine_points, 1, 2).^2, 1));
s_fine = [0, cumsum(segment_lengths)];
totalLength = s_fine(end);

resampled_data = struct(); % Initialize output structure
resampled_data.total_length = totalLength;
resampled_data.point_distance = point_distance;

if totalLength < eps
    warning('Total calculated spline length is near zero. Resampling not possible.');
    resampled_data.points = zeros(3, 0);
    resampled_data.directions = zeros(3, 0);
    resampled_data.angles = zeros(3, 0);
    resampled_data.num_points = 0;
    return;
end

% Create interpolant for mapping arc length (s) to parameter (t)
interp_s_to_t = @(s_query) interp1(s_fine, t_fine, s_query, 'linear');

fprintf('Resampling spline at fixed distance (%.3f)...\n', point_distance);

% --- Resample Spline at Fixed `point_distance` Intervals ---
s_resample_targets = (0 : point_distance : totalLength)';
if abs(s_resample_targets(end) - totalLength) > 1e-9 * totalLength % Relative tolerance check
    s_resample_targets = [s_resample_targets; totalLength];
end
s_resample_targets = unique(s_resample_targets);

t_resample = interp_s_to_t(s_resample_targets);

% Evaluate spline points and derivatives at these parameters
resampled_points = ppval(pp, t_resample);      % 3xM matrix
resampled_dirs_raw = ppval(pp_deriv, t_resample); % 3xM matrix
num_resampled = size(resampled_points, 2);

fprintf('Resampled into %d points. Pre-calculating directions and angles...\n', num_resampled);

% --- Pre-calculate Directions and Angles for ALL resampled points ---
resampled_directions = nan(3, num_resampled);
resampled_angles = nan(3, num_resampled);

for i = 1:num_resampled
    dir_vec = resampled_dirs_raw(:, i);
    norm_dir = norm(dir_vec);

    if norm_dir > eps
        dir_normalized = dir_vec / norm_dir;
    else
        dir_normalized = [NaN; NaN; NaN];
        warning('Spline derivative norm near zero at resampled point index %d.', i);
    end
    resampled_directions(:, i) = dir_normalized;

    if all(~isnan(dir_normalized))
        tx = dir_normalized(1); ty = dir_normalized(2); tz = dir_normalized(3);
        yaw = atan2(ty, tx);           % Rz
        pitch = atan2(tz, sqrt(tx^2 + ty^2)); % Ry
        roll = 0;                       % Rx
        resampled_angles(:, i) = [roll; pitch; yaw];
    else
        resampled_angles(:, i) = [NaN; NaN; NaN];
    end
end

% --- Store results in output structure ---
resampled_data.points = resampled_points;           % 3xM
resampled_data.directions = resampled_directions;   % 3xM
resampled_data.angles = resampled_angles;           % 3xM (Rx; Ry; Rz)
resampled_data.num_points = num_resampled;          % Scalar M

fprintf('Spline pre-processing finished.\n');

end