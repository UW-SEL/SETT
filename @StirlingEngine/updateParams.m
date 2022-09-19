function updateParams(obj, name, value)
    % UPDATEPARAMS Update component parameter values
    %
    % The parameter name is specified as a string starting with the
    % component name (fluid, ws, chx, regen, or hhx) and uses a period
    % as the namespace separator.
    %
    % Multiple name-value pairs can be used in a single call.
    %
    % Calling this function clears any solution values stored on the engine.
    %
    % Examples:
    %   engine.updateParams("chx.R_hyd", 100)
    %   engine.updateParams("regen.geometry.mesh.pitch", 6000, "hhx.W_parasitic", 1000)
    arguments
        obj
    end
    arguments (Repeating)
        name (1,1) string
        value (1,1) double
    end

    numPairs = length(name);

    % Validate all parameter changes first
    for i = 1:numPairs
        [compType, compParam] = parseName(name{i});
        try
            currentParams = obj.config.(compType).params;
            curentValue = getfield(currentParams, compParam{:});
            mustBeReal(curentValue)  % checks that compParam is valid for compType
        catch
            error("%s is not a valid component parameter", name{i})
        end
    end

    % Apply each change in turn
    for i = 1:numPairs
        [compType, compParam] = parseName(name{i});
        currentParams = obj.config.(compType).params;
        newParams = setfield(currentParams, compParam{:}, value{i});
        obj.config.(compType).params = newParams;  % update the engine config struct
        ClassName = str2func(metaclass(obj.(compType)).Name);
        obj.(compType) = ClassName(newParams);  % re-initialize the componenent with the new param
    end

    % Stored solution is no longer valid
    obj.clearSolution()
end


function [compType, compParam] = parseName(name)
    parts = strsplit(name, ".");
    compType = parts{1};
    compParam = parts(2:end);
end
