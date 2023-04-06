classdef StirlingEngine < handle
    % STIRLINGENGINE A Steady-State Stirling Engine Model
    %
    % Information on the approach and framework used by this model, as well as all
    % available component models, is available in the <a href="matlab:
    % web('documentation/Model Documentation.pdf', '-browser')">documentation</a>.
    %
    % Configuration of the engine is provided from a JSON-formatted config file or
    % a nested struct variable with the same format.  This config file or struct
    % defines, among other things, the component models to use and their parameters.
    %
    % A graphical tool is available for configuring and running an engine.  To open
    % this GUI, click <a href="matlab: StirlingEngineApp()">here</a> or run StirlingEngineApp().
    %
    % Examples:
    %   engine = StirlingEngine("path/to/config.json");
    %   engine = StirlingEngine(configStruct);

    methods (Static)
        checkComponentParams(compType, compName, params)
    end

    % Time-independent functions
    methods
        run(obj, varargin)
        plot(obj, plotType, varargin)
        save(obj, filename)
    end

    properties (SetAccess = private)
        config
    end

    properties (SetAccess = private)
        fluid
        ws
        chx
        regen
        hhx

        T_cold
        T_hot
        P_0

        isSolutionAvailable = false
        stateValues
        odeSol
        residuals
        numIterations

        V_k
        V_r
        V_l
        T_k
        T_r_cold
        T_r
        T_r_hot
        T_l
        P_ave
        freq
        period

        indicatedPowerZeroDP
        indicatedPower
        shaftPower
        shaftTorque
        netPower
        heatInput
        heatRejection
        efficiency
    end

    methods
        function obj = StirlingEngine(config)
            if isstruct(config)
                obj.config = config;
            else  % config is provided in a json file
                obj.config = jsondecode(fileread(config));
            end
            if isfield(obj.config, "solution")
                obj.config = rmfield(obj.config, "solution");  % drop solution if present in config file
            end

            % Initialize components
            for c = {'fluid', 'ws', 'chx', 'regen', 'hhx'}
                compType = c{1};  % get the string from the cell
                compName = obj.config.(compType).model;
                ClassName = str2func(['components.', compType, '.', compName]);
                if isfield(obj.config.(compType), 'params');
                    params = obj.config.(compType).params;
                    obj.checkComponentParams(compType, compName, params);
                    obj.(compType) = ClassName(params);
                else
                    obj.(compType) = ClassName();  % this component does not have any params
                end
            end

            % Store the saved conditions
            obj.T_cold = obj.config.conditions.T_cold;  % K
            obj.T_hot = obj.config.conditions.T_hot;    % K
            obj.P_0 = obj.config.conditions.P_0;        % Pa
        end
    end
end
