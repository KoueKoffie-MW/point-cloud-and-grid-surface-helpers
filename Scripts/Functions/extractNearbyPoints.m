function [output_points, output_directions, output_angles] = extractNearbyPoints(target_pt_signalx,target_pt_signaly,target_pt_signalz, resampled_data)
%extractNearbyPoints Finds the closest point in pre-resampled spline data
%   and extracts 11 neighboring points, directions, and angles.
%   Designed for use within a Simulink MATLAB Function block.
%
%   Inputs:
%       target_point   - 1x3 signal (current target point [xt, yt, zt]).
%       resampled_data - Structure parameter containing pre-calculated data:
%                        .points (3xM), .directions (3xM), .angles (3xM),
%                        .num_points (M).
%
%   Outputs:
%       output_points    - 11x3 matrix of selected points (NaN if out of bounds).
%       output_directions- 11x3 matrix of selected directions (NaN if out of bounds).
%       output_angles    - 11x3 matrix of selected angles (NaN if out of bounds).

%#codegen % Enable checks for code generation compatibility
target_point = [target_pt_signalx;target_pt_signaly;target_pt_signalz]';
% --- Input Checks (Basic) ---
% Check if resampled_data seems valid (more checks could be added)
if isempty(resampled_data) || ~isstruct(resampled_data) || ~isfield(resampled_data, 'points') || isempty(resampled_data.points)
     coder.internal.warning('Input ''resampled_data'' is empty or invalid. Returning NaNs.');
     output_points = nan(11, 3);
     output_directions = nan(11, 3);
     output_angles = nan(11, 3);
     return;
end
% Ensure target_point is usable (Simulink usually ensures type/size)
target_point_col = target_point(:); % Ensure it's a column vector 3x1

% --- Find Closest Resampled Point Index ---
num_resampled = resampled_data.num_points;
if num_resampled == 0
    % Handle case where resampling yielded no points
    output_points = nan(11, 3); output_directions = nan(11, 3); output_angles = nan(11, 3);
    return;
end

% Calculate squared Euclidean distances
% (resampled_data.points is 3xM, target_point_col is 3x1)
distances_sq = sum((resampled_data.points - target_point_col).^2, 1);

% Find the index of the minimum distance point
[~, idx_closest] = min(distances_sq);

% --- Extract 11 Neighboring Points/Directions/Angles ---
% Initialize Outputs
output_points = nan(11, 3);
output_directions = nan(11, 3);
output_angles = nan(11, 3); % [Rx, Ry, Rz] format

% Loop through the 11 output slots (-5 to +5 relative to idx_closest)
for k = 1:11
    current_idx = idx_closest + (k - 6); % k=1 -> idx-5, k=6 -> idx, k=11 -> idx+5

    % Check if this index is valid
    if current_idx >= 1 && current_idx <= num_resampled
        % Index is valid: copy pre-calculated data

        % Point (Transpose 3x1 column to 1x3 row for output)
        output_points(k, :) = resampled_data.points(:, current_idx)';

        % Direction (Transpose 3x1 column to 1x3 row)
        output_directions(k, :) = resampled_data.directions(:, current_idx)';

        % Angles (Transpose 3x1 column [Rx;Ry;Rz] to 1x3 row [Rx,Ry,Rz])
        output_angles(k, :) = resampled_data.angles(:, current_idx)';
    % else % Index is out of bounds, outputs remain NaN
    end
end

end

