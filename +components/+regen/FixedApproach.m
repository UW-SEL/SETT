% Fixed Approach Regenerator

classdef FixedApproach < handle
    properties (Constant)
        defaultParams = struct(  ...
            "vol", 1e-4,         ...
            "DT", 10,            ...
            "R_hyd", 0,          ...
            "Q_parasitic", 0     ...
        )
    end

    properties (SetAccess = private)
        % Interface Properties
        vol (1,1) double {mustBeReal}
        DT (1,1) double {mustBeReal}
        Q_parasitic (1,1) double {mustBeReal}
        DP (1,:) double {mustBeReal}

        % Internal Properties
        R_hyd (1,1) double
    end

    methods
        function obj = FixedApproach(params)
            obj.vol = params.vol;
            obj.DT = params.DT;
            obj.R_hyd = params.R_hyd;
            obj.Q_parasitic = params.Q_parasitic;
        end

        function firstCallUpdate(obj, engine)
            % Provide an initial guess value for DT before engine states are available
            % (Not required for this model)
        end

        function update(obj, engine)
            % Update the value for DT based on the current engine state
            % (Not required for this model)
        end

        function lastCallUpdate(obj, engine)
            % Update pressure drop values
            m_dot_avgs = 0.5 * (engine.stateValues.m_dot_kr + engine.stateValues.m_dot_rl);
            rho = engine.fluid.density(engine.T_r, engine.stateValues.P);
            V_dot = m_dot_avgs ./ rho;
            obj.DP = obj.R_hyd * V_dot;
        end
    end

    methods (Static)
        function getParams = createUI(gridLayout, params)
            inputs = containers.Map;
            createPanel = @StirlingEngineApp.createInputPanel;
            createInput = @StirlingEngineApp.createNumericInput;

            gridLayout.ColumnWidth = {"fit"};
            gridLayout.RowHeight = {"fit"};
            panelGrid = createPanel(gridLayout, "Parameters");

            inputs("vol") = createInput(     ...
                panelGrid,                   ...
                "Label", "Void Volume",      ...
                "Units", "m^3",              ...
                "Value", params.vol,         ...
                "LowerLimit", 0,             ...
                "LowerLimitInclusive","off"  ...
            );
            inputs("DT") = createInput(  ...
                panelGrid,               ...
                "Label", "Minimum ΔT",   ...
                "Units", "K",            ...
                "Value", params.DT,      ...
                "LowerLimit", 0          ...
            );
            inputs("R_hyd") = createInput(        ...
                panelGrid,                        ...
                "Label", "Hydraulic Resistance",  ...
                "Units", "Pa-s/m^3",              ...
                "Value", params.R_hyd,            ...
                "LowerLimit", 0                   ...
            );
            inputs("Q_parasitic") = createInput(    ...
                panelGrid,                          ...
                "Label", "Parasitic Thermal Loss",  ...
                "Units", "W",                       ...
                "Value", params.Q_parasitic,        ...
                "LowerLimit", 0                     ...
            );

            getParams = @getParamsFunc;
            function r = getParamsFunc()
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
    end
end
