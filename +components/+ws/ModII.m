% ModII / ModI_A Engine working space model
%
% TODO: Update the below comment when component is finalized:
%
% This is the model of the Mod I working spaces
% The model returns friction based on a curve fit to the values in the
% design review and auxiliary power from the same source

classdef ModII < handle
    properties (Constant)
        defaultParams = struct(          ...
            "frequency", 66.6667,        ... %frequency of the engine (rev/s)
            "phaseAngle", 90,            ... %phase angle between compression and expansion space (degree)
            "D", 0.0680,                 ... %bore diameter (m)
            "h", 0.000163,               ... %clearance between piston and cylinder (m)
            "L", 0.0435,                 ... %length of piston/cylinder gap (m)
            "stroke", 0.034,             ... %stroke (m)
            "V_clearance_c", 25.4e-6,    ... %clearance volume in compression space (m^3)
            "R_c", Inf,                  ... %thermal resistance between compression space gas and wall (K/W)
            "V_clearance_e", 12.1e-6,    ... %clearance volume in expansion space (m^3)
            "R_e", Inf,                  ... %thermal resistance between expansion space gas and wall (K/W)
            "material_p", "AISI1010",    ... %piston material (must be available in Solid.m)
            "material_c", "Stellite21",  ... %cylinder material (must be available in Solid.m)
            "th_pw", 0.005,              ... %piston wall thickness
            "th_cw", 0.008,              ... %cylinder wall thickness
            "L_cond", 0.075,             ... %length to use in conduction calculation
            "e", 0.5                     ... %emissivity to use in radiation calculation
        )
    end

    properties (SetAccess = private)
        freq (1,1) double
        V_swept (1,1) double
        D (1,1) double
        h (1,1) double
        L (1,1) double
        stroke (1,1) double
        V_clearance_c (1,1) double
        V_clearance_e (1,1) double
        R_c (1,1) double
        R_e (1,1) double
        radPhaseAngle (1,1) double
        omega (1,1) double
        material_p (1,1) string
        material_c (1,1) string
        th_pw (1,1) double
        th_cw (1,1) double
        L_cond (1,1) double
        e (1,1) double
        W_parasitic_c (1,1) double
        W_parasitic_e (1,1) double
        Q_parasitic_e (1,1) double
        isConverged (1,1) logical = true
        rpt (17,1) double
    end

    methods
        function obj = ModII(params)
            obj.freq = params.frequency;
            obj.omega = 2 * pi * params.frequency;  % angular velocity (rad/s)
            obj.radPhaseAngle = params.phaseAngle * pi / 180;  % convert degrees to radians
            obj.D = params.D;
            obj.L = params.L; 
            obj.h = params.h;
            obj.material_c = params.material_c;
            obj.material_p = params.material_p;
            obj.th_cw = params.th_cw;
            obj.th_pw = params.th_pw;
            obj.L_cond = params.L_cond;
            obj.e = params.e;
            obj.stroke = params.stroke;
            obj.V_swept = pi*obj.D^2*obj.stroke/4;
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
            obj.W_parasitic_c = 0;
            obj.W_parasitic_e = 0;
            obj.Q_parasitic_e = 0;
        end

        function [V_c, dVc_dt, V_e, dVe_dt] = values(obj, t)
            theta = obj.omega * t;  % rotation (rad)

            V_c = obj.V_clearance_c + 0.5 * obj.V_swept * (1 + cos(theta));
            V_e = obj.V_clearance_e + 0.5 * obj.V_swept * (1 + cos(theta + obj.radPhaseAngle));

            dVc_dt = -0.5 * obj.V_swept * sin(theta) * obj.omega;
            dVe_dt = -0.5 * obj.V_swept * sin(theta + obj.radPhaseAngle) * obj.omega;
        end

        function firstCallUpdate(obj, engine)
            % (Not required for this model)
        end

        function update(obj, engine)
            %get shuttle heat transfer
            t = engine.stateValues.time;
            P = engine.stateValues.P;
            P_max = max(P); %max pressure
            P_min = min(P); %min pressure
            t_max = t(find(P==P_max,1));
            phi = 2*pi*t_max*engine.freq - pi/2;
            DP = (P_max - P_min)/2; %pressure amplitude
            [SHL]=util.shuttleheattransfer(obj.D, obj.h, obj.L, obj.stroke, obj.omega, obj.material_c, DP, engine, phi);
            
            %get conduction heat transfer
            gv(1) = pi*obj.D*obj.th_cw;
            gv(2) = obj.L_cond;
            [Q_dot_cw] = util.conduction(obj.material_c, engine.T_l, engine.T_k, "plane", "avgk", gv);
            gv(1) = pi*obj.D*obj.th_pw;
            gv(2) = obj.L_cond;
            [Q_dot_pw] = util.conduction(obj.material_p, engine.T_l, engine.T_k, "plane", "avgk", gv);
            
            %get radiation
            A = pi*obj.D^2;
            sigma = 5.67e-8;
            Eb_h = sigma*engine.T_l^4;
            Eb_c = sigma*engine.T_k^4;
            R_s = (1-obj.e)/(obj.e*A);
            R_cf = 1/A;
            Q_dot_rad = (Eb_h - Eb_c)/(2*R_s + R_cf);
            
            obj.Q_parasitic_e = SHL + Q_dot_cw + Q_dot_pw + Q_dot_rad;
            
            obj.rpt(1) = SHL;
            obj.rpt(2) = Q_dot_pw;
            obj.rpt(3) = Q_dot_cw;
            obj.rpt(4) = Q_dot_rad;
        end

        function lastCallUpdate(obj, engine)
                                
            %get friction
            W_dot_f=1000*(0.0029098034-0.00067365469*engine.P_ave/1e6+0.013309624*engine.freq+0.0026824721*engine.P_ave*engine.freq/1e6);
            
            %get auxiliaries
            if(engine.freq<10)
                W_dot_alt = 1000*0.03;
            else
                Np = engine.freq - 10;
                Wp=0.000743954488 - 0.0000171022802*Np + 0.000027253729*Np^2 + 6.09726726E-07*Np^3;
                W_dot_alt = 1000*(0.03 + Wp);
            end
            W_dot_comp=1000*(0.0417182766 - 0.00024188924*engine.freq + 0.0000660561324*(engine.freq)^2 + 2.75839528E-07*(engine.freq)^3);
            W_dot_oil=1000*(0.0463827616 + 0.00182974022*engine.freq + 0.0000734612745*engine.freq^2 + 7.77522319E-07*engine.freq^3);
            obj.W_parasitic_e = W_dot_f + W_dot_alt + W_dot_comp + W_dot_oil;
            

            obj.rpt(5) = W_dot_f;
            obj.rpt(6) = W_dot_alt;
            obj.rpt(7) = W_dot_comp;
            obj.rpt(8) = W_dot_oil;
            
        end
        
        function lines = report(obj)
            % Return a string array that will be included in the engine report
            % (This function is optional)
            lines = [
                sprintf("Shuttle heat transfer = %.4f W", obj.rpt(1)),
                sprintf("Conduction through cylinder wall = %.4f W", obj.rpt(2)),
                sprintf("Conduction heat transfer through piston wall = %.4f W", obj.rpt(3)),
                sprintf("Radiation heat transfer through piston = %.4f W", obj.rpt(4)),
                sprintf("Total working space heat transfer parasitic = %.4f W", obj.Q_parasitic_e),
                sprintf("Friction per cylinder = %.4f W", obj.rpt(5)),
                sprintf("Alternator power per cylinder = %.4f W", obj.rpt(6)),
                sprintf("Gas compressor per cylinder = %.4f W", obj.rpt(7)),
                sprintf("Oil pump per cylinder = %.4f W", obj.rpt(8)),
                sprintf("Total mechanical parasitic per cylinder = %.4f W", obj.W_parasitic_e)
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
            inputs("phaseAngle") = createInput(  ...
                leftGrid,                        ...
                "Label", "Phase Angle",          ...
                "Units", "deg",                  ...
                "Value", params.phaseAngle,      ...
                "LowerLimit", 0,                 ...
                "UpperLimit", 360                ...
            );
            inputs("D") = createInput(        ...
                leftGrid,                     ...
                "Label", "Bore diameter",     ...
                "Units", "m",                 ...
                "Value", params.D,            ...
                "LowerLimit", 0,              ...
                "LowerLimitInclusive", "off"  ...
            );
            inputs("stroke") = createInput(   ...
                leftGrid,                     ...
                "Label", "Stroke",            ...
                "Units", "m",                 ...
                "Value", params.stroke,       ...
                "LowerLimit", 0,              ...
                "LowerLimitInclusive", "off"  ...
            );
            inputs("th_pw") = createInput(         ...
                leftGrid,                          ...
                "Label", "Piston wall thickness",  ...
                "Units", "m",                      ...
                "Value", params.th_pw,             ...
                "LowerLimit", 0,                   ...
                "LowerLimitInclusive", "off"       ...
            );
            inputs("th_cw") = createInput(           ...
                leftGrid,                            ...
                "Label", "Cylinder wall thickness",  ...
                "Units", "m",                        ...
                "Value", params.th_cw,               ...
                "LowerLimit", 0,                     ...
                "LowerLimitInclusive", "off"         ...
            );
            inputs("L_cond") = createInput(    ...
                leftGrid,                      ...
                "Label", "Conduction length",  ...
                "Units", "m",                  ...
                "Value", params.L_cond,        ...
                "LowerLimit", 0,               ...
                "LowerLimitInclusive", "off"   ...
            );
            inputs("e") = createInput(                       ...
                leftGrid,                                    ...
                "Label", "Emissivity to use for radiation",  ...
                "Units", "-",                                ...
                "Value", params.e,                           ...
                "LowerLimit", 0,                             ...
                "LowerLimitInclusive", "off"                 ...
            );
            uilabel(                            ...
                leftGrid,                       ...
                "Text", "Material for piston",  ...
                "HorizontalAlignment", "right"  ...
            );
            inputs("material_p") = uidropdown(  ...
                leftGrid,                       ...
                "Items", [                      ...
                    "Stainless Steel",          ...
                    "SS304",                    ...
                    "Stellite21",               ...
                    "Inconel",                  ...
                    "Titanium",                 ...
                    "AISI1010",                 ...
                    "Nickel"                    ...
                ],                              ...
                "Value", params.material_p      ...
            );
            uilabel(leftGrid, "Text", "");  % spacer
            uilabel(                              ...
                leftGrid,                         ...
                "Text", "Material for cylinder",  ...
                "HorizontalAlignment", "right"    ...
            );
            inputs("material_c") = uidropdown(  ...
                leftGrid,                       ...
                "Items", [                      ...
                    "Stainless Steel",          ...
                    "SS304",                    ...
                    "Stellite21",               ...
                    "Inconel",                  ...
                    "Titanium",                 ...
                    "AISI1010",                 ...
                    "Nickel"                    ...
                ],                              ...
                "Value", params.material_c      ...
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
            inputs("h") = createInput(     ...
                rightGrid,                 ...
                "Label", "gas gap width",  ...
                "Units", "m",              ...
                "Value", params.h,         ...
                "LowerLimit", 0            ...
            );
            inputs("L") = createInput(      ...
                rightGrid,                  ...
                "Label", "gas gap length",  ...
                "Units", "m",               ...
                "Value", params.L,          ...
                "LowerLimit", 0             ...
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
