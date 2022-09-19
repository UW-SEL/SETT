% Mod II / Mod I Cold Heat Exchanger
%
% TODO: Update the below comment when component is finalized:
%
% This model of the Mod I cold heat exchanger is for a woven screen regenerator
% The model assumes that T_cold is the inlet coolant temperature and does
% not consider the coolant-to-air heat exchanger.  The model computes the
% pump power (per cylinder) and flow rate based on engine speed

classdef ModII < handle
    properties (Constant)
        defaultParams = struct(           ...
            "geometry", struct(           ... %information about the geometry
                "tubes", struct(          ... %information about the tubes
                    "length", 0.093,      ... %total tube length (m)
                    "length_ht", 0.081,   ... %effective tube length (for heat transfer) (m)
                    "D_outer", 0.002,     ... %outer diameter of tube (m)
                    "D_inner", 0.001,     ... %inner diameter of tube (m)
                    "N_total", 449,       ... %total number of tubes
                    "roughness", 1.5e-6,  ... %tube roughness (m)
                    "material", "SS304"   ... %tube material (must be a material in .util.properties.Solid)
                ),                        ...
                "shell", struct(          ... %information about shell
                    "R_inner", 0.0405,    ... %inner radius of cooler shell (m)
                    "V_header", 2.5e-5,   ... %clearance volume in header, (m^3) - consists of 22 cm^3 (50% of 44 cm^3 total) for CHX to compression and 3 cm^3 for CHX to regenerator
                    "Ac_header", 3.5e-4   ... %cross-sectional area in header (m^2) - smallest value used to base head loss
                )                         ...
            ),                            ...
            "m_dot_p_fs", 2.3,            ... %full speed coolant flow rate (per cylinder)  (kg/s)
            "W_dot_p_fs", 188,            ... %full speed pump power (per cylinder) (W)
            "n_fs", 66.7,                 ... %full speed (rev/s)
            "fluid", "water",             ... %fluid on shell side
            "correlation", "oscillating"  ... %correlations to use "oscillating" or "steady"
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
        L (1,1) double
        L_ht (1,1) double
        D_t_o (1,1) double
        D_t_i (1,1) double
        N_t (1,1) double
        tubematerial (1,1) string
        R_s (1,1) double
        V_h (1,1) double
        Ac_h (1,1) double
        m_dot_p_fs (1,1) double
        W_dot_p_fs (1,1) double
        n_fs (1,1) double
        roughness (1,1) double
        correlation (1,1) string
        coolant (1,1) string
        rpt (17,1) double
    end

    methods
        function obj = ModII(params)
            obj.L = params.geometry.tubes.length;
            obj.L_ht = params.geometry.tubes.length_ht;
            obj.D_t_o = params.geometry.tubes.D_outer;
            obj.D_t_i = params.geometry.tubes.D_inner;
            obj.N_t = params.geometry.tubes.N_total;
            obj.roughness = params.geometry.tubes.roughness;
            obj.tubematerial = params.geometry.tubes.material;
            obj.R_s = params.geometry.shell.R_inner;
            obj.V_h = params.geometry.shell.V_header;
            obj.Ac_h = params.geometry.shell.Ac_header;
            obj.m_dot_p_fs = params.m_dot_p_fs;
            obj.W_dot_p_fs = params.W_dot_p_fs;
            obj.n_fs = params.n_fs;
            obj.correlation = params.correlation;
            obj.coolant = params.fluid;
            
            %total volume in chx is volume in tubes + header volume
            obj.vol = obj.L * obj.N_t * pi * obj.D_t_i^2 / 4 + obj.V_h;
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

            %average velocity & capacitance rate
            cp_g = fluidProps.CP;
            C_dot_avg = cp_g * m_dot_avg;
            rho_g = fluidProps.rho;

            %get DP and h in tube assuming steady flow
            [DP_tube, h_g] = util.tubeFlow(fluidProps, m_dot_avg/obj.N_t, obj.D_t_i, obj.L, obj.roughness);
            
            %get additional DP related to contraction & expansion
            [DP_minor] = util.K_tubearray(fluidProps,  m_dot_avg, obj.D_t_i, obj.L, obj.N_t, 2*obj.R_s);
            
            %additional minor loss due to CHX to compression space header
            u_h=m_dot_avg/(rho_g*obj.Ac_h);
            K_h = 1.5; %assumed minor loss coefficient
            DP_h = K_h*rho_g*u_h^2/2;
            
            DP_g = DP_tube+DP_minor+DP_h;  %total steady pressure loss
            
            if (obj.correlation == "oscillating")
                A_c=pi*obj.D_t_i^2/4;  %cross-sectional area of a tube
                u_max=m_dot_avg/(rho_g*A_c*obj.N_t)*sqrt(2);  %approximate max velocity
                [MF_DP, MF_h] = util.oscillatingFlow(fluidProps, obj.D_t_i, engine.freq, u_max);  %get oscillating flow multipliers
                DP_g = MF_DP*DP_g;
                h_g = MF_h*h_g;
            end
   
            obj.R_hyd = DP_g / (m_dot_avg / rho_g);
           
            %Determine coolant side characteristics
            %TODO - we need a Liquid.m utility function to avoid having to do this
            switch obj.coolant
                case "water"
                    rho_c = util.properties.Water("dens", (engine.T_cold+engine.T_k)/2);
                    mu_c = util.properties.Water("visc", (engine.T_cold+engine.T_k)/2);
                    k_c = util.properties.Water("cond", (engine.T_cold+engine.T_k)/2);
                    c_c = util.properties.Water("cp", (engine.T_cold+engine.T_k)/2);
                    Pr_c = mu_c*c_c/k_c;
    
                otherwise
                    error("fluid in utility function TubeBank is unrecognized");
            end
            
            %set up a tube bank with the right chararacteristics
            phi=obj.N_t*pi*obj.D_t_o^2/4/(pi*obj.R_s^2); %porosity - fluid volume/tube volume
            S_D=sqrt(pi*obj.D_t_o^2/(4*phi*cos(pi/6)));  %this computes the diagonal spacing in an HCP array required to get the porosity
            S_T=S_D;  %transverse pitch is the same as diagonal pitch
            S_L=S_D*cos(pi/6);  %longitudinal pitch is the reduced
            W=obj.R_s*sqrt(pi);  %tube bank is modeled as a square with dimension WxW
            N_L = floor(W/S_L);    %number of tubes  in flow direction
            
            %get the pump power and flow
            n_bar = engine.freq/obj.n_fs;  %engine speed normalized by pump full speed
            W_dot_pump_bar = 0.112907647 - 0.301177266*n_bar + 1.18483252*n_bar^2;  %pump power normalized by full speed power
            obj.W_parasitic = W_dot_pump_bar*obj.W_dot_p_fs;  %pump power per cylinder
            m_dot_c = obj.m_dot_p_fs*engine.freq/obj.n_fs;  %pump flow rate is assumed to scale linearly with engine speed
            
            %tube bank correlations
            u=m_dot_c/(W*obj.L_ht*rho_c);  %frontal velocity of coolant
            [DP_c, h_c] = util.TubeBank(u, N_L, obj.D_t_o, S_T, S_L, rho_c, mu_c, k_c, Pr_c);
            
             %resistance to tube wall
             [~, ~, k_t] = util.properties.Solid(obj.tubematerial, (engine.T_cold+engine.T_k)/2);  %tube conductivity
             R_t = log(obj.D_t_o / obj.D_t_i) / (2 * pi * k_t * obj.L_ht * obj.N_t);  %tube thermal resistance
 
             %determine total conductance
             R_g = 1 / (h_g * obj.N_t * obj.D_t_i * pi * obj.L_ht); %gas to tube resistance
             R_c = 1 / (h_c * obj.N_t * obj.D_t_o * pi * obj.L_ht);  %coolant to tube resistance
             R_total = R_g + R_c + R_t;  %total resistance
             UA = 1 / R_total;  %total conductance

             %determine approach temperature difference
             C_dot_c = m_dot_c * c_c;  %coolant capacitance rate
             C_dot_min = min(C_dot_c, C_dot_avg);  %minimum capacitance rate
             C_dot_max = max(C_dot_c, C_dot_avg);  %maximum capacitance rat
             NTU = UA / C_dot_min;   %number of transfer units
             Cr = C_dot_min / C_dot_max;  %capacitance ratio
             eff = (1 / (1 - exp(-NTU)) + Cr / (1 - exp(-Cr * NTU)) - 1 / NTU)^(-1);  %effectiveness
             obj.DT = Q_dot_avg * (1 / (eff * C_dot_min) - 1 / C_dot_avg);
             DT_c = Q_dot_avg/(m_dot_c*c_c);  %temperature change of water
             DT_g = Q_dot_avg/(m_dot_avg*cp_g); %temperature change of gas
             
             %parameters in report
             obj.rpt(1) = m_dot_c;
             obj.rpt(2) = h_c;
             obj.rpt(3) = R_c;
             obj.rpt(4) = m_dot_avg;
             obj.rpt(5) = h_g;
             obj.rpt(6) = R_g;
             obj.rpt(7) = R_t;
             obj.rpt(8) = R_total;
             obj.rpt(9) = NTU;
             obj.rpt(10) = Cr;
             obj.rpt(11) = eff;
             obj.rpt(12) = DT_c;
             obj.rpt(13) = DT_g;
             obj.rpt(14) = DP_tube;
             obj.rpt(15) = DP_minor;
             obj.rpt(16) = DP_h;
             obj.rpt(17) = DP_g;
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
                sprintf("Coolant flow rate per cylinder = %.4f kg/s", obj.rpt(1)),
                sprintf("Coolant to tube heat transfer coefficient = %.4f W/m^2-K", obj.rpt(2)),
                sprintf("Coolant to tube thermal resistance = %.6f K/W", obj.rpt(3)),
                sprintf("Average mass flow rate of gas = %.4f kg/s", obj.rpt(4)),
                sprintf("Gas-side heat transfer coefficient = %.4f W/m^2-K", obj.rpt(5)),
                sprintf("Gas-side thermal resistance = %.4f K/W", obj.rpt(6)),
                sprintf("Tube conduction thermal resistance = %.4f K/W", obj.rpt(7)),
                sprintf("Total thermal resistance = %.4f K/W", obj.rpt(8)),
                sprintf("Number of transfer units = %.4f", obj.rpt(9)),
                sprintf("Capacitance ratio = %.4f", obj.rpt(10)),
                sprintf("Effectiveness = %.4f", obj.rpt(11)),
                sprintf("Temperature change of coolant = %.4f K", obj.rpt(12)),
                sprintf("Temperature change of gas = %.4f K", obj.rpt(13)),
                sprintf("Gas-side pressure drop, friction = %.4f Pa", obj.rpt(14)),
                sprintf("Gas-side pressure drop, contraction/expansion = %.4f Pa", obj.rpt(15)),
                sprintf("Gas-side pressure drop, header = %.4f Pa", obj.rpt(16)),
                sprintf("Gas-side pressure drop, total = %.4f Pa", obj.rpt(17))
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
            tubesGrid = createPanel(leftSide, "Tubes");
            shellGrid = createPanel(leftSide, "Shell");
            coolantGrid = createPanel(rightSide, "Coolant");
            otherGrid = createPanel(rightSide, "Other Parameters");

            inputs("geometry.tubes.length") = createInput(  ...
                tubesGrid,                                  ...
                "Label", "Total Length",                    ...
                "Units", "m",                               ...
                "Value", params.geometry.tubes.length,      ...
                "LowerLimit", 0,                            ...
                "LowerLimitInclusive", "off"                ...
            );
            inputs("geometry.tubes.length_ht") = createInput(  ...
                tubesGrid,                                     ...
                "Label", "Heat Transfer Active Length",        ...
                "Units", "m",                                  ...
                "Value", params.geometry.tubes.length_ht,      ...
                "LowerLimit", 0,                               ...
                "LowerLimitInclusive", "off"                   ...
            );
            inputs("geometry.tubes.D_outer") = createInput(  ...
                tubesGrid,                                   ...
                "Label", "Outer Diameter",                   ...
                "Units", "m",                                ...
                "Value", params.geometry.tubes.D_outer,      ...
                "LowerLimit", 0,                             ...
                "LowerLimitInclusive", "off"                 ...
            );
            inputs("geometry.tubes.D_inner") = createInput(  ...
                tubesGrid,                                   ...
                "Label", "Inner Diameter",                   ...
                "Units", "m",                                ...
                "Value", params.geometry.tubes.D_inner,      ...
                "LowerLimit", 0,                             ...
                "LowerLimitInclusive", "off"                 ...
            );
            inputs("geometry.tubes.N_total") = createInput(  ...
                tubesGrid,                                   ...
                "Label", "Number of Tubes",                  ...
                "Value", params.geometry.tubes.N_total,      ...
                "IsInteger", true,                           ...
                "LowerLimit", 1                              ...
            );
            inputs("geometry.tubes.roughness") = createInput(  ...
                tubesGrid,                                     ...
                "Label", "Roughness",                          ...
                "Units", "m",                                  ...
                "Value", params.geometry.tubes.roughness,      ...
                "LowerLimit", 0                                ...
            );
            inputs("geometry.shell.R_inner") = createInput(  ...
                shellGrid,                                   ...
                "Label", "Inner Radius of Shell",            ...
                "Units", "m",                                ...
                "Value", params.geometry.shell.R_inner,      ...
                "LowerLimit", 0,                             ...
                "LowerLimitInclusive", "off"                 ...
            );
            inputs("geometry.shell.V_header") = createInput(  ...
                shellGrid,                                    ...
                "Label", "Volume in the header",              ...
                "Units", "m^3",                               ...
                "Value", params.geometry.shell.V_header,      ...
                "LowerLimit", 0,                              ...
                "LowerLimitInclusive", "off"                  ...
            );
            inputs("geometry.shell.Ac_header") = createInput(                    ...
                shellGrid,                                                       ...
                "Label", "Minimum cross-sectional area for flow in the header",  ...
                "Units", "m^2",                                                  ...
                "Value", params.geometry.shell.Ac_header,                        ...
                "LowerLimit", 0,                                                 ...
                "LowerLimitInclusive", "off"                                     ...
            );
            inputs("m_dot_p_fs") = createInput(                               ...
                coolantGrid,                                                  ...
                "Label", "Mass Flow Rate per cylinder at full engine speed",  ...
                "Units", "kg/s",                                              ...
                "Value", params.m_dot_p_fs,                                   ...
                "LowerLimit", 0,                                              ...
                "LowerLimitInclusive", "off"                                  ...
            );
            inputs("W_dot_p_fs") = createInput(                           ...
                coolantGrid,                                              ...
                "Label", "Pump power per cylinder at full engine speed",  ...
                "Units", "W",                                             ...
                "Value", params.W_dot_p_fs,                               ...
                "LowerLimit", 0                                           ...
            );
            inputs("n_fs") = createInput(      ...
                coolantGrid,                   ...
                "Label", "Full engine speed",  ...
                "Units", "rev/s",              ...
                "Value", params.n_fs,          ...
                "LowerLimit", 0                ...
            );
        
            uilabel(                            ...
                coolantGrid,                    ...
                "Text", "Coolant",              ...
                "HorizontalAlignment", "right"  ...
            );
            inputs("fluid") = uidropdown(  ...
                coolantGrid,               ...
                "Items", [                 ...
                    "water"                ...
                ],                         ...
                "Value", params.fluid      ...
            );
        
            uilabel(                            ...
                tubesGrid,                      ...
                "Text", "Material",             ...
                "HorizontalAlignment", "right"  ...
            );
            inputs("geometry.tubes.material") = uidropdown(  ...
                tubesGrid,                                   ...
                "Items", [                                   ...
                    "Stainless Steel",                       ...
                    "SS304",                                 ...
                    "Stellite21",                            ...
                    "Inconel",                               ...
                    "Titanium",                              ...
                    "Nickel"                                 ...
                ],                                           ...
                "Value", params.geometry.tubes.material      ...
            );
            uilabel(                                  ...
                otherGrid,                            ...
                "Text", "Gas-side correlation type",  ...
                "HorizontalAlignment", "right"        ...
            );
            inputs("correlation") = uidropdown(  ...
                otherGrid,                       ...
                "Items", [                       ...
                    "steady",                    ...
                    "oscillating"                ...
                ],                               ...
                "Value", params.correlation      ...
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