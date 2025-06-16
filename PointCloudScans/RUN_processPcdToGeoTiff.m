% --- Define your inputs ---
myPcdFile = 'Long Straight PointCloud.pcd'; % Change this
myTiffFile = 'Long Straight PointCloud.tif';  % Change this
myResolution = 0.5;                          % Change this (e.g., in meters)
myEpsgCode = 32632;                          % IMPORTANT: Change to your data's actual EPSG code!

% --- Run the function ---
try
    [loadedPtCloud, demGrid, demReference] = processPcdToGeoTiff(myPcdFile, myTiffFile, myResolution, myEpsgCode);
    % You can now work with loadedPtCloud, demGrid, demReference if needed
catch ME
    fprintf(2, 'Error running processPcdToGeoTiff: %s\n', ME.message); % Print error in red
end