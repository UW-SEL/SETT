classdef StirlingEngineApp < handle
    properties
        uiFigure
        tabGroup
        uiGrids
        engine
        getSolverParams function_handle
        getConditions function_handle
        fluid = struct(                            ...
            "name", "Fluid",                       ...
            "models", getComponentModels("fluid")  ...
        )
        ws = struct(                               ...
            "name", "Working Spaces",              ...
            "models", getComponentModels("ws")     ...
        )
        chx = struct(                              ...
            "name", "Cold HXR",                    ...
            "models", getComponentModels("chx")    ...
        )
        regen = struct(                            ...
            "name", "Regenerator",                 ...
            "models", getComponentModels("regen")  ...
        )
        hhx = struct(                              ...
            "name", "Hot HXR",                     ...
            "models", getComponentModels("hhx")    ...
        )
    end

    methods (Static)
        inputField = createNumericInput(container, options)
        panelGrid = createInputPanel(container, panelTitle)
    end

    methods (Access = public)
        function app = StirlingEngineApp()
            figWidth = 950;
            figHeight = 550;
            app.uiFigure = uifigure(                      ...
                "Name", "Stirling Engine App",            ...
                "Position", [0, 0, figWidth, figHeight],  ...
                "Visible", false                          ...
            );
            mainGrid = uigridlayout(         ...
                app.uiFigure,                ...
                "Padding", 0,                ...
                "RowHeight", {"1x", "fit"},  ...
                "ColumnWidth", {"1x"}        ...
            );
            app.tabGroup = uitabgroup(                   ...
                mainGrid,                                ...
                "SelectionChangedFcn", @app.onTabChange  ...
            );

            app.uiGrids = containers.Map;

            % Create the input tabs
            compKeys = ["fluid", "ws", "chx", "regen", "hhx"];
            for index = 1:length(compKeys)
                compKey = compKeys{index};
                app.updateComponentTab(compKey)
            end
            app.updateSolverTab()
            app.updateConditionsTab()

            % Initialize the engine
            config = app.getEngineConfig();
            app.engine = StirlingEngine(config);

            % Create the solution tab
            app.updateSolutionTab()

            % Create toolbar
            tb = uitoolbar(app.uiFigure);
            icons = fullfile(matlabroot, "toolbox", "matlab", "icons");
            openEngineFile = uipushtool(                   ...
                tb,                                        ...
                "Icon", fullfile(icons, "file_open.png"),  ...
                "Tooltip", "Open an engine file",          ...
                "ClickedCallback", @app.openEngine         ...
            );
            saveEngineFile = uipushtool(                   ...
                tb,                                        ...
                "Icon", fullfile(icons, "file_save.png"),  ...
                "Tooltip", "Save this engine",             ...
                "ClickedCallback", @app.saveEngine         ...
            );
            runEngine = uipushtool(                             ...
                tb,                                             ...
                "Icon", fullfile(icons, "greenarrowicon.gif"),  ...
                "Tooltip", "Update engine solution",            ...
                "ClickedCallback", @app.runEngine               ...
            );
            writeReport = uipushtool(                     ...
                tb,                                       ...
                "Icon", fullfile(icons, "book_sim.gif"),  ...
                "Tooltip", "Write engine report",         ...
                "ClickedCallback", @app.writeReport       ...
            );

            % Center the window and show it
            movegui(app.uiFigure, "center");
            app.uiFigure.Visible = true;

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            % This function is called before the app is deleted
            delete(app.uiFigure)
        end
    end

    methods (Access = private)
        function onTabChange(app, src, event)
            if strcmp(event.NewValue.Title, "Solution")
                % Check if the engine config is outdated
                currentConfig = app.getEngineConfig();
                if ~isequal(app.engine.config, currentConfig)
                    app.engine = StirlingEngine(currentConfig);
                    app.updateSolutionTab()
                end
            end
        end

        function openEngine(app, src, event)
            [file, folder] = uigetfile(             ...
                {"*.json", "Engine Config Files"},  ...
                "Open Engine Configuration"         ...
            );
            figure(app.uiFigure)  % makes GUI the front window after closing file dialog
            if isequal(file, 0) || isequal(folder, 0)
               return  % user canceled
            end

            % Create a modal that displays when config is loading
            modalHeight = 60;
            modalWidth = 250;
            appPosition = app.uiFigure.Position;
            modalLeft = appPosition(1) + (appPosition(3) - modalWidth) / 2;
            modalBottom = appPosition(2) + (appPosition(4) - modalHeight) / 2;
            modalFig = uifigure(                                            ...
                "Name", "Stirling Engine App",                              ...
                "WindowStyle", "modal",                                     ...
                "Position", [modalLeft modalBottom modalWidth modalHeight]  ...
            );
            uilabel(                                       ...
                modalFig,                                  ...
                "Text", "Opening engine file...",          ...
                "FontSize", 14,                            ...
                "Position", [0 0 modalWidth modalHeight],  ...
                "HorizontalAlignment", "center",           ...
                "VerticalAlignment", "center"              ...
            );
            drawnow()

            % Read file and update engine
            configFilePath = fullfile(folder, file);
            config = jsondecode(fileread(configFilePath));
            app.engine = StirlingEngine(config);

            % Update UI tabs with new engine values
            compKeys = {"fluid", "ws", "chx", "regen", "hhx"};
            for index = 1:length(compKeys)
                compKey = compKeys{index};
                compName = config.(compKey).model;
                if isfield(config.(compKey), "params")
                    compParams = config.(compKey).params;
                else
                    compParams = [];
                end
                app.(compKey).uiDropdown.Value = compName;
                app.updateComponentTab(compKey, compName, compParams);
            end
            app.updateSolverTab(config.solver)
            app.updateConditionsTab(config.conditions)
            app.updateSolutionTab()
            drawnow()

            % Close the modal
            delete(modalFig)
        end

        function runEngine(app, src, event)
            app.engine = StirlingEngine(app.getEngineConfig());
            app.engine.run("ShowResiduals", true);
            app.updateSolutionTab(true)
        end

        function saveEngine(app, src, event)
            % Check if the engine config is outdated
            currentConfig = app.getEngineConfig();
            if ~isequal(app.engine.config, currentConfig)
                app.engine = StirlingEngine(currentConfig);
                app.updateSolutionTab()  % necessary to prevent seeing outdated results
            end
            app.engine.save()
            figure(app.uiFigure)  % makes GUI the front window after closing file dialog
        end

        function writeReport(app, src, event)
            % Check if the engine config is outdated
            currentConfig = app.getEngineConfig();
            if ~isequal(app.engine.config, currentConfig)
                app.engine = StirlingEngine(currentConfig);
                app.updateSolutionTab()
            end
            if app.engine.isSolutionAvailable
                app.engine.report()
            else
                disp("The engine must be run before a report can be written")
            end
        end
    end
end



function r = getComponentModels(component)
    str = help(strcat("components.", component));
    lines = splitlines(str);
    lines = lines(3:end-1);
    s = cellfun(@splitHelp, lines);
    T = struct2table(s);
    sortedT = sortrows(T, "name");
    r = table2struct(sortedT);
end



function r = splitHelp(s)
    l = strtrim(s);
    x = strsplit(l, " - ");
    r = struct("name", x(1), "desc", x(2));
end
