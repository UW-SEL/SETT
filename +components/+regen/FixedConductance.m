% Fixed Conductance Regenerator

classdef FixedConductance < handle
    properties (Constant)
        defaultParams = struct(  ...
            "vol", 0.0001,       ...
            "UA", 70000,         ...
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
        UA (1,1) double
        R_hyd (1,1) double
        eff (1,1) double
    end

    methods
        function obj = FixedConductance(params)
            obj.vol = params.vol;
            obj.UA = params.UA;
            obj.R_hyd = params.R_hyd;
            obj.Q_parasitic = params.Q_parasitic;
        end

        function firstCallUpdate(obj, engine)
            % Provide an initial guess value for DT (before engine states are available)
            obj.DT = min(10, 0.1 * (engine.T_hot - engine.T_cold));
        end

        function update(obj, engine)
            % Update the value for DT based on the current engine state
            % TODO: add catch for UA < 0 is a perfect hxr

            % Calculate average capacitance rate
            m_dot_avgs = 0.5 * (engine.stateValues.m_dot_kr + engine.stateValues.m_dot_rl);
            CPs = engine.fluid.allProps(engine.T_r, engine.stateValues.P).CP;
            C_dot_avg = engine.freq * trapz(  ...
                engine.stateValues.time,      ...
                abs(m_dot_avgs) .* CPs        ...
            );

            % TODO: verify these equations
            NTU=obj.UA/C_dot_avg;
            obj.eff=(NTU/2)/(1+(NTU/2));
            obj.DT=(1-obj.eff)*(engine.T_l-engine.T_k);
        end

        function lastCallUpdate(obj, engine)
            % Update pressure drop values
            m_dot_avgs = 0.5 * (engine.stateValues.m_dot_kr + engine.stateValues.m_dot_rl);
            rho = engine.fluid.density(engine.T_r, engine.stateValues.P);
            V_dot = m_dot_avgs ./ rho;
            obj.DP = obj.R_hyd * V_dot;
        end

        function lines = report(obj)
            % Return a string array that will be included in the engine report
            % (This function is optional)
            lines = [
                sprintf(" UA = %g kW/K", obj.UA / 1000),
                sprintf("Eff = %.4f", obj.eff),
            ];
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

            inputs("vol") = createInput(      ...
                panelGrid,                    ...
                "Label", "Volume",            ...
                "Units", "m^3",               ...
                "Value", params.vol,          ...
                "LowerLimit", 0,              ...
                "LowerLimitInclusive", "off"  ...
            );
            inputs("UA") = createInput(  ...
                panelGrid,               ...
                "Label", "UA",           ...
                "Units", "W/K",          ...
                "Value", params.UA,      ...
                "LowerLimit", -1         ...
            );
            inputs("R_hyd") = createInput(        ...
                panelGrid,                        ...
                "Label", "Hydraulic Resistance",  ...
                "Units", "Pa-s/m^3",              ...
                "Value", params.R_hyd,            ...
                "LowerLimit", 0                   ...
            );
            inputs("Q_parasitic") = createInput(       ...
                panelGrid,                             ...
                "Label", "Parasitic Thermal Loss",     ...
                "Units", "W",                          ...
                "Value", params.Q_parasitic,           ...
                "LowerLimit", 0                        ...
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
