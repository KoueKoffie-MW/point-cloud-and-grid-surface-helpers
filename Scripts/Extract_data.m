% Assume 'input_matrix' is your existing 11x3x138 matrix
% Example: Create some sample data if you don't have it loaded
% input_matrix = rand(11, 3, 138);

% Get the dimensions of the input matrix
input_matrix = out.logsout{1}.Values.Data;
[num_points, num_coords, num_instances] = size(input_matrix); % Should be 11, 3, 138

% --- Input Size Check (Optional but Recommended) ---
if num_points ~= 11 || num_coords ~= 3
    warning('Input matrix size is %dx%dx%d, expected 11x3xN.', ...
            num_points, num_coords, num_instances);
    % Adjust num_points and num_coords if the warning is acceptable
    % For example:
    % num_points = size(input_matrix, 1);
    % num_coords = size(input_matrix, 2);
    % num_instances = size(input_matrix, 3);
end
% ----------------------------------------------------

% Pre-allocate a cell array to hold the 11 resulting matrices
% This improves performance by allocating memory upfront.
output_matrices = cell(1, num_points); % Creates a 1x11 cell array

% Loop through the first dimension (from 1 to 11)
for i = 1:num_points
    % Extract the data for the i-th point across all coordinates and instances.
    % M(i, :, :) gives a slice of size 1x3x138 (or 1xnum_coords x num_instances)
    slice_3d = input_matrix(i, :, :);

    % Reshape the 1x3x138 slice into a 3x138 matrix.
    % The reshape function takes elements column-wise, so this rearranges
    % the data correctly into [coord1_inst1, coord1_inst2, ...;
    %                         coord2_inst1, coord2_inst2, ...;
    %                         coord3_inst1, coord3_inst2, ...] form.
    output_matrices{i} = reshape(slice_3d, [num_coords, num_instances]);

    % --- Alternative using squeeze (less direct for specific shape) ---
    % matrix_2d = squeeze(slice_3d);
    % % Need to ensure it's 3x138, squeeze might make it 138x3 if original was 11x138x3
    % if size(matrix_2d, 1) ~= num_coords
    %     matrix_2d = matrix_2d'; % Transpose if needed
    % end
    % output_matrices{i} = matrix_2d;
    % ------------------------------------------------------------------
end

% --- Verification (Optional) ---
% Check the content and size of the first and last resulting matrices
% fprintf('Size of matrix for point 1: %d x %d\n', size(output_matrices{1}, 1), size(output_matrices{1}, 2));
% disp('First few columns of data for point 1:');
% disp(output_matrices{1}(:, 1:min(5, num_instances))); % Display first 5 columns
%
% fprintf('Size of matrix for point %d: %d x %d\n', num_points, size(output_matrices{num_points}, 1), size(output_matrices{num_points}, 2));
% -------------------------------

% Now you have a cell array named 'output_matrices' where:
% output_matrices{1} is the 3x138 matrix for the first point
% output_matrices{2} is the 3x138 matrix for the second point
% ...
% output_matrices{11} is the 3x138 matrix for the eleventh point