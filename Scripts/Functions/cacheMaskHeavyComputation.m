function [shouldCompute, cachedData] = cacheMaskHeavyComputation(varargin)
% cacheMaskHeavyComputation  Smart caching for expensive mask initialization code.
 
% NOTE: This function uses traditional nargin-style input validation
% instead of the 'arguments' block because it is intended to be called
% from Simulink mask initialization, which has limited support for the
% modern arguments block with validation attributes.
%
%   [shouldCompute, cachedData] = cacheMaskHeavyComputation('Param1', value1, 'Param2', value2, ...)
%
% This function helps prevent expensive operations (point cloud generation,
% terrain interpolation, figure creation, etc.) from running on every mask
% initialization. It only returns true when the provided input parameters
% have changed since the last call for this block.
%
% Inputs (name-value pairs):
%   Any parameters that affect the result of the heavy computation.
%   Common examples: 'stlFileName', stlFileName, 'resolution', resolution, ...
%
% Outputs:
%   shouldCompute - logical. true = run the expensive code, false = use cache
%   cachedData    - struct containing previously stored outputs (when shouldCompute = false)
%
% Example usage inside MaskInitialization:
%
%   [shouldCompute, cached] = cacheMaskHeavyComputation( ...
%       'stlFileName', stlFileName, ...
%       'resolution',  resolution, ...
%       'x_query',     x_query, ...
%       'y_query',     y_query, ...
%       'Int_method',  Int_method);
%
%   if shouldCompute
%       [imageMatrix, xi, yi, ZI, Res_orig, z_query] = GenerateTerrainFromSTL(...);
%
%       % Store results for next time
%       cacheMaskHeavyComputation('store', ...
%           'imageMatrix', imageMatrix, ...
%           'xi', xi, 'yi', yi, 'ZI', ZI);
%   else
%       imageMatrix = cached.imageMatrix;
%       xi          = cached.xi;
%       ...
%   end
%
% Note: This uses block path (gcb) as the cache key. It works best with
% MaskSelfModifiable blocks.

    persistent cacheStore

    if isempty(cacheStore)
        cacheStore = containers.Map('KeyType', 'char', 'ValueType', 'any');
    end

    blockKey = gcb;   % Unique key per block instance

    % Handle 'store' command
    if nargin >= 1 && strcmp(varargin{1}, 'store')
        if isKey(cacheStore, blockKey)
            stored = cacheStore(blockKey);
        else
            stored = struct();
        end

        for i = 2:2:numel(varargin)
            paramName = varargin{i};
            paramValue = varargin{i+1};
            stored.(paramName) = paramValue;
        end

        cacheStore(blockKey) = stored;
        shouldCompute = false;
        cachedData = stored;
        return;
    end

    % Normal usage: build hash from input parameters
    inputHash = '';
    for i = 1:2:numel(varargin)
        name  = varargin{i};
        value = varargin{i+1};

        if isnumeric(value) || islogical(value)
            valStr = mat2str(value(:)');
        elseif ischar(value) || isstring(value)
            valStr = char(value);
        else
            valStr = 'complex';
        end

        inputHash = [inputHash, name, '=', valStr, ';'];
    end

    currentHash = mlreportgen.utils.hash(inputHash);

    if isKey(cacheStore, blockKey)
        entry = cacheStore(blockKey);
        if isfield(entry, 'hash') && strcmp(entry.hash, currentHash)
            shouldCompute = false;
            cachedData = entry;
            return;
        end
    end

    % Inputs changed or first time -> must compute
    shouldCompute = true;
    cachedData = struct();
end
