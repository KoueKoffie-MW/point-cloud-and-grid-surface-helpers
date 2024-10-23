function resizeSTL(inputFileName, outputFileName, scaleFactors)
    % Read the STL file
    [TR, ~,~ , ~] = stlread(inputFileName);
    
    % Apply the scaling factors to the vertices
    scaledVertices = TR.Points;
    connectivityList = TR.ConnectivityList;
    scaledVertices(:, 1) = TR.Points(:, 1) * scaleFactors(1);  % Scale x-axis
    scaledVertices(:, 2) = TR.Points(:, 2) * scaleFactors(2);  % Scale y-axis
    scaledVertices(:, 3) = TR.Points(:, 3) * scaleFactors(3);  % Scale z-axis

    % Create the triangulation object
    TR_s = triangulation(connectivityList, scaledVertices);
    
    % Write the scaled model to a new STL file
    stlwrite(TR_s,outputFileName);
    
    % disp(['STL file has been resized and saved to ', outputFileName]);
end