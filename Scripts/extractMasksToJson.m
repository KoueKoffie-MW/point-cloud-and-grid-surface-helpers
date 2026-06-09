function extractMasksToJson()
% extractMasksToJson  Extract mask scripts and parameters from PC_GS_SSMB.slx to JSON.
%
%   This script opens the PC_GS_SSMB library, extracts all block masks,
%   and writes them to PC_GS_SSMB_mask_extraction.json (all masked blocks)
%   and PC_GS_SSMB_mask_code_only.json (only blocks containing actual
%   initialization code, variables, or callbacks).

    libraryName = "PC_GS_SSMB";
    libraryFile = "Libraries/PC_GS_SSMB.slx";

    % Ensure library file exists
    if ~exist(libraryFile, "file")
        error("Library file not found at: %s", libraryFile);
    end

    % Load the system (does not open GUI window)
    fprintf("Loading library: %s...\n", libraryFile);
    load_system(libraryFile);

    % Find all masked blocks in the library
    fprintf("Searching for masked blocks...\n");
    blocks = find_system(libraryName, "LookUnderMasks", "all", "FollowLinks", "on", "Mask", "on");
    numBlocks = length(blocks);
    fprintf("Found %d masked blocks.\n", numBlocks);

    % Preallocate structure array for all blocks
    extractedBlocks = struct("path", {}, "block_type", {}, "mask_type", {}, "mask_self_modifiable", {}, "mask", {});

    for i = 1:numBlocks
        blockPath = blocks{i};
        
        % Read basic properties
        blockType = get_param(blockPath, "BlockType");
        maskType = get_param(blockPath, "MaskType");
        maskSelfModifiable = get_param(blockPath, "MaskSelfModifiable");
        
        % Read mask properties
        maskInit = get_param(blockPath, "MaskInitialization");
        maskVars = get_param(blockPath, "MaskVariables");
        maskHelp = get_param(blockPath, "MaskHelp");
        maskDesc = get_param(blockPath, "MaskDescription");
        
        % Build callbacks structure
        callbacks = struct();
        try
            names = get_param(blockPath, "MaskNames");
            cbs = get_param(blockPath, "MaskCallbacks");
            for j = 1:length(names)
                if ~isempty(cbs{j})
                    callbacks.(names{j}) = cbs{j};
                end
            end
        catch
            % Ignore if block doesn't support parameter callbacks
        end
        
        % Store block details
        blockEntry = struct(...
            "path", blockPath, ...
            "block_type", blockType, ...
            "mask_type", maskType, ...
            "mask_self_modifiable", maskSelfModifiable, ...
            "mask", struct(...
                "initialization", maskInit, ...
                "variables", maskVars, ...
                "help", maskHelp, ...
                "description", maskDesc, ...
                "callbacks", callbacks ...
            ) ...
        );
        
        extractedBlocks(i) = blockEntry;
    end

    % Prepare common metadata
    extractedAt = char(datetime("now", "Format", "dd-MMM-yyyy HH:mm:ss"));
    matlabVer = version;

    %% 1. Write PC_GS_SSMB_mask_extraction.json (all masked blocks)
    fullData = struct(...
        "metadata", struct(...
            "library", libraryFile, ...
            "extracted_at", extractedAt, ...
            "matlab_version", matlabVer ...
        ), ...
        "blocks", extractedBlocks ...
    );

    fullJsonStr = jsonencode(fullData, "PrettyPrint", true);
    
    % Write to file in root directory
    outputFullFile = "PC_GS_SSMB_mask_extraction.json";
    fid1 = fopen(outputFullFile, "w", "n", "UTF-8");
    if fid1 == -1
        error("Could not open file for writing: %s", outputFullFile);
    end
    fprintf(fid1, "%s", fullJsonStr);
    fclose(fid1);
    fprintf("Successfully wrote all masked blocks to: %s\n", outputFullFile);

    %% 2. Write PC_GS_SSMB_mask_code_only.json (only blocks with actual code)
    % A block has code if initialization, variables, or callbacks are non-empty
    hasCode = false(1, numBlocks);
    for i = 1:numBlocks
        b = extractedBlocks(i);
        hasCallbacks = ~isempty(fieldnames(b.mask.callbacks));
        if ~isempty(b.mask.initialization) || ~isempty(b.mask.variables) || hasCallbacks
            hasCode(i) = true;
        end
    end
    
    codeOnlyBlocks = extractedBlocks(hasCode);
    fprintf("Found %d blocks containing actual mask code.\n", length(codeOnlyBlocks));

    codeOnlyData = struct(...
        "metadata", struct(...
            "library", libraryFile, ...
            "extracted_at", extractedAt, ...
            "matlab_version", matlabVer, ...
            "filter", "Only blocks with actual code (non-empty MaskInitialization, MaskVariables, or MaskCallbacks)" ...
        ), ...
        "blocks", codeOnlyBlocks ...
    );

    codeOnlyJsonStr = jsonencode(codeOnlyData, "PrettyPrint", true);
    
    % Write to file in root directory
    outputCodeFile = "PC_GS_SSMB_mask_code_only.json";
    fid2 = fopen(outputCodeFile, "w", "n", "UTF-8");
    if fid2 == -1
        error("Could not open file for writing: %s", outputCodeFile);
    end
    fprintf(fid2, "%s", codeOnlyJsonStr);
    fclose(fid2);
    fprintf("Successfully wrote code-only masked blocks to: %s\n", outputCodeFile);

    % Close system
    close_system(libraryName, 0);
    fprintf("Finished mask extraction.\n");
end
