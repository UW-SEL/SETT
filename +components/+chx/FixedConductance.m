% Fixed Conductance Heat Exchanger

classdef FixedConductance < handle
    properties (Constant)
        defaultParams = struct(  ...
            "vol", 4e-5,         ...
            "UA", 400,           ...
            "R_hyd", 0,          ...
            "W_parasitic", 0     ...
        )
    end

    properties (SetAccess = private)
        % Interface Properties
        vol (1,1) double {mustBeReal}
        DT (1,1) double {mustBeReal}
        W_parasitic (1,1) double {mustBeReal}
        DP (1,:) double {mustBeReal}

        % Internal Properties
        UA (1,1) double
        R_hyd (1,1) double
    end

    methods
        function obj = FixedConductance(params)
            obj.vol = params.vol;
            obj.UA = params.UA;
            obj.R_hyd = params.R_hyd;
            obj.W_parasitic = params.W_parasitic;
        end

        function firstCallUpdate(obj, engine)
            % Provide an initial guess value for DT (before engine states are available)
            if obj.UA < 0  % negative UA indicates a perfect heat exchanger
                obj.DT = 0;
            else
                obj.DT = min(10, 0.1 * (engine.T_hot - engine.T_cold));
            end
        end

        function update(obj, engine)
            % Update the value for DT based on the current engine state
            if obj.UA < 0  % nothing to update for perfect heat exchanger
                obj.DT = 0;
                return
            end

            % Get total heat transfer rate
            Q_dot_c = 0;
            if ~isinf(engine.ws.R_c)
                Q_dot_c = engine.freq * trapz(                             ...
                    engine.stateValues.time,                               ...
                    (engine.stateValues.T_c - engine.T_k) / engine.ws.R_c  ...
                );
            end
            Q_dot_k = engine.freq * trapz(  ...
                engine.stateValues.time,    ...
                engine.stateValues.Q_dot_k  ...
            );
            Q_dot_avg = Q_dot_c + Q_dot_k;

            % Calculate average mass flow rate in the hxr
            m_dot_avgs = 0.5 * (engine.stateValues.m_dot_ck + engine.stateValues.m_dot_kr);
            m_dot_avg = engine.freq * trapz(  ...
                engine.stateValues.time,      ...
                abs(m_dot_avgs)               ...
            );

            % Calculate average capacitance rate
            fluidProps = engine.fluid.allProps(engine.T_k, engine.P_ave);
            C_dot_avg = fluidProps.CP * m_dot_avg;

            NTU = obj.UA / C_dot_avg;
            eff = 1 - exp(-NTU);
            obj.DT = (Q_dot_avg / C_dot_avg) * (1 / eff - 1);
        end

        function lastCallUpdate(obj, engine)
            % Update pressure drop values
            m_dot_avgs = 0.5 * (engine.stateValues.m_dot_ck + engine.stateValues.m_dot_kr);
            rho = engine.fluid.density(engine.T_k, engine.stateValues.P);
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
            inputs("W_parasitic") = createInput(       ...
                panelGrid,                             ...
                "Label", "Parasitic Mechanical Loss",  ...
                "Units", "W",                          ...
                "Value", params.W_parasitic,           ...
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
