% Mod II / Mod I Regenerator
%
% This model of the Mod II / Mod I regenerator is for a woven screen regenerator
% The model returns the parasitic heat transfer through the matrix and the housing.

classdef ModII < handle
    properties (Constant)
        defaultParams = struct(                 ...
            "geometry", struct(                 ...
                "mesh", struct(                 ... %information about the mesh packing
                    "material", "SS304",        ... %material - must be included in solid utility function
                    "D_wire", 0.00005,          ... %wire diameter (m)
                    "pitch", 5650               ... %pitch (wires/m)
                ),                              ...
                "shell", struct(                ... %information about the shell
                    "material", "Stellite21",   ... %material - must be included in solid utility function
                    "R_sh", 0.040,              ... %outer radius (m)
                    "th_sh_cold", 0.004,        ... %thickness at the cold end (m)
                    "th_sh_hot", 0.0095,        ... %thickness at the hot end (m)
                    "length", 0.050             ... %length (m)
                )                               ...
            ),                                  ...
            "correlationtype", "steady",        ... %type of correlation to use, steady or oscillating
            "correlationf", "Gedeon and Wood",  ... %correlation for friction factor - must be one recognized by wovenMeshFlow
            "correlationj", "Gedeon and Wood"   ... %correlation for j-factor - must be one recognized by wovenMeshFlow
        )
    end

    properties (SetAccess = private)
        % Interface Properties
        vol (1,1) double {mustBeReal}   %void volume in regenerator (m^3)
        DT (1,1) double {mustBeReal}    %approach temperature - minimum temperature difference (K)
        Q_parasitic (1,1) double {mustBeReal}  %rate of axial heat transfer due to conduction (W)
        DP (1,:) double {mustBeReal}

        % Internal Properties
        d (1,1) double    %mesh diameter (m)
        m (1,1) double    %mesh pitch (1/m)
        R_sh (1,1) double %shell radius (m)
        th_sh_cold (1,1) double %eold end shell thickness (m)
        th_sh_hot (1,1) double %hot end shell thickness (m)
        L (1,1) double    %regenerator length (m)
        phi (1,1) double  %porosity
        r_h (1,1) double  %hydraulic radius (m)
        alpha (1,1) double %specific surface area (m^2/m^3)
        A_f (1,1) double  %cross-sectional area w/out screens(m^2)
        A_s (1,1) double  %total surface area (m^2)
        sigma (1,1) double %ratio of open area to cross-sectional area 
        R_hyd (1,1) double  %hydraulic resistance (ratio of DP/V_dot), (Pa-s/m^3)
        correlationtype (1,1) string %string indicating type of correlation to use
        correlationf (1,1) string %string indicating correlation to use
        correlationj (1,1) string
        meshMaterial (1,1) string %string indicating mesh material
        shellMaterial (1,1) string %string indicating shell material

        
        %Parameters for report
        eff (1,1) double %effectiveness
        NTU (1,1) double %number of transfer units
        U (1,1) double %utilization
        m_dot_avg (1,1) double %average mass flow rate (kg/s)
        Q_dot_par_ineff (1,1) double %enthalpy flow penalty due to ineffectiveness (W)
        Q_dot_shell (1,1) double %conduction through shell (W)
        Q_dot_screen (1,1) double %conduction through shell (W)
        DP_g (1,1) double %average pressure drop (Pa)
    end

    methods
        function obj = ModII(params)
            %assign internal objects to inputs, where possible
            obj.d = params.geometry.mesh.D_wire;
            obj.m = params.geometry.mesh.pitch;
            obj.R_sh = params.geometry.shell.R_sh;
            obj.th_sh_cold = params.geometry.shell.th_sh_cold;
            obj.th_sh_hot = params.geometry.shell.th_sh_hot;
            obj.L = params.geometry.shell.length;
            obj.correlationtype = params.correlationtype;
            obj.correlationf = params.correlationf;
            obj.correlationj = params.correlationj;
            obj.meshMaterial = params.geometry.mesh.material;
            obj.shellMaterial = params.geometry.shell.material;

            % Calculate geometric parameters related to the packing using
            % relations from Compact Heat Exchangers, 3rd edition, pg. 45
            x_t = 1 / (obj.m * obj.d);
            obj.phi = 1 - pi / (4 * x_t);           %porosity
            obj.r_h = obj.d * (x_t / pi - 1 / 4);   %hydraulic radius
            obj.alpha = pi / (x_t * obj.d);         %specific surface area
            obj.A_f = pi * (obj.R_sh^2);            %area for flow without packing, frontal area
            obj.A_s = obj.alpha * obj.L * obj.A_f;  %total surface area
            obj.sigma = (x_t - 1)^2 / x_t^2;        %open area for flow/frontal area
            obj.vol = obj.A_f * obj.L * obj.phi;    %void volume
        end

        function firstCallUpdate(obj, engine)
            % Provide an initial guess value for DT (before engine states are available)
            obj.DT = min(100, 0.1 * (engine.T_hot - engine.T_cold));
        end

        function update(obj, engine)
            % Update the value for DT based on the current engine cycle

            % Calculate average mass flow rate in the regenerator
            m_dot_avgs = 0.5 * (engine.stateValues.m_dot_kr + engine.stateValues.m_dot_rl);
            obj.m_dot_avg = engine.freq * trapz(  ...
                engine.stateValues.time,          ...
                abs(m_dot_avgs)                   ...
            );

            % Calculate average fluid properties in the regenerator at
            % mass average temperature and average pressure
            fluidProps = engine.fluid.allProps(engine.T_r, engine.P_ave);
            cp_g = fluidProps.CP;       %fluid specific heat capacity
            rho_g = fluidProps.rho;     %fluid density
            mu_g = fluidProps.mu;       %fluid viscosity

            % Mass flux & Reynolds number
            G = obj.m_dot_avg / (obj.phi*obj.A_f);  %mass flux is mass/flow area
            u_max = sqrt(2)*G/rho_g;  %maximum flow rate in regenerator assuming average density

            % Obtain pressure drop and heat transfer
            %steady flow behavior is used as a reference
            [DP_g_ss, h_ss] = util.wovenMeshFlow(fluidProps, G, obj.correlationj, obj.correlationf, obj.phi, obj.r_h, obj.A_s, obj.A_f, obj.sigma);
            switch obj.correlationtype
                case "steady"
                    MF_DP = 1; %use steady flow results with no adjustment
                    MF_h = 1;
                case "oscillating"
                     [MF_DP, MF_h] = util.oscillatingFlow(fluidProps, 4*obj.r_h, engine.freq, u_max);
                otherwise
                      error("correlationtype in ModII regenerator model is unrecognized");
            end  
            obj.DP_g = DP_g_ss*MF_DP; %oscillating flow results obtained with multiplier
            h = h_ss*MF_h;
            obj.R_hyd = obj.DP_g / (obj.m_dot_avg / rho_g);  %Calculate hydraulic resistance - this is used for the DP function to get frictional pressure drop
             
            % Obtain mesh material density and specific heat capacity
            [rho_mesh, cm, ~] = util.properties.Solid(obj.meshMaterial, engine.T_r);

            obj.NTU = h*obj.A_s/(obj.m_dot_avg*cp_g);   %Number of transfer units

            mm = (1-obj.phi)*obj.A_f*obj.L*rho_mesh;  % mass of mesh
            obj.U = obj.m_dot_avg*cp_g/(2*engine.freq*mm*cm);   % utilization - ratio of capacitance of fluid to capacitance of packing
                %note factor of 2 in denominator is because blow time is
                %half of period

            [obj.eff] = util.balancedregenerator(obj.NTU,obj.U);
            obj.DT=(engine.T_l-engine.T_k)*(1-obj.eff); %approach temperature difference
            
            %parasitic conduction through shell
            obj.Q_dot_shell = util.conduction(obj.shellMaterial, engine.T_l, engine.T_k, "tapcyl", "avgk", ...
                [obj.R_sh, obj.th_sh_cold, obj.th_sh_hot, obj.L]);
           
            %parasitic conduction through screen
            fluidProps = engine.fluid.allProps(engine.T_r, engine.P_ave);
            k_g = fluidProps.k;  % updated fluid conductivity
            [~, ~, k_s] = util.properties.Solid(obj.meshMaterial, engine.T_r);
            [k_e]=util.wovenMeshConduction(obj.d, obj.m, 2*obj.d, k_g, k_s);
            obj.Q_dot_screen = k_e*pi*obj.R_sh^2*(engine.T_l-engine.T_k)/obj.L;
            
            %total parasitic                    
            obj.Q_parasitic = obj.Q_dot_shell + obj.Q_dot_screen;
            
            %approximate parasitic due to regenerator ineffectiveness (included
            %implicity in model - do NOT add to Q_psrasitic
            obj.Q_dot_par_ineff=obj.m_dot_avg*fluidProps.CP*obj.DT/2;
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
                sprintf("Porosity = %.4f", obj.phi),
                sprintf("Average mass flow rate = %.4f kg/s", obj.m_dot_avg),
                sprintf("Utilization = %.4f", obj.U),
                sprintf("Number of transfer units = %.4f", obj.NTU),
                sprintf("Effectiveness = %.4f", obj.eff),
                sprintf("Penalty due to regenerator ineffectiveness = %.4f W", obj.Q_dot_par_ineff),
                sprintf("Frictional pressure drop at average flow = %.4f Pa", obj.DP_g),
                sprintf("Conduction through shell = %.4f W", obj.Q_dot_shell),
                sprintf("Conduction through screen pack = %.4f W", obj.Q_dot_screen)
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

            correlationsPanel = uipanel(leftSide, "Title", "Correlations");
            correlationsGrid = uigridlayout(    ...
                correlationsPanel,              ...
                "ColumnWidth", {"fit", "fit"},  ...
                "RowHeight", {"fit", "fit"}     ...
            );
            meshGrid = createPanel(rightSide, "Mesh");
            shellGrid = createPanel(rightSide, "Shell");

            inputs("geometry.shell.length") = createInput(  ...
                shellGrid,                                  ...
                "Label", "Length",                          ...
                "Units", "m",                               ...
                "Value", params.geometry.shell.length,      ...
                "LowerLimit", 0,                            ...
                "LowerLimitInclusive", "off"                ...
            );
            inputs("geometry.shell.R_sh") = createInput(  ...
                shellGrid,                                ...
                "Label", "Shell Radius",                  ...
                "Units", "m",                             ...
                "Value", params.geometry.shell.R_sh,      ...
                "LowerLimit", 0,                          ...
                "LowerLimitInclusive", "off"              ...
            );
            inputs("geometry.shell.th_sh_cold") = createInput(  ...
                shellGrid,                                      ...
                "Label", "Shell thickness at cold end",         ...
                "Units", "m",                                   ...
                "Value", params.geometry.shell.th_sh_cold,      ...
                "LowerLimit", 0,                                ...
                "LowerLimitInclusive", "off"                    ...
            );
            inputs("geometry.shell.th_sh_hot") = createInput(  ...
                shellGrid,                                     ...
                "Label", "Shell thickness at hot end",         ...
                "Units", "m",                                  ...
                "Value", params.geometry.shell.th_sh_hot,      ...
                "LowerLimit", 0,                               ...
                "LowerLimitInclusive", "off"                   ...
            );
            inputs("geometry.mesh.D_wire") = createInput(  ...
                meshGrid,                                  ...
                "Label", "Wire Diameter",                  ...
                "Units", "m",                              ...
                "Value", params.geometry.mesh.D_wire,      ...
                "LowerLimit", 0,                           ...
                "LowerLimitInclusive", "off"               ...
            );
            inputs("geometry.mesh.pitch") = createInput(  ...
                meshGrid,                                 ...
                "Label", "Pitch",                         ...
                "Units", "1/m",                           ...
                "Value", params.geometry.mesh.pitch,      ...
                "LowerLimit", 0,                          ...
                "LowerLimitInclusive", "off"              ...
            );
            uilabel(                            ...
                meshGrid,                       ...
                "Text", "Material",             ...
                "HorizontalAlignment", "right"  ...
            );
            inputs("geometry.mesh.material") = uidropdown(  ...
                meshGrid,                                   ...
                "Items", [                                  ...
                    "Stainless Steel",                      ...
                    "SS304",                                ...    
                    "Stellite21",                           ...
                    "Inconel",                              ...
                    "Titanium",                             ...
                    "Nickel"                                ...
                ],                                          ...
                "Value", params.geometry.mesh.material      ...
            );
            uilabel(                            ...
                shellGrid,                      ...
                "Text", "Material",             ...
                "HorizontalAlignment", "right"  ...
            );
            inputs("geometry.shell.material") = uidropdown(  ...
                shellGrid,                                   ...
                "Items", [                                   ...
                    "Stainless Steel",                       ...
                    "SS304",                                 ...
                    "Stellite21",                            ...
                    "Inconel",                               ...
                    "Titanium",                              ...
                    "Nickel"                                 ...
                ],                                           ...
                "Value", params.geometry.shell.material      ...
            );
            uilabel(                            ...
                correlationsGrid,               ...
                "Text", "Friction Factor",      ...
                "HorizontalAlignment", "right"  ...
            );
            inputs("correlationf") = uidropdown(  ...
                correlationsGrid,                 ...
                "Items", [                        ...
                    "Kays and London",            ...
                    "Gedeon and Wood"             ...
                ],                                ...
                "Value", params.correlationf      ...
            );
            uilabel(                            ...
                correlationsGrid,               ...
                "Text", "Colburn J-factor",     ...
                "HorizontalAlignment", "right"  ...
            );
            inputs("correlationj") = uidropdown(  ...
                correlationsGrid,                 ...
                "Items", [                        ...
                    "Kays and London",            ...
                    "Gedeon and Wood"             ...
                ],                                ...
                "Value", params.correlationj      ...
            );
            uilabel(                            ...
                correlationsGrid,               ...
                "Text", "Correlation type",     ...
                "HorizontalAlignment", "right"  ...
            );
            inputs("correlationtype") = uidropdown(  ...
                correlationsGrid,                    ...
                "Items", [                           ...
                    "steady",                        ...
                    "oscillating"                    ...
                ],                                   ...
                "Value", params.correlationtype      ...
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
