function checkComponentParams(compType, compName, params)
    % CHECKCOMPONENTPARAMS Verify component parameters (Static Method)
    %
    % This function checks that all required parameters are
    % present and that there are no unexpected parameters.

    % Create arrays of provided and expected parameter names
    providedFields = getFieldNames(params);
    expectedFields = getFieldNames(components.(compType).(compName).defaultParams);

    % Ensure all exected parameters are provided
    for i = 1:length(expectedFields)
        expectedField = expectedFields{i};
        index = strcmp(providedFields, expectedField);
        if any(index)
            providedFields(index) = [];
        else
            error(                                                         ...
                '%s component "%s" is missing a required parameter "%s"',  ...
                compType, compName, expectedField                          ...
            )
        end
    end

    % Check for any unexpected parameters
    if length(providedFields) > 0
        error(                                                     ...
            '%s component "%s" has an unexpected parameter "%s"',  ...
            compType, compName, providedFields{1}                  ...
        )
    end
end


function r = getFieldNames(s)
    % GETFIELDNAMES Return a cell array of field names in a struct
    %
    % Field names in a nested struct use a period as the namespace separator.
    r = {};
    fields = fieldnames(s);
    for i = 1:length(fields)
        field = fields{i};
        if isstruct(s.(field))
            subNames = getFieldNames(s.(field));
            for c = subNames
                r{end+1} = strcat(field, '.', c{1});  % single quotes around period are necessary
            end
        else
            r{end+1} = field;
        end
    end
end
