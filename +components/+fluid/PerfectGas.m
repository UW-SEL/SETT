% Perfect Gas

classdef PerfectGas
    properties (Constant)
        defaultParams = struct(  ...
            "name", "Helium"     ...
        )
    end

    properties (SetAccess = private)
        R
        CP
        CV
    end

    methods
        function obj = PerfectGas(params)
            switch params.name
                case "Air"
                    obj.R = 287;
                    obj.CP = 1029; % at 500 K
                    obj.CV = 742;  % at 500 K

                case "Helium"
                    obj.R = 2077;
                    obj.CP = 5192.6;
                    obj.CV = 3116;
                case "Hydrogen"
                    error("Perfect gas hydrogen is not available")
                otherwise
                    error("Unknown gas name: %s", params.name)
            end
        end

        function r = allProps(obj, T, P)
            r.rho = obj.density(T, P);
            r.u = obj.CV * T;
            r.h = obj.CP * T;
            r.drho_dT_P = -P ./ (obj.R * T.^2);
            r.drho_dP_T = 1 ./ (obj.R * T);
            r.du_dT_P = obj.CV;
            r.du_dP_T = 0;
            r.CP = obj.CP;
        end

        function r = density(obj, T, P)
            r = P ./ (obj.R * T);
        end

        function r = enthalpy(obj, T, P)
            r = obj.CP * T;
        end
    end

    methods (Static)
        function getParams = createUI(gridLayout, params)
            gridLayout.ColumnWidth = {"fit"};
            gridLayout.RowHeight = {"fit"};
            nameDropdown = uidropdown(       ...
                gridLayout,                  ...
                "Items", ["Air", "Helium"],  ...
                "Value", params.name         ...
            );

            getParams = @getParamsFunc;
            function r = getParamsFunc()
                r = struct("name", nameDropdown.Value);
            end
        end
    end
end
