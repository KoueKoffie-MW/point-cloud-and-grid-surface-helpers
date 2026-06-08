function result = getOrGenerateSurface(generatorFunc, args, cacheDir, forceRegen)
% getOrGenerateSurface  Persistent .mat caching for expensive surface generation.
%
%   result = getOrGenerateSurface(generatorFunc, args, cacheDir, forceRegen)
%
% Inputs:
%   generatorFunc - function handle that generates the surface
%                   e.g. @() GenerateTerrainFromSTL(stlFile, resolution, ...)
%   args          - cell array of arguments used to generate the hash
%   cacheDir      - folder to store cache files (will be created if needed)
%   forceRegen    - if true, ignore cache and regenerate (default = false)
%
% Output:
%   result        - the generated (or loaded) surface data

    if nargin < 4
        forceRegen = false;
    end

    if ~exist(cacheDir, 'dir')
        mkdir(cacheDir);
    end

    % Create a hash from the input arguments
    hashStr = '';
    for i = 1:numel(args)
        val = args{i};
        if isnumeric(val) || islogical(val)
            valStr = mat2str(val(:)');
        elseif ischar(val) || isstring(val)
            valStr = char(val);
        else
            valStr = 'complex';
        end
        hashStr = [hashStr, num2str(i), '=', valStr, ';'];
    end
    fileHash = mlreportgen.utils.hash(hashStr);
    cacheFile = fullfile(cacheDir, [fileHash, '.mat']);

    if ~forceRegen && exist(cacheFile, 'file')
        fprintf('Loading cached surface: %s\n', cacheFile);
        loaded = load(cacheFile);
        result = loaded.result;
        return;
    end

    % Generate new surface
    fprintf('Generating surface (cache miss)...\n');
    result = generatorFunc();

    % Save to cache
    fprintf('Saving to cache: %s\n', cacheFile);
    save(cacheFile, 'result');
end
