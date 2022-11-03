% GPU-3 Hot Heat Exchanger with Nuclear Isomer
%
% This model of the GPU-3 hot heat exchanger assumes that T_hot is the
% hottest tube temperature and assumes that the heat exchanger consists of
% an array of tubes in a circular configuration filled with nuclear isomer.  

classdef GPU3_NI < handle
    properties (Constant)
        defaultParams = struct(  ...
            "R_f", 0.25,         ... %m, outer radius of core
            "L_f", 0.15,         ... %m, length of core
            "R_regen", 0.0825,   ... %m, radius of centers of coolers
            "D_outer", 0.00483,  ... %m, outer tube radius
            "D_inner", 0.00302,  ... %m, inner tube radius
            "k_f", 5,            ... %W/m-K, assumed fuel thermal conductivity
            "roughness", 1e-5,   ... %m, roughness on internal tube surface
            "N_total", 40,       ... %-, total number of tubes
            "vol_h", 1e-6,       ... %m^3, header volume of heat exchanger
            "R_ins", 0.1,        ... %K-m^2/W, area-specific thermal resistance of the insulation system
            "W_parasitic", 0     ...
        )
    end

    properties (SetAccess = private)
        % Interface Properties
        vol (1,1) double {mustBeReal}
        W_parasitic (1,1) double {mustBeReal}
        Q_parasitic (1,1) double {mustBeReal}
        DP (1,:) double {mustBeReal}

        % Internal Properties
        R_hyd (1,1) double
        L (1,1) double
        L_htr (1,1) double
        D_o (1,1) double
        D_i (1,1) double
        N_t (1,1) double
        roughness (1,1) double
        vol_h (1,1) double
        DT (1,1) double
        R_f (1,1) double
        L_f (1,1) double
        R_m (1,1) double
        R_regen (1,1) double
        k_f (1,1) double
        rpt (19,1) double
        T_max (1,1) double
        R_ins (1,1) double
        DT_f (1,1) double
        Q_dot_hhx (1,1) double
        Q_dot_b_loss (1,1) double
        Q_dot_r_loss (1,1) double
    end

    methods
        function obj = GPU3_NI(params)
            obj.R_f = params.R_f;
            obj.L_f = params.L_f;
            obj.R_regen = params.R_regen;
            obj.k_f = params.k_f;
            obj.D_o = params.D_outer;
            obj.D_i = params.D_inner;
            obj.N_t = params.N_total;
            obj.vol_h = params.vol_h;
            obj.R_ins = params.R_ins;
            obj.W_parasitic = params.W_parasitic;
            obj.Q_parasitic = 0;
            
            %setup geometry
            R_bar = obj.R_f/sqrt(2);    %area averaged radius - half of tubes inboard of this and the other half outboard
            obj.L_htr = 2*obj.L_f;      %length of each tube exposed to heat
            obj.L = obj.L_htr*1.2+(obj.R_f + R_bar)/2-obj.R_regen+R_bar/2;  %approximate length of each tubre
            obj.R_m = obj.R_f/sqrt(2*obj.N_t);  %outer radius of fuel surrounding a tube
                        
            % Calculate fluid volume inside tubes
            obj.vol = (obj.L) * obj.N_t * pi * obj.D_i^2 / 4+obj.vol_h;
        end

        function firstCallUpdate(obj, engine)
            % Provide an initial guess value for DT (before engine states are available)
            obj.DT = 10;
        end

        function update(obj, engine)
            % Update the value for DT based on the current engine state

            % Get total heat transfer rate
            Q_dot_e = 0;
            if ~isinf(engine.ws.R_e)
                Q_dot_e = engine.freq * trapz(                             ...
                    engine.stateValues.time,                               ...
                    (engine.T_l - engine.stateValues.T_e) / engine.ws.R_e  ...
                );
            end
            Q_dot_l = engine.freq * trapz(  ...
                engine.stateValues.time,    ...
                engine.stateValues.Q_dot_l  ...
            );
            obj.Q_dot_hhx = Q_dot_e + Q_dot_l;

            % Calculate average mass flow rate in the hxr
            m_dot_avgs = 0.5 * (engine.stateValues.m_dot_rl + engine.stateValues.m_dot_le);
            m_dot_avg = engine.freq * trapz(  ...
                engine.stateValues.time,      ...
                abs(m_dot_avgs)               ...
            );

            % Calculate average fluid properties in the HHX
            fluidProps = engine.fluid.allProps(engine.T_l, engine.P_ave);
            C_dot_avg = fluidProps.CP * m_dot_avg;  %average capacitance rate (W/K)
            rho_g = fluidProps.rho;  %average fluid density

            % Working fluid side calculations
            %--------------------------------
            %steady flow friction and htc
            [DP_tube, htc_g] = util.tubeFlow(fluidProps, m_dot_avg/obj.N_t, obj.D_i, obj.L, obj.roughness);
            
            %get minor loss
            K_h = 4.5; %assumed total minor loss coefficient (expansion/contraction, U, and multiple bends)
            Ac_g = pi * obj.D_i^2 / 4 * obj.N_t;  %cross-sectional area for flow in tubes
            u_g_avg = m_dot_avg / (rho_g * Ac_g);  %average velocity

            DP_minor = K_h*rho_g*u_g_avg^2/2;   %minor loss
            
            DP_g = DP_tube+DP_minor;  %total steady pressure loss
            
            u_max=u_g_avg*sqrt(2);  %approximate max velocity
            [MF_DP, MF_h] = util.oscillatingFlow(fluidProps, obj.D_i, engine.freq, u_max);  %get oscillating flow multipliers
            DP_g = MF_DP*DP_g;
            htc_g = MF_h*htc_g;
   
            obj.R_hyd = DP_g / (m_dot_avg / rho_g);  
            
            % Heat Loss
            %--------------------------------
            Vol_f = (pi*obj.R_f^2-2*obj.N_t*obj.D_o^2/4)*obj.L_f; %total volume of fuel
            
            gd=obj.Q_dot_hhx/Vol_f;  %volumetric thermal energy dissipation, neglecting additional heat due to losses
            obj.DT_f=gd*obj.R_m^2*log(obj.R_m/(obj.D_o/2))/(2*obj.k_f)-gd*(obj.R_m^2 - (obj.D_o/2)^2)/(4*obj.k_f);  %temperature rise from T_hot to edge of fuel (K)
            A_s = pi*obj.R_f^2 + 2*pi*obj.R_f*obj.L_f; %surface area for loss calculations
            obj.Q_parasitic = A_s*(engine.T_hot+obj.DT_f - engine.T_cold)/obj.R_ins;  %parasitic heat transfer from combustion system due to insulation

            UA_int = obj.N_t*pi*obj.D_i*htc_g*obj.L_htr;
            NTU_int = UA_int/C_dot_avg;  %NTU of heat exchanger from metal to working fluid
            eff_int = 1-exp(-NTU_int); %eff of heat exchanger from metal to working fluid
            obj.DT = obj.Q_dot_hhx/C_dot_avg * (1 / eff_int - 1);  %approach temperature - relative to T_hot, the tube temp.
            
            %parameters in report
            obj.rpt(1) = DP_g;
            obj.rpt(2) = m_dot_avg;
            obj.rpt(3) = obj.vol;
        end

        function lastCallUpdate(obj, engine)
            % Update pressure drop values
            m_dot_avgs = 0.5 * (engine.stateValues.m_dot_rl + engine.stateValues.m_dot_le);
            rho = engine.fluid.density(engine.T_l, engine.stateValues.P);
            V_dot = m_dot_avgs ./ rho;
            obj.DP = obj.R_hyd * V_dot;
        end
        
        function lines = report(obj)
            % Return a string array that will be included in the engine report
            % (This function is optional)
            lines = [
                sprintf("Gas side pressure drop = %.4f Pa", obj.rpt(1)),
                sprintf("average mass flow rate = %.4f kg/s", obj.rpt(2)),
                sprintf("hot heat exchanger void volume = %.4f m^3", obj.rpt(3)),
                sprintf("heat transfer rate in hhx = %.4f W", obj.Q_dot_hhx),
                sprintf("temperature rise in fuel = %.4f K", obj.DT_f)
            ];
        end
        
    end

    methods (Static)
        function getParams = createUI(gridLayout, params)
            inputs = containers.Map;
            createPanel = @StirlingEngineApp.createInputPanel;
            createInput = @StirlingEngineApp.createNumericInput;
            gridLayout.ColumnWidth = {"fit"};
            gridLayout.RowHeight = "fit";

            panelGrid = createPanel(gridLayout, "Parameters");
            inputs("R_f") = createInput(          ...
                panelGrid,                        ...
                "Label", "Outer Radius of Core",  ...
                "Units", "m",                     ...
                "Value", params.R_f,              ...
                "LowerLimit", 0,                  ...
                "LowerLimitInclusive", "off"      ...
            );
            inputs("L_f") = createInput(      ...
                panelGrid,                    ...
                "Label", "Length of Core",    ...
                "Units", "m",                 ...
                "Value", params.L_f,          ...
                "LowerLimit", 0,              ...
                "LowerLimitInclusive", "off"  ...
            );
            inputs("R_regen") = createInput(              ...
                panelGrid,                                ...
                "Label", "Radius of Centers of Coolers",  ...
                "Units", "m",                             ...
                "Value", params.R_regen,                  ...
                "LowerLimit", 0,                          ...
                "LowerLimitInclusive", "off"              ...
            );
            inputs("D_outer") = createInput(     ...
                panelGrid,                       ...
                "Label", "Outer Tube Diameter",  ...
                "Units", "m",                    ...
                "Value", params.D_outer,         ...
                "LowerLimit", 0,                 ...
                "LowerLimitInclusive", "off"     ...
            );
            inputs("D_inner") = createInput(     ...
                panelGrid,                       ...
                "Label", "Inner Tube Diameter",  ...
                "Units", "m",                    ...
                "Value", params.D_inner,         ...
                "LowerLimit", 0,                 ...
                "LowerLimitInclusive", "off"     ...
            );
            inputs("k_f") = createInput(               ...
                panelGrid,                             ...
                "Label", "Fuel Thermal Conductivity",  ...
                "Units", "W/m-K",                      ...
                "Value", params.k_f,                   ...
                "LowerLimit", 0,                       ...
                "LowerLimitInclusive", "off"           ...
            );
            inputs("roughness") = createInput(               ...
                panelGrid,                                   ...
                "Label", "Tube Internal Surface Roughness",  ...
                "Units", "m",                                ...
                "Value", params.roughness,                   ...
                "LowerLimit", 0,                             ...
                "LowerLimitInclusive", "off"                 ...
            );
            inputs("N_total") = createInput(  ...
                panelGrid,                    ...
                "Label", "Number of Tubes",   ...
                "Value", params.N_total,      ...
                "IsInteger", true,            ...
                "LowerLimit", 1               ...
            );
            inputs("vol_h") = createInput(    ...
                panelGrid,                    ...
                "Label", "Header Volume",     ...
                "Units", "m^3",               ...
                "Value", params.vol_h,        ...
                "LowerLimit", 0,              ...
                "LowerLimitInclusive", "off"  ...
            );
            inputs("R_ins") = createInput(                                  ...
                panelGrid,                                                  ...
                "Label", "Area-Specific Thermal Resistance of Insulation",  ...
                "Units", "K-m^2/W",                                         ...
                "Value", params.R_ins,                                      ...
                "LowerLimit", 0,                                            ...
                "LowerLimitInclusive", "off",                               ...
                "UpperLimit", 1                                             ...
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
