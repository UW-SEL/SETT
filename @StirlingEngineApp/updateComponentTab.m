function updateComponentTab(app, compKey, compName, params)
    % UPDATECOMPONENTTAB Update the `compKey` tab with a new component model

    % The component tab is created if compName is not provided
    % (this happens when the app is first initialized)
    if nargin < 3
        compName = createComponentTab(app, compKey);  % creating the tab returns the default comp name
    end

    % If params are not provided, use the defaults defined in the component model
    if nargin < 4
        params = components.(compKey).(compName).defaultParams;
    end

    % Update the component model's description
    models = app.(compKey).models;
    index = find(strcmp({models.name}, compName));
    app.(compKey).uiLabel.Text = models(index).desc;

    % Clear the previous component model's UI
    gridLayout = app.uiGrids(compKey);
    delete(gridLayout.Children)

    % Create the UI for the new component model and store its params getter function
    app.(compKey).getParams = components.(compKey).(compName).createUI(gridLayout, params);
end


function defaultCompName = createComponentTab(app, compKey)
    switch compKey
        case "fluid"
            header = "Fluid";
            defaultCompName = "Hydrogen";
        case "ws"
            header = "Working Spaces";
            defaultCompName = "SinusoidalVolumes";
        case "chx"
            header = "Cold HXR";
            defaultCompName = "FixedApproach";
        case "regen"
            header = "Regenerator";
            defaultCompName = "FixedApproach";
        case "hhx"
            header = "Hot HXR";
            defaultCompName = "FixedApproach";
    end

    % Create the layout for this tab
    tab = uitab(app.tabGroup, "Title", header);
    tabGrid = uigridlayout(          ...
        tab,                         ...
        "RowHeight", {"fit", "1x"},  ...
        "ColumnWidth", {"1x"}        ...
    );
    tabTopGrid = uigridlayout(        ...
        tabGrid,                      ...
        "RowHeight", {"fit"},         ...
        "ColumnWidth", {"fit", "1x"}  ...
    );

    % Create the dropdown that selects which component model to use
    app.(compKey).uiDropdown = uidropdown(                        ...
        tabTopGrid,                                               ...
        "Items", {app.(compKey).models.name},                     ...
        "Value", defaultCompName,                                 ...
        "ValueChangedFcn",                                        ...
        @(src, event) app.updateComponentTab(compKey, src.Value)  ...
    );

    % Create the label that displays the model description
    app.(compKey).uiLabel = uilabel(tabTopGrid);

    % Create the grid layout used by the component model UI
    app.uiGrids(compKey) = uigridlayout(  ...
        tabGrid,                          ...
        "Padding", [10, 10, 10, 0]        ...
    );
end
