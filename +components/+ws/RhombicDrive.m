% Rhombic Drive Compression and Expansion Volumes

classdef RhombicDrive < handle
    properties (Constant)
        defaultParams = struct(         ...
            "frequency", 50,            ...
            "V_clearance_c", 5.785e-6,  ...
            "R_c", Inf,                 ...
            "W_parasitic_c", 0,         ...
            "V_clearance_e", 4.13e-6,   ...
            "R_e", Inf,                 ...
            "W_parasitic_e", 0,         ...
            "Q_parasitic_e", 0,         ...
            "r_crank", 0.01397,         ...
            "L_conn", 0.04602,          ...
            "eccentricity", 0.02065,    ...
            "D_p", 0.0698,              ...
            "D_d", 0.0696               ...
        )
    end

    properties (SetAccess = private)
        freq (1,1) double
        V_swept_c (1,1) double
        V_swept_e (1,1) double
        V_clearance_c (1,1) double
        V_clearance_e (1,1) double
        R_c (1,1) double
        R_e (1,1) double
        omega (1,1) double
        W_parasitic_c (1,1) double
        W_parasitic_e (1,1) double
        Q_parasitic_e (1,1) double
        isConverged (1,1) logical = true

        %geometric parameters
        r_crank (1,1) double
        L_conn (1,1) double
        e (1,1) double
        D_p (1,1) double
        D_d (1,1) double
    end

    methods
        function obj = RhombicDrive(params)
            obj.freq = params.frequency;
            obj.omega = 2 * pi * params.frequency;  % angular velocity (rad/s)
            obj.r_crank = params.r_crank;
            obj.L_conn = params.L_conn;
            obj.e = params.eccentricity;
            obj.D_p = params.D_p;
            obj.D_d = params.D_d;
            obj.V_clearance_c = params.V_clearance_c;
            obj.V_clearance_e = params.V_clearance_e;
            if ~isnumeric(params.R_c) && params.R_c == "Inf"
                obj.R_c = Inf;
            else
                obj.R_c = params.R_c;
            end
            if ~isnumeric(params.R_e) && params.R_e == "Inf"
                obj.R_e = Inf;
            else
                obj.R_e = params.R_e;
            end
            obj.W_parasitic_c = params.W_parasitic_c;
            obj.W_parasitic_e = params.W_parasitic_e;
            obj.Q_parasitic_e = params.Q_parasitic_e;
        end

        function [V_c, dVc_dt, V_e, dVe_dt] = values(obj, t)
            theta = obj.omega * t;  % rotation (rad)

            b_theta = sqrt(obj.L_conn^2 - (obj.e + obj.r_crank .* cos(theta)).^2);
            b_1 = sqrt(obj.L_conn^2 - (obj.e - obj.r_crank)^2);
            b_2 = sqrt((obj.L_conn - obj.r_crank)^2 - obj.e^2);
            b_3 = sqrt(obj.L_conn^2 - (obj.e + obj.r_crank)^2);
            b_4 = sqrt((obj.L_conn + obj.r_crank)^2 - obj.e^2);

            A_p = pi * obj.D_p^2 / 4;
            A_d = pi * obj.D_d^2 / 4;

            V_c = obj.V_clearance_c + 2 .* A_p .* (b_1 - b_theta);
            V_e = obj.V_clearance_e + A_d .* (b_theta - b_2 - obj.r_crank .* sin(theta));

            dVc_dtheta = -2 .* A_p .* obj.r_crank .* sin(theta) .* (obj.e + (obj.r_crank .* cos(theta))) ./ b_theta;
            dVc_dt = dVc_dtheta * obj.omega;

            dVe_dtheta = -((dVc_dtheta .* A_d) ./ (2 .* A_p)) - A_d .* obj.r_crank .* cos(theta);
            dVe_dt = dVe_dtheta * obj.omega;
            

            %swept volumes
            obj.V_swept_c = 2 .* A_p .* (b_1 - b_3);
            obj.V_swept_e = A_d .* (b_4 - b_2);
        end

        function firstCallUpdate(obj, engine)
            % (Not required for this model)
        end

        function update(obj, engine)
            % (Not required for this model)
        end

        function lastCallUpdate(obj, engine)
            % (Not required for this model)
        end
    end

    methods (Static)
        function getParams = createUI(gridLayout, params)
            inputs = containers.Map;
            createPanel = @StirlingEngineApp.createInputPanel;
            createInput = @StirlingEngineApp.createNumericInput;

            gridLayout.ColumnWidth = {"fit", "fit", "fit"};
            gridLayout.RowHeight = {"fit"};
            leftGrid = createPanel(gridLayout, "Common Parameters");
            middleGrid = createPanel(gridLayout, "Compression Space");
            rightGrid = createPanel(gridLayout, "Expansion Space");

            inputs("frequency") = createInput(  ...
                leftGrid,                       ...
                "Label", "Frequency",           ...
                "Units", "Hz",                  ...
                "Value", params.frequency,      ...
                "LowerLimit", 0                 ...
            );
            inputs("V_clearance_c") = createInput(  ...
                middleGrid,                         ...
                "Label", "Clearance Volume",        ...
                "Units", "m^3",                     ...
                "Value", params.V_clearance_c,      ...
                "LowerLimit", 0                     ...
            );
            inputs("R_c") = createInput(        ...
                middleGrid,                     ...
                "Label", "Thermal Resistance",  ...
                "Units", "K/W",                 ...
                "Value", params.R_c,            ...
                "LowerLimit", 0                 ...
            );
            inputs("W_parasitic_c") = createInput(     ...
                middleGrid,                            ...
                "Label", "Parasitic Mechanical Loss",  ...
                "Units", "W",                          ...
                "Value", params.W_parasitic_c,         ...
                "LowerLimit", 0                        ...
            );

            inputs("V_clearance_e") = createInput(  ...
                rightGrid,                          ...
                "Label", "Clearance Volume",        ...
                "Units", "m^3",                     ...
                "Value", params.V_clearance_e,      ...
                "LowerLimit", 0                     ...
            );
            inputs("R_e") = createInput(        ...
                rightGrid,                      ...
                "Label", "Thermal Resistance",  ...
                "Units", "K/W",                 ...
                "Value", params.R_e,            ...
                "LowerLimit", 0                 ...
            );
            inputs("W_parasitic_e") = createInput(     ...
                rightGrid,                             ...
                "Label", "Parasitic Mechanical Loss",  ...
                "Units", "W",                          ...
                "Value", params.W_parasitic_e,         ...
                "LowerLimit", 0                        ...
            );
            inputs("Q_parasitic_e") = createInput(  ...
                rightGrid,                          ...
                "Label", "Parasitic Thermal Loss",  ...
                "Units", "W",                       ...
                "Value", params.Q_parasitic_e,      ...
                "LowerLimit", 0                     ...
            );
            inputs("r_crank") = createInput(  ...
                leftGrid,                     ...
                "Label", "Crank Radius",      ...
                "Units", "m",                 ...
                "Value", params.r_crank,      ...
                "LowerLimit", 0               ...
            );
            inputs("L_conn") = createInput(        ...
                leftGrid,                          ...
                "Label", "Connecting Rod Length",  ...
                "Units", "m",                      ...
                "Value", params.L_conn,            ...
                "LowerLimit", 0                    ...
            );
            inputs("eccentricity") = createInput(  ...
                leftGrid,                          ...
                "Label", "Eccentricity",           ...
                "Units", "m",                      ...
                "Value", params.eccentricity,      ...
                "LowerLimit", 0                    ...
            );
            inputs("D_p") = createInput(           ...
                leftGrid,                          ...
                "Label", "Power Piston Diameter",  ...
                "Units", "m",                      ...
                "Value", params.D_p,               ...
                "LowerLimit", 0                    ...
            );
            inputs("D_d") = createInput(        ...
                leftGrid,                       ...
                "Label", "Displacer Diameter",  ...
                "Units", "m",                   ...
                "Value", params.D_d,            ...
                "LowerLimit", 0                 ...
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
