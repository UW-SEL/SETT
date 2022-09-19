function panelGrid = createInputPanel(container, panelTitle, options)
    % CREATEINPUTPANEL Create a panel and return its inner grid (Static Method)
    %
    % The optional `fillWidth` and `fillHeight` arguments are used to adjust
    % how the panel is sized within its container.  The optional `numRows` is
    % only needed if `fillHeight` is true, which will stretch the inputs if
    % the correct number isn't specified.
    %
    % The panel's grid is configured to use three columns, which is appropriate
    % for rows of inputs created using the `createNumericInput` function.
    arguments
        container
        panelTitle
        options.fillWidth = false
        options.fillHeight = false
        options.numRows = 1
    end
    if options.fillWidth
        widthValue = "1x";
    else
        widthValue = "fit";
    end
    if options.fillHeight
        heightValue = "1x";
    else
        heightValue = "fit";
    end
    wrapper = uigridlayout(           ...
        container,                    ...
        "ColumnWidth", {widthValue},  ...
        "RowHeight", {heightValue},   ...
        "Padding", 0                  ...
    );
    panel = uipanel(         ...
        wrapper,             ...
        "Title", panelTitle  ...
    );
    columnWidth = {"fit", "fit", "fit"};
    rowHeight = cell(1, options.numRows);
    rowHeight(:) = {"fit"};
    panelGrid = uigridlayout(        ...
        panel,                       ...
        "ColumnWidth", columnWidth,  ...
        "RowHeight", rowHeight       ...
    );
end
