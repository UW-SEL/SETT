function config = getEngineConfig(app)
    % GETENGINECONFIG Generate an engine config based on current input values
    config = struct;
    compKeys = {"fluid", "ws", "chx", "regen", "hhx"};
    for index = 1:length(compKeys)
        compKey = compKeys{index};
        modelName = app.(compKey).uiDropdown.Value;
        params = app.(compKey).getParams();
        if isstruct(params)
            config.(compKey) = struct("model", modelName, "params", params);
        else
            config.(compKey) = struct("model", modelName);
        end
    end
    config.solver = app.getSolverParams();
    config.conditions = app.getConditions();
end
