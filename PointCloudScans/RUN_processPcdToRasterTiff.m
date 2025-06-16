% --- Define your inputs ---
myPcdFile = 'Long Straight PointCloud.pcd'; % Path to your PCD file
myTiffFile = 'Long Straight PointCloud.tif';  % Desired output TIFF path
resolution = [1 ;1];                        % Your desired resolution IF using Resolution mode - can also be scalar for isotrropic resolution

% Flag to choose mode:
% 0 = Use the 'resolution' variable above ('Resolution' mode)
% 1 = Estimate resolution based on point count ('PointCount' mode)
flag_OrignumPoints = 1;

% --- Run the function ---
try
    if flag_OrignumPoints == 0
        % --- Resolution Mode ---
        % Provide pcd, tiff, and the resolution value.
        % 'ControlMode', 'Resolution' is the default, so technically optional,
        % but good practice to include if you have the flag logic.
        fprintf('Calling function in Resolution mode with resolution = %g\n', resolution);
        [ptCloud, Z, RA] = processPcdToRasterTiff(myPcdFile, myTiffFile, resolution, 'ControlMode', 'Resolution');

    else % flag_OrignumPoints is not 0 (e.g., 1)
        % --- PointCount Mode ---
        % Provide pcd, tiff, and specify the ControlMode.
        % DO NOT provide the resolution variable here.
        fprintf('Calling function in PointCount mode...\n');
        [ptCloud, Z, RA] = processPcdToRasterTiff(myPcdFile, myTiffFile, 'ControlMode', 'PointCount');
    end

    % Optional: Do something with the outputs ptCloud, Z, RA if needed
    fprintf('Function call completed successfully.\n');

catch ME
    fprintf(2, 'Error running processPcdToRasterTiff: %s\n', ME.message);
    % Display stack trace for more details
    fprintf(2, 'Error occurred in file: %s, line: %d\n', ME.stack(1).file, ME.stack(1).line);
end