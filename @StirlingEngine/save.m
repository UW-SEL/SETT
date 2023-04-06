function save(obj, filename)
    % SAVE Save the current engine state
    %
    % The engine state will be saved as a JSON-formatted file with
    % the given filename.  If no filename is provided, a save file
    % dialog will be opened.

    % If a filename is not provided, ask for one
    if nargin < 2
        [file, folder] = uiputfile(             ...
            {'*.json', 'Engine Config Files'},  ...
            'Save Engine State',                ...
            'engine.json'                       ...
        );
        if isequal(file, 0) || isequal(folder, 0)
            disp("Warning: Engine file not saved")
            return
        end
        filename = fullfile(folder, file);
    end
    % TODO: add ".json" to end of filename if not present

    configData = obj.config;
    configData.conditions = struct(  ...
        "T_cold", obj.T_cold,        ...
        "T_hot", obj.T_hot,          ...
        "P_0", obj.P_0               ...
    );
    if obj.isSolutionAvailable
        configData.solution = struct(                          ...
            "V_k", obj.V_k,                                    ...
            "V_r", obj.V_r,                                    ...
            "V_l", obj.V_l,                                    ...
            "T_k", obj.T_k,                                    ...
            "T_r_cold", obj.T_r_cold,                          ...
            "T_r", obj.T_r,                                    ...
            "T_r_hot", obj.T_r_hot,                            ...
            "T_l", obj.T_l,                                    ...
            "P_ave", obj.P_ave,                                ...
            "freq", obj.freq,                                  ...
            "period", obj.period,                              ...
            "indicatedPowerZeroDP", obj.indicatedPowerZeroDP,  ...
            "indicatedPower", obj.indicatedPower,              ...
            "shaftPower", obj.shaftPower,                      ...
            "shaftTorque", obj.shaftTorque,                    ...
            "netPower", obj.netPower,                          ...
            "heatInput", obj.heatInput,                        ...
            "heatRejection", obj.heatRejection,                ...
            "efficiency", obj.efficiency                       ...
        );
    else
        disp("Warning: Solution not included in saved file")
        disp("         Run the engine before saving to include the solution")
    end

    writeConfigFile(configData, filename)
end


%{
The function that follows was adapted from code written by Lior Kirsch and copied from the MATLAB
Central File Exchange (https://www.mathworks.com/matlabcentral/fileexchange/50965-structure-to-json)

Copyright (c) 2015, Lior Kirsch
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in
      the documentation and/or other materials provided with the distribution

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
%}


function writeConfigFile(configData, configFilePath)
    fid = fopen(configFilePath,'w');
    writeElement(fid, configData,'');
    fprintf(fid,'\n');
    fclose(fid);

    function writeElement(fid, configData,tabs)
        namesOfFields = fieldnames(configData);
        numFields = length(namesOfFields);
        baseTabs = tabs;
        tabs = sprintf('%s  ',tabs);
        fprintf(fid,'{\n%s',tabs);

        for i = 1:numFields - 1
            currentField = namesOfFields{i};
            currentElementValue = eval(sprintf('configData.%s',currentField));
            writeSingleElement(fid, currentField,currentElementValue,tabs);
            fprintf(fid,',\n%s',tabs);
        end
        if isempty(i)
            i=1;
        else
          i=i+1;
        end

        currentField = namesOfFields{i};
        currentElementValue = eval(sprintf('configData.%s',currentField));
        writeSingleElement(fid, currentField,currentElementValue,tabs);
        fprintf(fid,'\n%s}',baseTabs);
    end

    function writeSingleElement(fid, currentField, currentElementValue, tabs)
        % If this is an array and not a string then iterate on every element
        % If this is a single element write it
        if length(currentElementValue) > 1 && ~ischar(currentElementValue)
            fprintf(fid,'"%s": %s',currentField, jsonencode(currentElementValue));
        elseif isstruct(currentElementValue)
            fprintf(fid,'"%s": ',currentField);
            writeElement(fid, currentElementValue,tabs);
        elseif isStringScalar(currentElementValue)
            fprintf(fid,'"%s": "%s"' , currentField,currentElementValue);
        elseif isinf(currentElementValue)
            fprintf(fid,'"%s": "Inf"' , currentField);
        elseif isnumeric(currentElementValue)
            fprintf(fid,'"%s": %g' , currentField,currentElementValue);
        elseif isempty(currentElementValue)
            fprintf(fid,'"%s": null' , currentField,currentElementValue);
        elseif islogical(currentElementValue)
            if currentElementValue
                fprintf(fid,'"%s": true' , currentField);
            else
                fprintf(fid,'"%s": false' , currentField);
            end
        else % ischar or something else ...
            fprintf(fid,'"%s": "%s"' , currentField,currentElementValue);
        end
    end
end
