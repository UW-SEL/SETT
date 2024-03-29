function updateSolverTab(app, solverParams)
    % UPDATESOLVERTAB Update the Solver tab with new values

    % The Solver tab is initialized if solverParams are not provided
    % (this happens when the app is first initialized)
    if nargin < 2
        % Use the default solver parameters
        solverParams = struct(             ...
            "odeSolver", "ode45",          ...
            "odeTolerance", struct(        ...
              "abs", 1e-6,                 ...
              "rel", 1e-4                  ...
            ),                             ...
            "innerLoopTolerance", struct(  ...
              "abs", 1e-6,                 ...
              "rel", 1e-4                  ...
            ),                             ...
            "outerLoopTolerance", struct(  ...
              "abs", 1e-6,                 ...
              "rel", 1e-4                  ...
            ),                             ...
            "timeResolution", 5            ...
        );

        % Create the Solver tab and grid
        solverTab = uitab(app.tabGroup, "Title", "Solver");
        app.uiGrids("solver") = uigridlayout(     ...
            solverTab,                            ...
            "RowHeight", {"fit", "fit"},          ...
            "ColumnWidth", {"fit", "fit", "fit"}  ...
        );
    else
        delete(app.uiGrids("solver").Children)  % clear existing inputs
    end

    inputs = containers.Map;

    createPanel = @StirlingEngineApp.createInputPanel;
    createInput = @StirlingEngineApp.createNumericInput;

    gridLayout = app.uiGrids("solver");
    odePanelGrid = createPanel(gridLayout, "ODE", "fillWidth", true);
    innerLoopPanelGrid = createPanel(gridLayout, "Inner Loop");
    outerLoopPanelGrid = createPanel(gridLayout, "Outer Loop");
    miscPanelGrid = createPanel(gridLayout, "Miscellaneous");

    inputs("odeTolerance.abs") = createInput(    ...
        odePanelGrid,                            ...
        "Label", "Tolerance (Abs)",              ...
        "Value", solverParams.odeTolerance.abs,  ...
        "LowerLimit", 0,                         ...
        "LowerLimitInclusive", "off"             ...
    );
    inputs("odeTolerance.rel") = createInput(    ...
        odePanelGrid,                            ...
        "Label", "Tolerance (Rel)",              ...
        "Value", solverParams.odeTolerance.rel,  ...
        "LowerLimit", 0,                         ...
        "LowerLimitInclusive", "off"             ...
    );
    uilabel(                            ...
        odePanelGrid,                   ...
        "Text", "Solver",               ...
        "HorizontalAlignment", "right"  ...
    );
    inputs("odeSolver") = uidropdown(  ...
        odePanelGrid,                  ...
        "Items", ["ode15s", "ode45"],  ...
        "Value", "ode45"               ...
    );

    inputs("innerLoopTolerance.abs") = createInput(    ...
        innerLoopPanelGrid,                            ...
        "Label", "Tolerance (Abs)",                    ...
        "Value", solverParams.innerLoopTolerance.abs,  ...
        "LowerLimit", 0,                               ...
        "LowerLimitInclusive", "off"                   ...
    );
    inputs("innerLoopTolerance.rel") = createInput(    ...
        innerLoopPanelGrid,                            ...
        "Label", "Tolerance (Rel)",                    ...
        "Value", solverParams.innerLoopTolerance.rel,  ...
        "LowerLimit", 0,                               ...
        "LowerLimitInclusive", "off"                   ...
    );

    inputs("outerLoopTolerance.abs") = createInput(    ...
        outerLoopPanelGrid,                            ...
        "Label", "Tolerance (Abs)",                    ...
        "Value", solverParams.outerLoopTolerance.abs,  ...
        "LowerLimit", 0,                               ...
        "LowerLimitInclusive", "off"                   ...
    );
    inputs("outerLoopTolerance.rel") = createInput(    ...
        outerLoopPanelGrid,                            ...
        "Label", "Tolerance (Rel)",                    ...
        "Value", solverParams.outerLoopTolerance.rel,  ...
        "LowerLimit", 0,                               ...
        "LowerLimitInclusive", "off"                   ...
    );

    inputs("timeResolution") = createInput(    ...
        miscPanelGrid,                         ...
        "Label", "Time Resolution",            ...
        "Value", solverParams.timeResolution,  ...
        "LowerLimit", 1,                       ...
        "IsInteger", true                      ...
    );

    app.getSolverParams = @getSolverParamsFunc;
    function r = getSolverParamsFunc()
        r = struct;
        names = keys(inputs);
        for i = 1:length(names)
            name = names{i};
            nestedName = strsplit(name, ".");
            currentValue = inputs(name).Value;
            r = setfield(r, nestedName{:}, currentValue);
        end
    end
end
