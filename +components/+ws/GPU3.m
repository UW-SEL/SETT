% GPU3 Compression and Expansion Volumes - with appendix gas gap losses

classdef GPU3 < handle
    properties (Constant)
        defaultParams = struct(         ...
            "frequency", 25,            ...  "Hz, frequency"
            "V_clearance_c", 5.785e-6,  ...  "m^3, compression space clearanace volume"
            "R_c", Inf,                 ...  "K/W, thermal resistance between gas and compression space"
            "V_clearance_e", 4.13e-6,   ...  "m^3, expansion space clearanace volume"
            "R_e", Inf,                 ...  "K/W, thermal resistance between gas and compression space"
            "r_crank", 0.01397,         ...  "m, rhombic drive crank radius"
            "L_conn", 0.04602,          ...  "m, rhombic drive connector length"
            "eccentricity", 0.02065,    ...  "m, rhombic drive eccentricity"
            "D", 0.0701,                ...  "m, piston diameter"
            "D_dr", 0.00953,            ...  "m, drive rod diameter"
            "L", 0.0436,                ...  "m, length of piston/wall gap"
            "h", 0.000163               ...  "m, clearance between piston wall and piston"
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
        D_dr (1,1) double
        A_p (1,1) double
        A_d (1,1) double
        D (1,1) double
        h (1,1) double
        L (1,1) double
        X_d (1,1) double
        
        %performance
        H_dot_sh (1,1) double
        Q_dot_cond_e (1,1) double
        W_dot_fr (1,1) double
        P_max (1,1) double
    end

    methods
        function obj = GPU3(params)
            obj.freq = params.frequency;
            obj.omega = 2 * pi * params.frequency;  % angular velocity (rad/s)
            obj.r_crank = params.r_crank;
            obj.L_conn = params.L_conn;
            obj.e = params.eccentricity;
            obj.D = params.D;
            obj.D_dr = params.D_dr;
            obj.L = params.L;
            obj.h = params.h;
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
            obj.Q_parasitic_e = 0;  %set during last call
            
            obj.A_p = pi*obj.D^2/4; %m^2, piston area
            obj.A_d = obj.A_p - pi*obj.D_dr^2/4;  %m^2, displacer area
        end

        function [V_c, dVc_dt, V_e, dVe_dt] = values(obj, t)
            theta = obj.omega * t;  % rotation (rad)

            b_theta = sqrt(obj.L_conn^2 - (obj.e + obj.r_crank .* cos(theta)).^2);
            b_1 = sqrt(obj.L_conn^2 - (obj.e - obj.r_crank)^2);
            b_2 = sqrt((obj.L_conn - obj.r_crank)^2 - obj.e^2);
            b_3 = sqrt(obj.L_conn^2 - (obj.e + obj.r_crank)^2);
            b_4 = sqrt((obj.L_conn + obj.r_crank)^2 - obj.e^2);

            V_c = obj.V_clearance_c + 2 .* obj.A_p .* (b_1 - b_theta);
            V_e = obj.V_clearance_e + obj.A_d .* (b_theta - b_2 - obj.r_crank .* sin(theta));

            dVc_dtheta = -2 .* obj.A_p .* obj.r_crank .* sin(theta) .* (obj.e + (obj.r_crank .* cos(theta))) ./ b_theta;
            dVc_dt = dVc_dtheta * obj.omega;

            dVe_dtheta = -((dVc_dtheta .* obj.A_d) ./ (2 .* obj.A_p)) - obj.A_d .* obj.r_crank .* cos(theta);
            dVe_dt = dVe_dtheta * obj.omega;
            

            %swept volumes
            obj.V_swept_c = 2 .* obj.A_p .* (b_1 - b_3);
            obj.V_swept_e = obj.A_d .* (b_4 - b_2);
            obj.X_d = obj.V_swept_e/obj.A_d;
        end

        function firstCallUpdate(obj, engine)
            % (Not required for this model)
        end

        function update(obj, engine)
            % (Not required for this model)
        end

        function lastCallUpdate(obj, engine)
            %get shuttle heat transfer
            t = engine.stateValues.time;
            P = engine.stateValues.P;
            obj.P_max = max(P); %max pressure
            P_min = min(P); %min pressure
            t_max = t(find(P==obj.P_max,1));
            phi = 2*pi*t_max*engine.freq - pi/2;
            DP = (obj.P_max - P_min)/2; %pressure amplitude
            [SHL]=util.shuttleheattransfer(obj.D, obj.h, obj.L, obj.X_d, obj.omega, 'SS304', DP, engine, phi);
            obj.H_dot_sh=SHL;
                        
            %estimate conduction loss
            R_all = 0.61; %K/W, total thermal resistance from Martinelli
            obj.Q_dot_cond_e = (engine.T_l - engine.T_k)/R_all;
            obj.Q_parasitic_e = obj.H_dot_sh + obj.Q_dot_cond_e;
            
            %Friction
            Pressure=engine.P_ave/1e6;
            N = obj.freq*60;
            %Friction=0+0.22905801*Pressure-0.024248599*Pressure^2-0.00051029684*N+2.6561433E-7*N^2+0.000038763495*Pressure*N;  %the average friction at each data point correlated with P and N
            %Friction=0.86965403+0.065986581*Pressure-0.0127752*Pressure^2-0.00091780314*N+3.2678571E-7*N^2+0.000057901465*Pressure*N;
            %Friction=0.38637407+0.12426242*Pressure-0.014532836*Pressure^2-0.00062017736*N+2.7000000E-7*N^2+0.00003392277*Pressure*N;
            Friction=-0.30378556+0.086701731*Pressure+2.0086292E-7*N^2;  %average friction correlation not including cross terms to allow extrapoloation
            
            obj.W_dot_fr = Friction*1000;
            obj.W_parasitic_e = obj.W_dot_fr;
            obj.W_parasitic_c = 0;
        end
        
       function lines = report(obj)
            % Return a string array that will be included in the engine report
            % (This function is optional)
            lines = [
                sprintf("Friction = %.4f W", obj.W_dot_fr),
                sprintf("Shuttle heat transfer = %.4f W", obj.H_dot_sh),
                sprintf("Conduction loss (all paths) = %.4f W", obj.Q_parasitic_e)
                ];
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
            inputs("D") = createInput(       ...
                leftGrid,                    ...
                "Label", "Piston diameter",  ...
                "Units", "m",                ...
                "Value", params.D,           ...
                "LowerLimit", 0              ...
            );
            inputs("D_dr") = createInput(       ...
                leftGrid,                       ...
                "Label", "Drive Rod Diameter",  ...
                "Units", "m",                   ...
                "Value", params.D_dr,           ...
                "LowerLimit", 0                 ...
            );

            inputs("L") = createInput(                 ...
                leftGrid,                              ...
                "Label", "Piston-to-Wall Gap Length",  ...
                "Units", "m",                          ...
                "Value", params.L,                     ...
                "LowerLimit", 0                        ...
            );

            inputs("h") = createInput(                   ...
                leftGrid,                                ...
                "Label", "Piston-toWall Gap Clearance",  ...
                "Units", "m",                            ...
                "Value", params.h,                       ...
                "LowerLimit", 0                          ...
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
