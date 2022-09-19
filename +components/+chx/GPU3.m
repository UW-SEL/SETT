% GPU-3 Cold Heat Exchanger
%
% This model assumes known inlet water temperature and flow.

classdef GPU3 < handle
    properties (Constant)
        defaultParams = struct(      ...
            "length_total", 0.0461,  ... %m, total length of tubes
            "length_ht", 0.0355,     ... %m, length of tubes exposed to water
            "D_inner", 0.00108,      ... %m, inner diameter of tubes
            "D_outer", 0.00159,      ... %m, outer diameter of tubes
            "N_total", 312,          ... % -, total number of tubes
            "N_shell", 8,            ... %-, number of shells (1 per regenerator)
            "D_sh", 0.0226,          ... %m, diameter of shell (should be same as regenerator)
            "Ac_h", 2.2386e-4,       ... %m^2, cross sectional area of ducts (all of them) carrying flow from cooler to compression space
            "roughness", 1.5e-6,     ... %m, roughness
            "vol_h", 1e-5,           ... %m^3, header volume
            "m_dot_w", 0.136,        ... %kg/s, mass flow rate of water
            "coolant", "Water",      ... %type of coolant
            "m_dot_a", 0.35,         ... %kg/s, mass flow rate of air
            "UA_a", 500,             ... %W/K, conductance of air-to-water cooler, note if UA_a<0 then defaults to only simulating the cooler
            "W_parasitic", 0         ... %W, parasitic - set to zero to ignore pump/fan power
        )
    end

    properties (SetAccess = private)
        % Interface Properties
        vol (1,1) double {mustBeReal}
        DT (1,1) double {mustBeReal}
        W_parasitic (1,1) double {mustBeReal}
        DP (1,:) double {mustBeReal}

        % Internal Properties
        R_hyd (1,1) double
        L_t (1,1) double
        L_ht (1,1) double
        D_o (1,1) double
        D_i (1,1) double
        N_t (1,1) double
        N_shell (1,1) double
        R_sh (1,1) double
        Ac_h (1,1) double
        vol_h (1,1) double
        m_dot_w (1,1) double
        coolant (1,1) string
        m_dot_a (1,1) double
        UA_a (1,1) double
        roughness (1,1) double
        rpt (19,1) double
    end

    methods
        function obj = GPU3(params)
            obj.L_t = params.length_total;
            obj.L_ht = params.length_ht;
            obj.D_o = params.D_outer;
            obj.D_i = params.D_inner;
            obj.N_t = params.N_total;
            obj.N_shell = params.N_shell;
            obj.R_sh = params.D_sh/2;
            obj.Ac_h = params.Ac_h;
            obj.roughness = params.roughness;
            obj.vol_h = params.vol_h;
            obj.m_dot_w = params.m_dot_w;
            obj.coolant = params.coolant;
            obj.m_dot_a = params.m_dot_a;
            obj.UA_a = params.UA_a;
            obj.W_parasitic = params.W_parasitic;

            % Calculate fluid volume inside tubes
            obj.vol = obj.L_t * obj.N_t * pi * obj.D_i^2 / 4 + obj.vol_h;
        end

        function firstCallUpdate(obj, engine)
            % Provide an initial guess value for DT (before engine states are available)
            obj.DT = min(50, 0.1 * (engine.T_hot - engine.T_cold));
        end

        function update(obj, engine)
            % Update the value for DT based on the current engine state

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
         
            % Calculate average fluid properties in the CHX
            fluidProps = engine.fluid.allProps(engine.T_k, engine.P_ave);

            %average mass flow rate, velocity, & capacitance rate
            cp_g = fluidProps.CP;
            C_dot_avg = cp_g * m_dot_avg;
            rho_g = fluidProps.rho;
            
            %get DP and h in tube assuming steady flow
            [DP_tube, h_g] = util.tubeFlow(fluidProps, m_dot_avg/obj.N_t, obj.D_i, obj.L_t, obj.roughness);
            
            %get additional DP related to contraction & expansion
            [DP_minor] = util.K_tubearray(fluidProps,  m_dot_avg/obj.N_shell, obj.D_i, obj.L_t, obj.N_t/obj.N_shell, 2*obj.R_sh);         
            
            %additional minor loss due to CHX to compression space header
            u_h=m_dot_avg/(rho_g*obj.Ac_h);
            K_h = 2.5; %assumed minor loss coefficient
            DP_h = K_h*rho_g*u_h^2/2;            
            DP_g = DP_tube+DP_minor+DP_h;  %total steady pressure loss
            
            A_c=pi*obj.D_i^2/4;  %cross-sectional area of a tube
            u_max=m_dot_avg/(rho_g*A_c*obj.N_t)*sqrt(2);  %approximate max velocity
            [MF_DP, MF_h] = util.oscillatingFlow(fluidProps, obj.D_i, engine.freq, u_max);  %get oscillating flow multipliers
            DP_g = MF_DP*DP_g;
            h_g = MF_h*h_g;
            
            obj.R_hyd = DP_g / (m_dot_avg / rho_g);
           
            %Determine coolant side characteristics         
            rho_c = 1000;
            mu_c = 0.00035;
            k_c = 0.667;
            c_c = 4200;
            Pr_c = mu_c*c_c/k_c;         
            
            %set up a tube bank with the right chararacteristics
            phi=(obj.N_t/obj.N_shell)*pi*obj.D_o^2/4/(pi*obj.R_sh^2); %porosity - fluid volume/tube volume
            S_D=sqrt(pi*obj.D_o^2/(4*phi*cos(pi/6)));  %this computes the diagonal spacing in an HCP array required to get the porosity
            S_T=S_D;  %transverse pitch is the same as diagonal pitch
            S_L=S_D*cos(pi/6);  %longitudinal pitch is the reduced
            W=obj.R_sh*sqrt(pi);  %tube bank is modeled as a square with dimension WxW
            N_L = floor(W/S_L);    %number of tubes  in flow direction
            
            %tube bank correlations
            u=obj.m_dot_w/(2*W*obj.L_ht*rho_c);  %frontal velocity of coolant - mass flow is split into two circuits
            [~, h_c] = util.TubeBank(u, N_L, obj.D_o, S_T, S_L, rho_c, mu_c, k_c, Pr_c);
            
            %resistance to tube wall
            [~, ~, k_t] = util.properties.Solid('SS304', (engine.T_cold+engine.T_k)/2);  %tube conductivity
            R_t = log(obj.D_o / obj.D_i) / (2 * pi * k_t * obj.L_ht * obj.N_t);  %tube thermal resistance

            %determine total conductance
            R_g = 1 / (h_g * obj.N_t * obj.D_i * pi * obj.L_ht); %gas to tube resistance
            R_ct = 1 / (h_c * obj.N_t * obj.D_o * pi * obj.L_ht);  %coolant to tube resistance
            R_total = R_g + R_ct + R_t;  %total resistance
            UA_c = 1 / R_total;  %total conductance of cooler

            %determine approach temperature difference
            C_dot_w = obj.m_dot_w * c_c;  %capacitance rate of coolant 
            C_dot_min = min(C_dot_w, C_dot_avg); 
            C_dot_max = max(C_dot_w, C_dot_avg);
            NTU_c = UA_c / C_dot_min;  %NTU of shell and tube coolers
            Cr = C_dot_min / C_dot_max;  %capacitance ratio of shell and tube coolers
            eff_c = (1 / (1 - exp(-NTU_c)) + Cr / (1 - exp(-Cr * NTU_c)) - 1 / NTU_c)^(-1); %effectiveness of shell and tube coolers
            
            if(obj.UA_a>0) 
                c_a = 1007;  %specific heat capacity of air
                C_dot_a = obj.m_dot_a*c_a; %air capacitance rate
                C_dot_a_min = min(C_dot_w, C_dot_a);
                C_dot_a_max = max(C_dot_w, C_dot_a);
                NTU_a = obj.UA_a/C_dot_a_min;
                CR_a = C_dot_a_min/C_dot_a_max;
                eff_a = 1-exp(NTU_a^0.22/CR_a*(exp(-CR_a*NTU_a^0.78)-1));
                obj.DT = Q_dot_avg*(1/(eff_a*C_dot_a_min)+1/(eff_c*C_dot_min)-1/C_dot_avg-1/C_dot_w);
                DT_g=Q_dot_avg/C_dot_avg;
                DT_c=Q_dot_avg/C_dot_w;
                DT_a=Q_dot_avg/C_dot_a;
            else
                obj.DT = Q_dot_avg * (1 / (eff_c * C_dot_min) - 1 / C_dot_avg);
                DT_c=Q_dot_avg/C_dot_w;
                DT_g=Q_dot_avg/C_dot_avg;
                DT_a=-999;
                eff_a=-999;
            end    
            
             %parameters in report
             obj.rpt(1) = obj.m_dot_w;
             obj.rpt(2) = h_c;
             obj.rpt(3) = R_ct;
             obj.rpt(4) = m_dot_avg;
             obj.rpt(5) = h_g;
             obj.rpt(6) = R_g;
             obj.rpt(7) = R_t;
             obj.rpt(8) = R_total;
             obj.rpt(9) = NTU_c;
             obj.rpt(10) = Cr;
             obj.rpt(11) = eff_c;
             obj.rpt(12) = DT_c;
             obj.rpt(13) = DT_g;
             obj.rpt(14) = DP_tube;
             obj.rpt(15) = DP_minor;
             obj.rpt(16) = DP_h;
             obj.rpt(17) = DP_g;
             obj.rpt(18) = DT_a;
             obj.rpt(19) = eff_a;
        end

        function lastCallUpdate(obj, engine)
            % Update pressure drop values
            m_dot_avgs = 0.5 * (engine.stateValues.m_dot_ck + engine.stateValues.m_dot_kr);
            rho = engine.fluid.density(engine.T_k, engine.stateValues.P);
            V_dot = m_dot_avgs ./ rho;
            obj.DP = obj.R_hyd * V_dot;
        end
        
        function lines = report(obj)
            % Return a string array that will be included in the engine report
            % (This function is optional)
            lines = [
                sprintf("Coolant flow rate = %.4f kg/s", obj.rpt(1)),
                sprintf("Coolant to tube heat transfer coefficient = %.4f W/m^2-K", obj.rpt(2)),
                sprintf("Coolant to tube thermal resistance = %.6f K/W", obj.rpt(3)),
                sprintf("Average mass flow rate of gas = %.4f kg/s", obj.rpt(4)),
                sprintf("Gas-side heat transfer coefficient = %.4f W/m^2-K", obj.rpt(5)),
                sprintf("Gas-side thermal resistance = %.4f K/W", obj.rpt(6)),
                sprintf("Tube conduction thermal resistance = %.4f K/W", obj.rpt(7)),
                sprintf("Total thermal resistance = %.4f K/W", obj.rpt(8)),
                sprintf("Number of transfer units = %.4f", obj.rpt(9)),
                sprintf("Capacitance ratio = %.4f", obj.rpt(10)),
                sprintf("Effectiveness of H2 to coolant HX = %.4f", obj.rpt(11)),
                sprintf("Temperature change of coolant = %.4f K", obj.rpt(12)),
                sprintf("Temperature change of gas = %.4f K", obj.rpt(13)),
                sprintf("Gas-side pressure drop, friction = %.4f Pa", obj.rpt(14)),
                sprintf("Gas-side pressure drop, contraction/expansion = %.4f Pa", obj.rpt(15)),
                sprintf("Gas-side pressure drop, header = %.4f Pa", obj.rpt(16)),
                sprintf("Gas-side pressure drop, total = %.4f Pa", obj.rpt(17)),
                sprintf("Temperature change of air = %.4f K", obj.rpt(18)),
                sprintf("Effectiveness of coolant to air HX = %.4f", obj.rpt(19))
            ];
        end
    end

    methods (Static)
        function getParams = createUI(gridLayout, params)
            inputs = containers.Map;
            createPanel = @StirlingEngineApp.createInputPanel;
            createInput = @StirlingEngineApp.createNumericInput;

            gridLayout.ColumnWidth = {"fit", "fit"};
            gridLayout.RowHeight = "fit";
            leftSide = uigridlayout(          ...
                gridLayout,                   ...
                "ColumnWidth", {"fit"},       ...
                "RowHeight", {"fit", "fit"},  ...
                "Padding", 0                  ...
            );
            rightSide = uigridlayout(         ...
                gridLayout,                   ...
                "ColumnWidth", {"fit"},       ...
                "RowHeight", {"fit", "fit"},  ...
                "Padding", 0                  ...
            );

            leftGrid = createPanel(leftSide, "Parameters");
            rightGrid = createPanel(rightSide, "Parameters");

            inputs("length_total") = createInput(  ...
                leftGrid,                          ...
                "Label", "Total Tube Length",      ...
                "Units", "m",                      ...
                "Value", params.length_total,      ...
                "LowerLimit", 0,                   ...
                "LowerLimitInclusive", "off"       ...
            );

            inputs("length_ht") = createInput(   ...
                leftGrid,                        ...
                "Label", "Exposed Tube Length",  ...
                "Units", "m",                    ...
                "Value", params.length_ht,       ...
                "LowerLimit", 0,                 ...
                "LowerLimitInclusive", "off"     ...
            );

            inputs("D_inner") = createInput(     ...
                leftGrid,                        ...
                "Label", "Tube Inner Diameter",  ...
                "Units", "m",                    ...
                "Value", params.D_inner,         ...
                "LowerLimit", 0,                 ...
                "LowerLimitInclusive", "off"     ...
            );

            inputs("D_outer") = createInput(     ...
                leftGrid,                        ...
                "Label", "Tube Outer Diameter",  ...
                "Units", "m",                    ...
                "Value", params.D_outer,         ...
                "LowerLimit", 0,                 ...
                "LowerLimitInclusive", "off"     ...
            );

            inputs("N_total") = createInput(       ...
                leftGrid,                          ...
                "Label", "Total Number of Tubes",  ...
                "Value", params.N_total,           ...
                "LowerLimit", 0,                   ...
                "LowerLimitInclusive", "off"       ...
            );

            inputs("N_shell") = createInput(  ...
                leftGrid,                     ...
                "Label", "Number of Shells",  ...
                "Value", params.N_shell,      ...
                "LowerLimit", 0,              ...
                "LowerLimitInclusive", "off"  ...
            );

            inputs("D_sh") = createInput(      ...
                leftGrid,                      ...
                "Label", "Diameter of Shell",  ...
                "Units", "m",                  ...
                "Value", params.D_sh,          ...
                "LowerLimit", 0,               ...
                "LowerLimitInclusive", "off"   ...
            );

            inputs("Ac_h") = createInput(              ...
                rightGrid,                             ...
                "Label", "Duct Cross-Sectional Area",  ...
                "Units", "m^2",                        ...
                "Value", params.Ac_h,                  ...
                "LowerLimit", 0,                       ...
                "LowerLimitInclusive", "off"           ...
            );

            inputs("roughness") = createInput(  ...
                rightGrid,                      ...
                "Label", "Roughness",           ...
                "Units", "m",                   ...
                "Value", params.roughness,      ...
                "LowerLimit", 0,                ...
                "LowerLimitInclusive", "off"    ...
            );

            inputs("vol_h") = createInput(    ...
                rightGrid,                    ...
                "Label", "Header Volume",     ...
                "Units", "m^3",               ...
                "Value", params.vol_h,        ...
                "LowerLimit", 0,              ...
                "LowerLimitInclusive", "off"  ...
            );

            inputs("m_dot_w") = createInput(         ...
                rightGrid,                           ...
                "Label", "Mass Flow Rate of Water",  ...
                "Units", "kg/s",                     ...
                "Value", params.m_dot_w,             ...
                "LowerLimit", 0,                     ...
                "LowerLimitInclusive", "off"         ...
            );

            uilabel(                            ...
                rightGrid,                      ...
                "Text", "Coolant",              ...
                "HorizontalAlignment", "right"  ...
            );
            inputs("coolant") = uidropdown(  ...
                rightGrid,                   ...
                "Items", [                   ...
                    "Water",                 ...
                ],                           ...
                "Value", params.coolant      ...
            );
            uilabel(rightGrid, "Text", "");  % spacer

            inputs("m_dot_a") = createInput(       ...
                rightGrid,                         ...
                "Label", "Mass Flow Rate of Air",  ...
                "Units", "kg/s",                   ...
                "Value", params.m_dot_a,           ...
                "LowerLimit", 0,                   ...
                "LowerLimitInclusive", "off"       ...
            );

            inputs("UA_a") = createInput(                    ...
                rightGrid,                                   ...
                "Label", "Air-to-Water Cooler Conductance",  ...
                "Units", "kg/s",                             ...
                "Value", params.UA_a                         ...
            );

            inputs("W_parasitic") = createInput(       ...
                rightGrid,                             ...
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
